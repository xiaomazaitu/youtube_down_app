# YouTube视频下载网站启动和测试指南

## 启动步骤

### 1. 环境准备
```bash
# 克隆项目
git clone <项目地址>
cd youtube_downloader

# 创建虚拟环境
python -m venv venv
source venv/bin/activate  # Linux/Mac
# 或者 venv\Scripts\activate  # Windows

# 安装依赖
pip install -r requirements.txt
```

### 2. 安装外部依赖
```bash
# 安装Redis服务器
# Ubuntu/Debian:
sudo apt update
sudo apt install redis-server

# macOS:
brew install redis

# 安装yt-dlp
pip install yt-dlp

# 安装ffmpeg
# Ubuntu/Debian:
sudo apt install ffmpeg

# macOS:
brew install ffmpeg
```

### 3. 启动服务
打开4个终端窗口分别执行以下命令：

```bash
# 终端1: 启动Redis
redis-server

# 终端2: 启动Celery worker
cd youtube_downloader
celery -A celery_app.celery worker --loglevel=info

# 终端3: 启动Celery beat (定时任务)
cd youtube_downloader
celery -A celery_app.celery beat --loglevel=info

# 终端4: 启动Flask应用
cd youtube_downloader
python app.py
```

### 4. 验证服务启动
访问 http://localhost:5000 应该能看到Flask默认页面

## 测试步骤

### 1. 基本功能测试
```bash
# 发送下载请求
curl -X POST http://localhost:5000/download \
     -H "Content-Type: application/json" \
     -d '{"url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}'

# 返回结果示例:
# {"message": "Download started", "task_id": "任务ID"}

# 查询任务状态
curl http://localhost:5000/status/任务ID

# 下载完成后获取视频
curl http://localhost:5000/video/视频文件名
```

### 2. 并发测试
使用Apache Bench进行并发测试：
```bash
# 安装ab工具
# Ubuntu/Debian:
sudo apt install apache2-utils

# 测试10个并发用户，每个用户发送10个请求
ab -n 100 -c 10 -p test_data.json -T "application/json" http://localhost:5000/download

# test_data.json内容:
# {"url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}
```

### 3. 频率限制测试
```bash
# 连续发送601个请求测试频率限制
for i in {1..601}; do
  curl -X POST http://localhost:5000/download \
       -H "Content-Type: application/json" \
       -d '{"url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}'
  echo "Request $i sent"
done
# 第601个请求应该返回429状态码
```

### 4. 缓存清理测试
```bash
# 等待1小时或手动修改文件时间戳
touch -d "2 hours ago" cache/test_video.mp4

# 检查定时任务是否清理过期文件
# 查看Celery beat终端输出确认定时任务执行
```

## 监控和日志

### 1. 查看服务日志
- Flask应用日志: 终端4输出
- Celery worker日志: 终端2输出
- Celery beat日志: 终端3输出
- Redis日志: 通常在/var/log/redis/redis-server.log

### 2. 性能监控
```bash
# 查看系统资源使用情况
htop

# 查看Redis状态
redis-cli info

# 查看磁盘使用情况
df -h
```

## 常见问题排查

### 1. 服务启动失败
- 检查端口是否被占用: `lsof -i :5000`
- 检查Redis是否正常运行: `redis-cli ping`
- 检查依赖是否安装完整: `pip list`

### 2. 下载失败
- 检查yt-dlp是否正常工作: `yt-dlp --version`
- 检查ffmpeg是否正常工作: `ffmpeg -version`
- 查看Celery worker日志中的错误信息

### 3. 频率限制不生效
- 检查Redis连接是否正常
- 查看Redis中是否正确存储了访问次数
- 验证IP获取逻辑是否正确