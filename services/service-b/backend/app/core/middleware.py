import time
import uuid
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from app.core.logger import logger
from app.core.context import trace_id_var, client_ip_var


def get_client_ip(request: Request) -> str:
    # X-Forwarded-For 헤더 처리 (프록시/로드밸런서 뒤에서도 실제 IP 추출)
    forwarded_for = request.headers.get("X-Forwarded-For")
    if forwarded_for:
        return forwarded_for.split(",")[0].strip()
    return request.client.host


class SecurityLoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        # 요청마다 고유 trace_id 생성
        trace_id = str(uuid.uuid4())
        client_ip = get_client_ip(request)

        # ContextVar에 저장 (비동기 환경에서 요청 간 유실 방지)
        trace_id_var.set(trace_id)
        client_ip_var.set(client_ip)

        start_time = time.time()
        response = await call_next(request)
        process_time = time.time() - start_time

        log_data = {
            "method": request.method,
            "path": request.url.path,
            "status": response.status_code,
            "duration": round(process_time, 4)
        }

        if response.status_code >= 500:
            logger.error("SYSTEM_ERROR", extra=log_data)
        elif response.status_code >= 400:
            logger.warning("CLIENT_ERROR", extra=log_data)
        else:
            logger.info("REQUEST_COMPLETED", extra=log_data)

        return response
