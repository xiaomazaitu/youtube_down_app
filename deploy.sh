#!/bin/bash

# YouTube视频下载应用一键部署脚本 (vkdown.com)
# 适用于4核6G云服务器

set -e  # 遇到错误时停止执行

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# 检查是否以root权限运行
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "此脚本不应以root权限运行"
        exit 1
    fi
}

# 更新系统包
update_system() {
    log "更新系统包..."
    sudo apt update && sudo apt upgrade -y
}

# 安装基础工具
install_base_tools() {
    log "安装基础工具..."
    sudo apt install -y curl wget git unzip htop tree
}

# 安装Python环境
install_python() {
    log "安装Python环境..."
    sudo apt install -y python3 python3-pip python3-venv
    
    # 验证安装
    python3 --version
    pip3 --version
}

# 安装系统依赖
install_system_dependencies() {
    log "安装系统依赖..."
    
    # 安装Redis服务器
    sudo apt install -y redis-server
    
    # 安装FFmpeg
    sudo apt install -y ffmpeg
    
    # 安装其他必要工具
    sudo apt install -y build-essential libffi-dev
}

# 克隆后端项目代码
clone_backend_project() {
    log "克隆后端项目代码..."
    
    # 创建后端项目目录
    mkdir -p /opt/youtube_app
    
    # 检查目录是否已包含项目文件
    if [ -d "/opt/youtube_app" ] && [ -n "$(ls -A /opt/youtube_app)" ]; then
        log "后端目录 /opt/youtube_app 已包含文件，跳过克隆步骤"
        cd /opt/youtube_app
    else
        log "后端目录为空，开始克隆项目..."
        cd /opt/youtube_app
        
        # 克隆后端项目代码（这里假设从Git仓库获取，需要替换为实际仓库地址）
        git clone https://github.com/xiaomazaitu/youtube_down_app.git .
        # 或者如果项目文件已上传到服务器，可以跳过此步骤
    fi
    
    # 创建必要的目录
    mkdir -p /opt/youtube_app/cache
    
    # 设置目录权限
    sudo chown -R www-data:www-data /opt/youtube_app
    chmod -R 755 /opt/youtube_app
}

# 克隆前端项目代码
clone_frontend_project() {
    log "克隆前端项目代码..."
    
    # 检查前端目录是否已包含项目文件
    if [ -d "/opt/youtube_web" ] && [ -n "$(ls -A /opt/youtube_web)" ]; then
        log "前端目录 /opt/youtube_web 已包含文件，跳过克隆步骤"
    else
        log "前端目录为空，开始克隆项目..."
        # 创建前端项目目录
        mkdir -p /opt/youtube_web
        
        # 克隆前端项目代码（这里假设从Git仓库获取，需要替换为实际仓库地址）
        git clone https://github.com/xiaomazaitu/youtube_down_web.git /opt/youtube_web
        # 或者如果项目文件已上传到服务器，可以跳过此步骤
    fi
    
    # 设置前端目录权限
    sudo chown -R www-data:www-data /opt/youtube_web
    chmod -R 755 /opt/youtube_web
}

# 创建Python虚拟环境
setup_virtualenv() {
    log "创建Python虚拟环境..."
    
    cd /opt/youtube_app
    
    # 检查虚拟环境是否已存在
    if [ -d "/opt/youtube_app/venv" ]; then
        log "虚拟环境已存在，跳过创建步骤"
    else
        # 创建虚拟环境
        python3 -m venv venv
    fi
    
    # 激活虚拟环境
    . venv/bin/activate
    
    # 升级pip
    pip install --upgrade pip
    
    # 安装项目依赖
    pip install -r requirements.txt
    
    # 安装yt-dlp
    pip install yt-dlp
}

# Redis配置优化
configure_redis() {
    log "配置Redis..."
    
    # 备份原始配置
    sudo cp /etc/redis/redis.conf /etc/redis/redis.conf.backup
    
    # 更新Redis配置
    sudo sed -i 's/# maxmemory <bytes>/maxmemory 536870912/' /etc/redis/redis.conf  # 512MB
    sudo sed -i 's/# maxmemory-policy noeviction/maxmemory-policy allkeys-lru/' /etc/redis/redis.conf
    
    # 重启Redis服务
    sudo systemctl restart redis-server
    
    # 设置开机自启
    sudo systemctl enable redis-server
    
    # 测试Redis连接
    redis-cli ping
}

# 后端环境变量配置
configure_backend_env() {
    log "配置后端环境变量..."
    
    # 创建后端环境变量文件
    cat > /opt/youtube_app/.env << 'EOF'
# Flask配置
SECRET_KEY=your-production-secret-key-here
FLASK_ENV=production

# Redis配置
REDIS_URL=redis://localhost:6379/0

# 应用配置
CACHE_DIR=/opt/youtube_app/cache
VIDEO_DIR=/opt/youtube_app/cache

# 前端配置
FRONTEND_DIR=/opt/youtube_web
EOF
    
    # 设置文件权限
    chmod 600 /opt/youtube_app/.env
}

# 更新后端应用配置
configure_backend_app() {
    log "更新后端应用配置..."
    
    # 更新Celery配置
    cat > /opt/youtube_app/config/celery_config.py << 'EOF'
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
EOF
}

# 创建Systemd服务文件
create_systemd_services() {
    log "创建Systemd服务文件..."
    
    # Flask应用服务
    sudo cat > /etc/systemd/system/youtube-downloader-app.service << 'EOF'
[Unit]
Description=YouTube Downloader Flask App
After=network.target redis-server.service

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/youtube_app
Environment=PATH=/opt/youtube_app/venv/bin
EnvironmentFile=/opt/youtube_app/.env
ExecStart=/opt/youtube_app/venv/bin/gunicorn --workers 3 --bind 127.0.0.1:5000 --timeout 120 app:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # Celery Worker服务
    sudo cat > /etc/systemd/system/youtube-downloader-worker.service << 'EOF'
[Unit]
Description=YouTube Downloader Celery Worker
After=network.target redis-server.service

[Service]
Type=forking
User=www-data
Group=www-data
WorkingDirectory=/opt/youtube_app
Environment=PATH=/opt/youtube_app/venv/bin
EnvironmentFile=/opt/youtube_app/.env
ExecStart=/opt/youtube_app/venv/bin/celery -A celery_app.celery worker --loglevel=info --concurrency=4 --pidfile=/var/run/celery/worker.pid
ExecReload=/bin/kill -HUP $MAINPID
PIDFile=/var/run/celery/worker.pid
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # Celery Beat服务
    sudo cat > /etc/systemd/system/youtube-downloader-beat.service << 'EOF'
[Unit]
Description=YouTube Downloader Celery Beat
After=network.target redis-server.service

[Service]
Type=forking
User=www-data
Group=www-data
WorkingDirectory=/opt/youtube_app
Environment=PATH=/opt/youtube_app/venv/bin
EnvironmentFile=/opt/youtube_app/.env
ExecStart=/opt/youtube_app/venv/bin/celery -A celery_app.celery beat --loglevel=info --pidfile=/var/run/celery/beat.pid
ExecReload=/bin/kill -HUP $MAINPID
PIDFile=/var/run/celery/beat.pid
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # 创建Celery运行目录
    sudo mkdir -p /var/run/celery
    sudo chown www-data:www-data /var/run/celery
    
    # 创建Celery日志目录
    sudo mkdir -p /var/log/celery
    sudo chown www-data:www-data /var/log/celery
    
    # 重新加载systemd配置
    sudo systemctl daemon-reload
    
    # 设置服务开机自启
    sudo systemctl enable youtube-downloader-app.service
    sudo systemctl enable youtube-downloader-worker.service
    sudo systemctl enable youtube-downloader-beat.service
}

# 安装和配置Nginx
configure_nginx() {
    log "安装和配置Nginx..."
    
    # 安装Nginx
    sudo apt install -y nginx
    
    # 启动Nginx
    sudo systemctl start nginx
    sudo systemctl enable nginx
    
    # 配置Nginx反向代理
    sudo cat > /etc/nginx/sites-available/youtube-downloader << 'EOF'
server {
    listen 80;
    server_name vkdown.com;  # 替换为你的域名或服务器IP

    # 客户端最大请求体大小
    client_max_body_size 16M;

    # 服务前端静态文件
    location / {
        root /opt/youtube_web;
        index index.html;
        try_files $uri $uri/ =404;
    }

    # 代理API请求到Flask应用
    location /api/ {
        proxy_pass http://127.0.0.1:5000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }

    # 代理下载请求到Flask应用
    location /download {
        proxy_pass http://127.0.0.1:5000/download;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 代理状态查询请求到Flask应用
    location /status/ {
        proxy_pass http://127.0.0.1:5000/status/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 代理视频文件请求到Flask应用
    location /video/ {
        proxy_pass http://127.0.0.1:5000/video/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 缓存静态文件
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2|ttf|eot|svg)$ {
        root /opt/youtube_web;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # 日志配置
    access_log /var/log/nginx/youtube_downloader_access.log;
    error_log /var/log/nginx/youtube_downloader_error.log;
}
EOF
    
    # 启用站点配置
    sudo ln -sf /etc/nginx/sites-available/youtube-downloader /etc/nginx/sites-enabled/
    
    # 测试Nginx配置
    sudo nginx -t
    
    # 重启Nginx
    sudo systemctl restart nginx
}

# 配置防火墙
configure_firewall() {
    log "配置防火墙..."
    
    # 启用UFW防火墙
    echo "y" | sudo ufw enable
    
    # 允许SSH访问
    sudo ufw allow ssh
    
    # 允许HTTP访问
    sudo ufw allow 80
    
    # 允许HTTPS访问
    sudo ufw allow 443
    
    # 查看防火墙状态
    sudo ufw status
}

# 启动所有服务
start_services() {
    log "启动所有服务..."
    
    # 启动应用服务
    sudo systemctl start youtube-downloader-app.service
    sudo systemctl start youtube-downloader-worker.service
    sudo systemctl start youtube-downloader-beat.service
    
    # 检查服务状态
    sudo systemctl status youtube-downloader-app.service --no-pager || true
    sudo systemctl status youtube-downloader-worker.service --no-pager || true
    sudo systemctl status youtube-downloader-beat.service --no-pager || true
}

# 创建监控脚本
create_monitoring_scripts() {
    log "创建监控脚本..."
    
    # 创建监控脚本
    cat > /opt/youtube_app/monitor.sh << 'EOF'
#!/bin/bash
echo "=== 系统资源使用情况 ==="
free -h

echo "=== 磁盘使用情况 ==="
df -h

echo "=== Redis状态 ==="
redis-cli info memory

echo "=== Celery任务队列 ==="
redis-cli llen celery

echo "=== 应用进程 ==="
ps aux | grep -E "(gunicorn|celery|redis)"
EOF
    
    chmod +x /opt/youtube_app/monitor.sh
}

# 主函数
main() {
    log "开始部署YouTube视频下载应用 (vkdown.com)..."
    
    check_root
    update_system
    install_base_tools
    install_python
    install_system_dependencies
    clone_backend_project
    clone_frontend_project
    setup_virtualenv
    configure_redis
    configure_backend_env
    configure_backend_app
    create_systemd_services
    configure_nginx
    configure_firewall
    start_services
    create_monitoring_scripts
    
    log "部署完成！请检查服务状态并根据需要配置SSL证书。"
    log "访问 http://vkdown.com 测试应用。"
}

# 执行主函数
main "$@"