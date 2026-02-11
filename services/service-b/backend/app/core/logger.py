import logging
import sys
from pythonjsonlogger import jsonlogger
from datetime import datetime
from app.core.context import trace_id_var, client_ip_var, user_id_var


class CustomJsonFormatter(jsonlogger.JsonFormatter):
    def add_fields(self, log_record, record, message_dict):
        super(CustomJsonFormatter, self).add_fields(log_record, record, message_dict)

        # 타임스탬프
        if not log_record.get('timestamp'):
            log_record['timestamp'] = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%S.%fZ')

        # 로그 레벨
        log_record['level'] = record.levelname

        # ContextVar에서 자동 주입 (비동기 환경에서도 유실 안 됨)
        log_record['trace_id'] = trace_id_var.get()
        log_record['ip'] = log_record.get('ip') or client_ip_var.get()
        log_record['user_id'] = log_record.get('user_id') or user_id_var.get()

        # 불필요한 기본 필드 제거
        log_record.pop('color_message', None)


def get_logger(name: str):
    logger = logging.getLogger(name)

    if not logger.handlers:
        logger.setLevel(logging.INFO)
        handler = logging.StreamHandler(sys.stdout)

        formatter = CustomJsonFormatter(
            '%(timestamp)s %(level)s %(trace_id)s %(user_id)s %(ip)s %(message)s'
        )
        handler.setFormatter(formatter)
        logger.addHandler(handler)

    return logger


logger = get_logger("service-b")
