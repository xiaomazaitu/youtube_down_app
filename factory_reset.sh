#!/bin/bash

# YouTube视频下载应用一键出厂设置脚本
# 用于完全卸载和清理所有已部署的组件

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

# 确认函数
confirm() {
    read -p "确定要执行此操作吗？这将删除所有数据和配置。(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "操作已取消"
        exit 0
    fi
}

# 停止所有服务
stop_services() {
    log "停止所有相关服务..."
    
    # 停止应用服务
    sudo systemctl stop youtube-downloader-app.service 2>/dev/null || true
    sudo systemctl stop youtube-downloader-worker.service 2>/dev/null || true
    sudo systemctl stop youtube-downloader-beat.service 2>/dev/null || true
    
    # 停止Redis服务
    sudo systemctl stop redis-server 2>/dev/null || true
    
    # 停止Nginx服务
    sudo systemctl stop nginx 2>/dev/null || true
}

# 禁用并删除Systemd服务
remove_systemd_services() {
    log "移除Systemd服务..."
    
    # 禁用服务
    sudo systemctl disable youtube-downloader-app.service 2>/dev/null || true
    sudo systemctl disable youtube-downloader-worker.service 2>/dev/null || true
    sudo systemctl disable youtube-downloader-beat.service 2>/dev/null || true
    
    # 删除服务文件
    sudo rm -f /etc/systemd/system/youtube-downloader-app.service
    sudo rm -f /etc/systemd/system/youtube-downloader-worker.service
    sudo rm -f /etc/systemd/system/youtube-downloader-beat.service
    
    # 重新加载systemd配置
    sudo systemctl daemon-reload
}

# 删除项目文件和目录
remove_project_files() {
    log "删除项目文件和目录..."
    
    # 删除后端目录
    sudo rm -rf /opt/youtube_app
    
    # 删除前端目录
    sudo rm -rf /opt/youtube_web
    
    # 删除Celery运行目录
    sudo rm -rf /var/run/celery
    
    # 删除Celery日志目录
    sudo rm -rf /var/log/celery
}

# 删除Nginx配置
remove_nginx_config() {
    log "移除Nginx配置..."
    
    # 删除站点配置
    sudo rm -f /etc/nginx/sites-available/youtube-downloader
    sudo rm -f /etc/nginx/sites-enabled/youtube-downloader
    
    # 重新加载Nginx配置
    sudo nginx -s reload 2>/dev/null || true
}

# 删除Redis数据
remove_redis_data() {
    log "清理Redis数据..."
    
    # 删除Redis dump文件
    sudo rm -f /var/lib/redis/dump.rdb
    
    # 清理Redis配置备份
    sudo rm -f /etc/redis/redis.conf.backup 2>/dev/null || true
}

# 卸载软件包
uninstall_packages() {
    log "卸载已安装的软件包..."
    
    # 卸载Python虚拟环境相关包
    # 注意：这里不卸载系统级包，因为它们可能被其他应用使用
    # 如果确定要卸载，可以取消注释以下行
    # sudo apt remove -y python3 python3-pip python3-venv
    
    # 卸载Redis服务器
    # sudo apt remove -y redis-server
    
    # 卸载FFmpeg
    # sudo apt remove -y ffmpeg
    
    # 卸载Nginx
    # sudo apt remove -y nginx
}

# 清理用户和权限设置
cleanup_users() {
    log "清理用户和权限设置..."
    
    # 注意：这里不删除www-data用户，因为它是系统用户
    # 如果创建了其他专用用户，可以在这里删除
}

# 清理防火墙规则
cleanup_firewall() {
    log "清理防火墙规则..."
    
    # 删除特定的UFW规则（如果存在）
    sudo ufw delete allow 80 2>/dev/null || true
    sudo ufw delete allow 443 2>/dev/null || true
}

# 清理Cron任务
cleanup_cron() {
    log "清理Cron任务..."
    
    # 删除可能添加的cron任务
    # 注意：这需要手动检查和删除特定任务
    # crontab -l | grep -v "youtube" | crontab -
}

# 主函数
main() {
    log "开始YouTube视频下载应用一键出厂设置..."
    
    # 显示警告信息
    echo -e "${RED}警告：此操作将完全删除所有已部署的组件和数据！${NC}"
    echo "包括但不限于："
    echo "  - 所有应用文件和配置 (/opt/youtube_app, /opt/youtube_web)"
    echo "  - 所有服务配置和数据"
    echo "  - Redis数据和配置"
    echo "  - Nginx配置"
    echo "  - 日志文件和运行时数据"
    echo
    
    # 确认操作
    confirm
    
    # 执行清理操作
    stop_services
    remove_systemd_services
    remove_project_files
    remove_nginx_config
    remove_redis_data
    # uninstall_packages  # 默认不卸载系统包
    cleanup_users
    cleanup_firewall
    cleanup_cron
    
    log "出厂设置完成！所有已部署的组件和数据已被清理。"
    log "注意：系统级软件包（如Python、Redis、Nginx等）仍然安装在系统中。"
    log "如果需要完全卸载这些软件包，请手动编辑脚本取消注释相关行。"
}

# 执行主函数
main "$@"