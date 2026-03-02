import ssl

from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from app.core.config import settings

# GCP Cloud SQL ssl_mode=ENCRYPTED_ONLY 대응
# asyncpg는 URL 쿼리스트링 sslmode를 지원하지 않으므로 connect_args로 전달
# 사설 IP(VPC 내부) 연결이므로 인증서 호스트명 검증 생략
_ssl_ctx = ssl.create_default_context()
_ssl_ctx.check_hostname = False
_ssl_ctx.verify_mode = ssl.CERT_NONE

# PostgreSQL 엔진 생성
# Cloud SQL max_connections=200 기준 분배: Service A(100) + Service B(40) + 운영/모니터링(30) + 버퍼(30)
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=False,
    future=True,
    pool_size=40,
    max_overflow=0,
    connect_args={"ssl": _ssl_ctx},
)

# AsyncSession 생성기
AsyncSessionLocal = sessionmaker(
    bind=engine, 
    class_=AsyncSession, 
    expire_on_commit=False, 
    autoflush=False
)

# DB 세션 의존성
async def get_db():
    async with AsyncSessionLocal() as session:
        yield session
