from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from prometheus_fastapi_instrumentator import Instrumentator
from app.core.config import settings
from app.core.middleware import SecurityLoggingMiddleware
from app.core.logger import logger
from app.core.vault_client import vault_client
from app.database.session import engine
from app.models import Base
from app.routers import auth

# FastAPI 앱 생성
app = FastAPI(
    title=settings.PROJECT_NAME,
    version="2.0.0",
    description="Security Lab - Vault Integrated Backend (Service B)"
)

app.include_router(auth.router, prefix="/api/v1/auth", tags=["auth"])

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 보안 로깅 미들웨어 추가
app.add_middleware(SecurityLoggingMiddleware)

# Prometheus 메트릭 수집
Instrumentator().instrument(app).expose(app)


@app.on_event("startup")
async def startup_event():
    # 애플리케이션 시작 시 실행
    
    # 데이터베이스 테이블 생성
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    logger.info("SERVER_STARTED", extra={
        "project": settings.PROJECT_NAME,
        "vault_enabled": settings.VAULT_ENABLED,
        "vault_available": vault_client.is_available()
    })


@app.on_event("shutdown")
async def shutdown_event():
    # 애플리케이션 종료 시 실행
    logger.info("SERVER_SHUTDOWN")


# ==================== 헬스체크 엔드포인트 ====================

@app.get("/")
async def root():
    # 루트 경로
    return {
        "service": settings.PROJECT_NAME,
        "status": "running",
        "vault_integrated": vault_client.is_available()
    }


@app.get("/health")
async def health_check():
    # 기본 헬스체크
    return {"status": "healthy"}


@app.get("/api/v1/health/vault")
async def vault_health():
    # Vault 연결 상태 확인
    is_available = vault_client.is_available()
    
    return {
        "vault_enabled": settings.VAULT_ENABLED,
        "vault_available": is_available,
        "vault_url": vault_client.vault_url,
        "status": "connected" if is_available else "disconnected"
    }


@app.get("/api/v1/health/database")
async def database_health():
    # 데이터베이스 연결 상태 확인
    from app.database.session import AsyncSessionLocal
    from sqlalchemy import text
    
    try:
        async with AsyncSessionLocal() as session:
            result = await session.execute(text("SELECT 1"))
            result.scalar()
        
        return {
            "database": "connected",
            "credentials_source": "vault" if vault_client.is_available() else "environment"
        }
    except Exception as e:
        logger.error("DB_CONNECTION_FAILED", extra={"stack_trace": str(e)})
        return {
            "database": "disconnected",
            "error": str(e)
        }


@app.get("/api/v1/info")
async def system_info():
    # 시스템 정보 (디버깅용)
    return {
        "project": settings.PROJECT_NAME,
        "vault": {
            "enabled": settings.VAULT_ENABLED,
            "available": vault_client.is_available(),
            "url": vault_client.vault_url
        },
        "database": {
            "server": settings.POSTGRES_SERVER,
            "database": settings.POSTGRES_DB,
            "user": settings.POSTGRES_USER,
            "password_set": bool(settings.POSTGRES_PASSWORD)
        }
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )
