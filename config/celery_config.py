# Celery配置
from celery.schedules import crontab
import os

# Broker设置 - 从环境变量读取，如果没有则使用默认值
# 生产环境应始终设置REDIS_URL环境变量
redis_url = os.environ.get('REDIS_URL')
if not redis_url:
    import warnings
    warnings.warn("REDIS_URL not set, using default localhost connection. "
                  "This is not recommended for production environments.", 
                  RuntimeWarning)
    redis_url = 'redis://localhost:6379/0'

CELERY_BROKER_URL = redis_url
CELERY_RESULT_BACKEND = redis_url

# 任务序列化设置
CELERY_TASK_SERIALIZER = 'json'
CELERY_RESULT_SERIALIZER = 'json'
CELERY_ACCEPT_CONTENT = ['json']

# 时区设置
CELERY_TIMEZONE = 'UTC'
CELERY_ENABLE_UTC = True

# 定时任务配置
CELERY_BEAT_SCHEDULE = {
    'cleanup-expired-videos': {
        'task': 'app.tasks.cleanup_expired_videos',
        'schedule': crontab(minute=0, hour='*'),  # 每小时执行一次
    },
}

# 设置broker连接重试行为，以消除Celery 6.0的警告
CELERY_BROKER_CONNECTION_RETRY_ON_STARTUP = True