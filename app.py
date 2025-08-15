from app import create_app
from flask_cors import CORS

# 创建Flask应用
app = create_app()

# 开发环境CORS配置 - 允许所有源
CORS(app, origins="*", supports_credentials=True)

if __name__ == '__main__':
    app.run(debug=True)