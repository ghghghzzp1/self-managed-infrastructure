from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from app.core.config import settings

# PostgreSQL 엔진 생성
# Cloud SQL max_connections=200 기준 분배: Service A(100) + Service B(40) + 운영/모니터링(30) + 버퍼(30)
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=False,
    future=True,
    pool_size=40,
    max_overflow=0,
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
