from fastapi import APIRouter, Depends, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text, select
from app.database.session import get_db
from app.core.logger import logger
from app.models import User 
from app.core.context import client_ip_var

router = APIRouter()

def create_response(success_code: int, data: dict = None, error: dict = None):
    return {"success": success_code, "data": data, "error": error}

# --- 1. 로그인 (SQL Injection 탐지 + 취약점) ---
class LoginRequest(BaseModel):
    username: str
    password: str

@router.post("/login")
async def login(
    login_data: LoginRequest, 
    request: Request,
    db: AsyncSession = Depends(get_db)
):
    try:
               # 1. SQL Injection 공격 패턴 감지 (Wazuh 관제용)
        import re
        
        # 오탐 방지를 위한 정규표현식 패턴
        suspicious_patterns = [
            re.compile("'\\s*(?:OR|AND)\\b", re.IGNORECASE),
            re.compile("\\bUNION\\s+SELECT\\b", re.IGNORECASE),
            re.compile("--"),
            re.compile(";\\s*DROP\\b", re.IGNORECASE),
            re.compile("/\\*.*?\\*/", re.IGNORECASE)
        ]
        
        detected = []
        for pattern in suspicious_patterns:
            if (pattern.search(login_data.username) or 
                pattern.search(login_data.password)):
                detected.append(pattern.pattern)

        if detected:
            logger.warning("SUSPICIOUS_INPUT", extra={
                "input_user": login_data.username[:50],
                "patterns": str(detected),
                "type": "SQL_INJECTION_ATTEMPT",
                "ip": client_ip_var.get()
            })

        # 2. 취약점: 입력값 검증 없이 쿼리 실행 (name 컬럼도 조회)
        query = text(f"SELECT id, username, name, email, is_admin FROM fastapi_users WHERE username = '{login_data.username}' AND password = '{login_data.password}'")
        
        result = await db.execute(query)
        user = result.mappings().first() 

        # 3. 로그인 성공 여부 및 로그 기록
        login_success = True if user else False
        log_event = "LOGIN_SUCCESS" if login_success else "AUTH_UNAUTHORIZED"
        
        logger.info(log_event, extra={
            "input_user": login_data.username[:50],
            "ip": client_ip_var.get(),
            "success": login_success
        })

        if login_success:
            return create_response(success_code=200, data={
                "id": user.id,
                "username": user.username,
                "name": user.name,     # 실명 반환
                "email": user.email,
                "is_admin": user.is_admin
            })
        else:
            return JSONResponse(
                status_code=401,
                content=create_response(401, error={"code": "AUTH_FAILED", "message": "Invalid credentials"})
            )

    except Exception as e:
                logger.error("LOGIN_ERROR", extra={"error": str(e), "input_user": login_data.username[:50]})
                return JSONResponse(status_code=500, content=create_response(500, error={"code": "SERVER_ERROR"}))

# --- 2. 회원가입 (4가지 정보 입력: ID, Name, PW, Email) ---
class RegisterRequest(BaseModel):
    username: str
    name: str      # 실명 입력 받음
    password: str
    email: str

@router.post("/register")
async def register(reg_data: RegisterRequest, db: AsyncSession = Depends(get_db)):
    try:
        # 중복 ID 체크
        existing = await db.execute(select(User).where(User.username == reg_data.username))
        if existing.scalars().first():
            return JSONResponse(status_code=400, content={"message": "Username exists"})

        # 유저 생성 (비밀번호 평문 저장)
        new_user = User(
            username=reg_data.username,
            name=reg_data.name,      # 실명 저장
            password=reg_data.password, 
            email=reg_data.email,
            is_admin=False
        )
        
        db.add(new_user)
        await db.commit()
        await db.refresh(new_user)

        # 👇 [수정됨] "name" -> "full_name"으로 변경 (500 에러 해결!)
        logger.info("USER_REGISTER", extra={"username": new_user.username, "full_name": new_user.name})
        return create_response(201, data={"username": new_user.username, "message": "User created"})

    except Exception as e:
        logger.error("REGISTER_ERROR", extra={"error": str(e)})
        return JSONResponse(status_code=500, content={"message": "Register failed"})


# --- 3. 내 정보 조회 (이름, 이메일 반환) ---
@router.get("/profile/{user_id}")
async def get_profile(user_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalars().first()

    if not user:
        return JSONResponse(status_code=404, content={"message": "User not found"})

    return create_response(200, data={
        "name": user.name,
        "email": user.email
    })
