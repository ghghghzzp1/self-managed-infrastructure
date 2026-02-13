import logging
import sys
from pythonjsonlogger import jsonlogger
from datetime import datetime, timezone, timedelta
from app.core.context import trace_id_var, client_ip_var, user_id_var

KST = timezone(timedelta(hours=9))

class CustomJsonFormatter(jsonlogger.JsonFormatter):
    def add_fields(self, log_record, record, message_dict):
        super(CustomJsonFormatter, self).add_fields(log_record, record, message_dict)

        # @timestamp - Asia/Seoul 타임존
        if not log_record.get('@timestamp'):
            log_record['@timestamp'] = datetime.now(KST).strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] + '+09:00'

        # 로그 레벨
        log_record['level'] = record.levelname

        # mdc 객체 안에 trace_id
        log_record['mdc'] = {"trace_id": trace_id_var.get()}

        # ip, user_id
        log_record['ip'] = log_record.get('ip') or client_ip_var.get()
        log_record['user_id'] = log_record.get('user_id') or user_id_var.get()

        # 불필요한 기본 필드 제거
        log_record.pop('timestamp', None)
        log_record.pop('color_message', None)


def get_logger(name: str):
    logger = logging.getLogger(name)

    if not logger.handlers:
        logger.setLevel(logging.INFO)
        handler = logging.StreamHandler(sys.stdout)

        formatter = CustomJsonFormatter(
            '%(@timestamp)s %(level)s %(mdc)s %(user_id)s %(ip)s %(message)s'
        )
        handler.setFormatter(formatter)
        logger.addHandler(handler)

    return logger


logger = get_logger("service-b")
