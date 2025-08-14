import os
from celery import Celery

# 创建一个不依赖Flask应用的Celery实例
celery = Celery(
    'youtube_downloader',
    broker=os.environ.get('REDIS_URL') or 'redis://localhost:6379/0',
    backend=os.environ.get('REDIS_URL') or 'redis://localhost:6379/0'
)

# 更新配置
celery.conf.update(
    task_serializer='json',
    accept_content=['json'],
    result_serializer='json',
    timezone='UTC',
    enable_utc=True,
    # 指定包含任务的模块
    include=['app.tasks']
)

# 从配置文件加载额外的配置
basedir = os.path.abspath(os.path.dirname(__file__))
config_path = os.path.join(basedir, 'config', 'celery_config.py')
if os.path.exists(config_path):
    # 手动加载配置文件
    import importlib.util
    spec = importlib.util.spec_from_file_location("celery_config", config_path)
    celery_config = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(celery_config)
    
    # 应用配置
    for attr in dir(celery_config):
        if not attr.startswith('_'):
            celery.conf[attr.lower()] = getattr(celery_config, attr)

# 导入任务以确保它们被注册
from app import tasks

if __name__ == '__main__':
    celery.start()