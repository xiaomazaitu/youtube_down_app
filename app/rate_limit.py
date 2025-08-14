from flask import request, jsonify
from functools import wraps
import redis
import time

# 连接Redis用于存储访问次数
redis_client = redis.Redis(host='localhost', port=6379, db=1, decode_responses=True)

def get_client_ip():
    """
    获取客户端真实IP地址
    """
    # 检查常见的代理头
    if request.environ.get('HTTP_X_FORWARDED_FOR'):
        # X-Forwarded-For可能包含多个IP，取第一个
        ip = request.environ.get('HTTP_X_FORWARDED_FOR').split(',')[0].strip()
    elif request.environ.get('HTTP_X_REAL_IP'):
        ip = request.environ.get('HTTP_X_REAL_IP')
    else:
        ip = request.remote_addr
    
    return ip

def rate_limit(limit=600, window=3600):
    """
    IP频率限制装饰器
    :param limit: 限制次数
    :param window: 时间窗口（秒）
    """
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            # 获取客户端IP
            ip = get_client_ip()
            
            # 构造Redis键
            key = f"rate_limit:{ip}"
            
            # 获取当前访问次数
            current = redis_client.get(key)
            
            if current is None:
                # 第一次访问，设置初始值和过期时间
                redis_client.setex(key, window, 1)
            elif int(current) >= limit:
                # 超过限制
                return jsonify({'error': 'Rate limit exceeded'}), 429
            else:
                # 增加访问次数
                redis_client.incr(key)
            
            return f(*args, **kwargs)
        return decorated_function
    return decorator