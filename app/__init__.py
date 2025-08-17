import os
from flask import Flask

def create_app():
    app = Flask(__name__)
    
    # 安全配置
    secret_key = os.environ.get('SECRET_KEY')
    if not secret_key:
        # 在生产环境中应该始终设置SECRET_KEY环境变量
        import warnings
        warnings.warn("SECRET_KEY not set, using default development key. "
                      "This is not recommended for production environments.", 
                      RuntimeWarning)
        secret_key = 'dev-secret-key'
    
    app.config['SECRET_KEY'] = secret_key
    app.config['CACHE_DIR'] = 'cache'
    
    # 注册蓝图
    from app.api import bp as api_bp
    app.register_blueprint(api_bp)
    
    return app