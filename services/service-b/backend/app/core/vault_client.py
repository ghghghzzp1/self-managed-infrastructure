import os
import time
import threading
import hvac
from typing import Dict, Optional
from app.core.logger import logger


class VaultClient:
    # 만료 15분 전 갱신 시작 (token_period=1h 기준)
    _TOKEN_RENEWAL_THRESHOLD = 900
    # 재시도 최소 간격: 10초 미만 재시도 금지 → retry storm 방지
    _MIN_RETRY_INTERVAL = 10
    # is_available() API 호출 캐시 TTL: 매 요청마다 Vault 호출 방지
    _AUTH_CACHE_TTL = 30

    def __init__(self):
        self.vault_url = os.getenv("VAULT_URI", "http://vault:8200")
        self.role_id = os.getenv("VAULT_ROLE_ID")
        self.secret_id = os.getenv("VAULT_SECRET_ID")
        self.client: Optional[hvac.Client] = None

        self._token_expire_time: float = 0
        self._last_renewal_attempt: float = 0

        # is_available() 캐시 상태
        self._auth_cache: Optional[bool] = None
        self._auth_cache_expires: float = 0

        self._initialize_client()
        self._start_renewal_thread()

    # ──────────────────────────────────────────────────────────────
    # 인증
    # ──────────────────────────────────────────────────────────────

    def _authenticate(self) -> bool:
        """AppRole 인증. 성공 시 클라이언트 토큰·만료 시각 갱신 후 True 반환."""
        try:
            client = hvac.Client(url=self.vault_url)
            resp = client.auth.approle.login(
                role_id=self.role_id,
                secret_id=self.secret_id,
            )
            client.token = resp["auth"]["client_token"]
            lease_duration = resp["auth"].get("lease_duration", 3600)
            self.client = client
            self._token_expire_time = time.time() + lease_duration
            self._invalidate_auth_cache()
            return True
        except Exception as e:
            logger.error("Vault authentication failed", extra={"error": str(e)})
            self.client = None
            self._invalidate_auth_cache()
            return False

    def _initialize_client(self):
        if not self.role_id or not self.secret_id:
            logger.warning(
                "VAULT_ROLE_ID or VAULT_SECRET_ID not set - Vault integration disabled"
            )
            return
        if self._authenticate():
            logger.info(
                "Vault client authenticated successfully",
                extra={"vault_url": self.vault_url},
            )

    # ──────────────────────────────────────────────────────────────
    # 백그라운드 토큰 갱신 (retry storm 방지 로직 포함)
    # ──────────────────────────────────────────────────────────────

    def _start_renewal_thread(self):
        if not self.client:
            return
        t = threading.Thread(
            target=self._renewal_loop, daemon=True, name="vault-token-renewer"
        )
        t.start()
        logger.info("Vault token renewal thread started")

    def _renewal_loop(self):
        """
        백그라운드 토큰 갱신 루프.

        흐름:
          1. 만료 _TOKEN_RENEWAL_THRESHOLD 초 전까지 sleep
          2. _MIN_RETRY_INTERVAL 이내 중복 시도 금지 (retry storm 방지)
          3. renew-self 시도 → 성공이면 다음 주기 대기
          4. 갱신 실패 → AppRole 재인증 (renewal-mode: re_authenticate 동등 로직)
        """
        while True:
            try:
                time_until_expiry = self._token_expire_time - time.time()
                sleep_secs = max(
                    time_until_expiry - self._TOKEN_RENEWAL_THRESHOLD,
                    self._MIN_RETRY_INTERVAL,
                )
                time.sleep(sleep_secs)

                now = time.time()
                if now - self._last_renewal_attempt < self._MIN_RETRY_INTERVAL:
                    continue
                self._last_renewal_attempt = now

                # 1차: 토큰 갱신 시도
                if self._renew_token():
                    continue

                # 갱신 실패 → AppRole 재인증
                logger.warning(
                    "Token renewal failed, re-authenticating with AppRole"
                )
                if self._authenticate():
                    logger.info("Re-authentication successful")
                else:
                    logger.error(
                        "Re-authentication failed, will retry after interval"
                    )

            except Exception as e:
                logger.error(
                    "Unexpected error in Vault renewal loop",
                    extra={"error": str(e)},
                )
                time.sleep(self._MIN_RETRY_INTERVAL)

    def _renew_token(self) -> bool:
        """renew-self 호출. 성공 시 만료 시각 갱신 후 True 반환."""
        if not self.client:
            return False
        try:
            result = self.client.auth.token.renew_self()
            lease_duration = result["auth"].get("lease_duration", 3600)
            self._token_expire_time = time.time() + lease_duration
            self._invalidate_auth_cache()
            logger.info("Vault token renewed", extra={"new_ttl": lease_duration})
            return True
        except Exception as e:
            logger.warning(
                "Vault token renewal failed", extra={"error": str(e)}
            )
            return False

    # ──────────────────────────────────────────────────────────────
    # 시크릿 조회
    # ──────────────────────────────────────────────────────────────

    def get_secret(self, path: str, mount_point: str = "secret") -> Optional[Dict]:
        if not self.client:
            logger.warning("Vault client not initialized - cannot fetch secrets")
            return None

        try:
            secret_response = self.client.secrets.kv.v2.read_secret_version(
                path=path,
                mount_point=mount_point,
            )
            secret_data = secret_response["data"]["data"]
            logger.info(
                "Secret retrieved from Vault",
                extra={"path": path, "mount_point": mount_point},
            )
            return secret_data

        except hvac.exceptions.InvalidPath:
            logger.error(
                "Secret path not found in Vault",
                extra={"path": path, "mount_point": mount_point},
            )
            return None

        except Exception as e:
            logger.error(
                "Failed to retrieve secret from Vault",
                extra={"stack_trace": str(e), "path": path},
            )
            return None

    def get_database_credentials(self) -> Optional[Dict[str, str]]:
        path = "service-b-backend"
        return self.get_secret(path)

    # ──────────────────────────────────────────────────────────────
    # 상태 확인 (캐시)
    # ──────────────────────────────────────────────────────────────

    def _invalidate_auth_cache(self):
        self._auth_cache = None
        self._auth_cache_expires = 0

    def is_available(self) -> bool:
        """
        Vault 클라이언트 사용 가능 여부.

        _AUTH_CACHE_TTL(30초) 동안 결과를 캐싱하여 매 요청마다
        Vault API를 호출하는 것을 방지한다.
        """
        now = time.time()
        if self._auth_cache is not None and now < self._auth_cache_expires:
            return self._auth_cache

        if not self.client:
            self._auth_cache = False
            self._auth_cache_expires = now + self._AUTH_CACHE_TTL
            return False

        try:
            result = self.client.is_authenticated()
            self._auth_cache = result
            self._auth_cache_expires = now + self._AUTH_CACHE_TTL
            return result
        except Exception:
            self._auth_cache = False
            # 에러 시 짧은 캐시(10초)로 Vault 부하 완화
            self._auth_cache_expires = now + self._MIN_RETRY_INTERVAL
            return False


# 싱글톤 인스턴스 생성
vault_client = VaultClient()
