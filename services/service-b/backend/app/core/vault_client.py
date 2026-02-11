import os
import hvac
from typing import Dict, Optional
from app.core.logger import logger


class VaultClient:
    # Vault 연결 및 시크릿 관리 클래스
    
    def __init__(self):
        # Vault 서버 주소
        self.vault_url = os.getenv("VAULT_URI", "http://vault:8200")
        
        # app
        self.role_id = os.getenv("VAULT_ROLE_ID")
        self.secret_id = os.getenv("VAULT_SECRET_ID")
        
        # Vault 클라이언트 초기화
        self.client: Optional[hvac.Client] = None
        self._initialize_client()
    
    def _initialize_client(self):
        # Vault 클라이언트 초기화 및 연결 확인
        try:
            if not self.role_id or not self.secret_id:
                logger.warning("VAULT_ROLE_ID or VAULT_SECRET_ID not set - Vault integration disabled")
                return
            
            self.client = hvac.Client(url=self.vault_url)
            auth_response = self.client.auth.approle.login(
            role_id=self.role_id,
            secret_id=self.secret_id,
            )
            self.client.token = auth_response["auth"]["client_token"]
            
            # 연결 테스트
            if self.client.is_authenticated():
                logger.info("Vault client authenticated successfully", extra={
                    "vault_url": self.vault_url
                })
            else:
                logger.error("Vault authentication failed")
                self.client = None
                
        except Exception as e:
            logger.error("Failed to initialize Vault client", extra={
                "error": str(e),
                "vault_url": self.vault_url
            })
            self.client = None
    
    def get_secret(self, path: str, mount_point: str = "secret") -> Optional[Dict]:
        # Vault에서 시크릿 읽어오기
        # Args:
        #   path: 시크릿 경로 (예: "service-b-backend")
        #   mount_point: KV 엔진 마운트 포인트 (기본값: "secret")
        # Returns:
        #   시크릿 데이터 딕셔너리 또는 None
        
        if not self.client:
            logger.warning("Vault client not initialized - cannot fetch secrets")
            return None
        
        try:
            # KV v2 엔진 사용
            secret_response = self.client.secrets.kv.v2.read_secret_version(
                path=path,
                mount_point=mount_point
            )
            
            # 실제 데이터는 ['data']['data']에 있음
            secret_data = secret_response['data']['data']
            
            logger.info("Secret retrieved from Vault", extra={
                "path": path,
                "mount_point": mount_point
            })
            
            return secret_data
            
        except hvac.exceptions.InvalidPath:
            logger.error("Secret path not found in Vault", extra={
                "path": path,
                "mount_point": mount_point
            })
            return None
            
        except Exception as e:
            logger.error("Failed to retrieve secret from Vault", extra={
                "error": str(e),
                "path": path
            })
            return None
    
    def get_database_credentials(self) -> Optional[Dict[str, str]]:
        # 데이터베이스 자격증명을 Vault에서 가져오기
        # 경로: secret/service-b-backend/
        # 실제 Vault 구조:
        # {
        #     "db.name": "appdb",
        #     "db.username": "admin",
        #     "db.password": "secure_password"
        # }
        # 주의: db.host는 Vault에 없음 (환경변수에서 가져옴)
        
        # 고정 경로 (프로필 분리 없음)
        path = "service-b-backend"
        return self.get_secret(path)
    
    def is_available(self) -> bool:
        # Vault 클라이언트가 사용 가능한지 확인
        return self.client is not None and self.client.is_authenticated()


# 싱글톤 인스턴스 생성
vault_client = VaultClient()
