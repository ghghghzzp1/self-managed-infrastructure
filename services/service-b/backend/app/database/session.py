from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from app.core.config import settings

# PostgreSQL 엔진 생성
engine = create_async_engine(
    settings.DATABASE_URL, 
    echo=False, 
    future=True
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
