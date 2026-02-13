from contextvars import ContextVar

# 요청마다 고유한 trace_id 저장
trace_id_var: ContextVar[str] = ContextVar("trace_id", default="-")

# 클라이언트 IP 저장 (X-Forwarded-For 처리 포함)
client_ip_var: ContextVar[str] = ContextVar("client_ip", default="-")

# 인증된 유저 ID 저장 (비로그인 요청은 null)
user_id_var: ContextVar[str | None] = ContextVar("user_id", default=None)
