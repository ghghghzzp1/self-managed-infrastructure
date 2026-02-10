import os
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    PROJECT_NAME: str = "Service B"
    
    # Vault 설정
    VAULT_URI: str = os.getenv("VAULT_URI", "http://vault:8200")
    VAULT_ROLE_ID: str = os.getenv("VAULT_ROLE_ID", "")
    VAULT_SECRET_ID: str = os.getenv("VAULT_SECRET_ID", "")
    VAULT_ENABLED: bool = os.getenv("VAULT_ENABLED", "true").lower() == "true"
    
    # [DB 접속 정보] - Vault에서 동적으로 가져오거나 환경변수 사용
    POSTGRES_USER: str = ""
    POSTGRES_PASSWORD: str = ""
    POSTGRES_SERVER: str = ""
    POSTGRES_DB: str = ""

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self._load_database_credentials()
    
    def _load_database_credentials(self):
        # DB 자격증명을 Vault에서 가져오기 (폴백: 환경변수)
        
        from app.core.logger import logger
        
        # Vault 사용이 활성화되어 있고 토큰이 있는 경우
        if self.VAULT_ENABLED and self.VAULT_ROLE_ID and self.VAULT_SECRET_ID:
            try:
                from app.core.vault_client import vault_client
                
                # Vault에서 DB 자격증명 가져오기
                # 경로: secret/service-b-backend
                db_creds = vault_client.get_database_credentials()
                
                if db_creds:
                    # 실제 Vault 키 이름 사용
                    self.POSTGRES_USER = db_creds.get("db.user", "")
                    self.POSTGRES_PASSWORD = db_creds.get("db.password", "")
                    self.POSTGRES_DB = db_creds.get("db.name", "appdb")
                    
                    # db.host는 Vault에 없으므로 환경변수에서 가져옴
                    self.POSTGRES_SERVER = os.getenv("POSTGRES_SERVER", "postgres")
                    
                    logger.info("DB_CREDENTIALS_LOADED_FROM_VAULT", extra={
                        "user": self.POSTGRES_USER,
                        "host": self.POSTGRES_SERVER,
                        "database": self.POSTGRES_DB
                    })
                    return
                else:
                    logger.warning("VAULT_FETCH_FAILED_FALLBACK_TO_ENV")
                    
            except Exception as e:
                logger.error("VAULT_INTEGRATION_ERROR", extra={
                    "error": str(e)
                })
        
        # Vault 실패 시 환경변수에서 시도하되 기본값 없음
        self.POSTGRES_USER = os.getenv("POSTGRES_USER", "")
        self.POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD", "") #
        self.POSTGRES_SERVER = os.getenv("POSTGRES_SERVER", "")
        self.POSTGRES_DB = os.getenv("POSTGRES_DB", "")

        if not self.POSTGRES_PASSWORD:
            raise ValueError("DB credentials not available: Vault failed and no environment variables set")
        
        logger.info("DB_CREDENTIALS_LOADED_FROM_ENV", extra={
            "user": self.POSTGRES_USER,
            "host": self.POSTGRES_SERVER
        })

    @property
    def DATABASE_URL(self) -> str:
        # DB 접속 주소 완성하기
        return f"postgresql+asyncpg://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.POSTGRES_SERVER}:5432/{self.POSTGRES_DB}"


settings = Settings()
