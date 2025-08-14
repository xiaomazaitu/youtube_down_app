import os
from flask import Flask

def create_app():
    app = Flask(__name__)
    
    # 配置
    app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY') or 'dev-secret-key'
    app.config['CACHE_DIR'] = 'cache'
    
    # 注册蓝图
    from app.api import bp as api_bp
    app.register_blueprint(api_bp)
    
    return app