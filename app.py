from app import create_app

# 创建Flask应用
app = create_app()

if __name__ == '__main__':
    app.run(debug=True)