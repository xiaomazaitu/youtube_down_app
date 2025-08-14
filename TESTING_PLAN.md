# YouTube视频下载网站测试计划

## 1. 环境准备
- 安装Python 3.8+
- 安装Redis服务器
- 安装yt-dlp和ffmpeg
- 安装项目依赖: `pip install -r requirements.txt`

## 2. 启动服务
```bash
# 启动Redis
redis-server

# 启动Celery worker
celery -A celery_app.celery worker --loglevel=info

# 启动Celery beat
celery -A celery_app.celery beat --loglevel=info

# 启动Flask应用
python app.py
```

## 3. 功能测试

### 3.1 单用户下载测试
1. 发送下载请求:
   ```bash
   curl -X POST http://localhost:5000/download \
        -H "Content-Type: application/json" \
        -d '{"url": "https://www.youtube.com/watch?v=测试视频ID"}'
   ```

2. 查询任务状态:
   ```bash
   curl http://localhost:5000/status/任务ID
   ```

3. 获取下载文件:
   ```bash
   curl http://localhost:5000/video/文件名
   ```

### 3.2 多用户并发下载测试
1. 使用工具模拟多个并发请求
2. 观察服务器资源使用情况
3. 检查任务队列处理能力

### 3.3 缓存管理测试
1. 下载多个视频文件
2. 等待1小时后检查文件是否自动清理
3. 验证定时任务执行情况

### 3.4 频率限制测试
1. 同一IP连续发送超过600次请求
2. 验证是否返回429状态码
3. 等待1小时后验证限制是否重置

## 4. 性能指标
- 并发用户数: 支持至少10个用户同时下载
- 响应时间: API响应时间小于1秒
- 内存使用: 4核6G服务器正常运行
- 稳定性: 24小时连续运行无故障