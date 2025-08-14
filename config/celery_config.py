# Celery配置
from celery.schedules import crontab
import os

# Broker设置 - 从环境变量读取，如果没有则使用默认值
CELERY_BROKER_URL = os.environ.get('REDIS_URL') or 'redis://localhost:6379/0'
CELERY_RESULT_BACKEND = os.environ.get('REDIS_URL') or 'redis://localhost:6379/0'

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