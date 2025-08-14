import yt_dlp
import os
import subprocess
import time
import shlex
import logging
from celery import current_task
from celery_app import celery

# 配置日志
logger = logging.getLogger(__name__)

# 获取项目根目录
basedir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))

@celery.task(bind=True)
def download_video(self, url):
    """
    下载视频并转换为MP4格式（支持YouTube、Bilibili、VK、TikTok等平台）
    """
    try:
        # 更新任务状态
        self.update_state(state='PROGRESS', meta={'status': '开始下载'})
        
        # 创建临时目录
        cache_dir = os.path.join(basedir, 'cache')
        os.makedirs(cache_dir, exist_ok=True)
        
        # yt-dlp配置
        ydl_opts = {
            'format': 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best',
            'outtmpl': os.path.join(cache_dir, '%(id)s.%(ext)s'),
            'progress_hooks': [lambda d: self.update_state(
                state='PROGRESS', 
                meta={'status': f'下载进度: {d.get("downloaded_bytes", 0)} bytes'})
            ],
        }
        
        # 下载视频
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=True)
            video_id = info['id']
            filename = ydl.prepare_filename(info)
        
        # 更新任务状态
        self.update_state(state='PROGRESS', meta={'status': '下载完成，正在转换格式'})
        
        # 如果不是MP4格式，使用ffmpeg转换
        if not filename.endswith('.mp4'):
            mp4_filename = os.path.join(cache_dir, f'{video_id}.mp4')
            # 使用shlex.quote安全地处理文件名
            subprocess.run([
                'ffmpeg', '-i', shlex.quote(filename), 
                '-c:v', 'libx264', '-c:a', 'aac', 
                '-strict', 'experimental', shlex.quote(mp4_filename)
            ], check=True)
            
            # 删除原始文件
            os.remove(filename)
            filename = mp4_filename
        
        # 返回文件路径
        relative_path = os.path.relpath(filename, basedir)
        return {
            'status': 'completed',
            'filename': relative_path,
            'video_id': video_id
        }
        
    except Exception as exc:
        logger.error(f"下载视频失败: {url}, 错误: {str(exc)}", exc_info=True)
        self.update_state(
            state='FAILURE',
            meta={'status': '下载失败', 'error': str(exc)}
        )
        raise

@celery.task
def cleanup_expired_videos():
    """
    清理过期视频文件（超过1小时）
    """
    try:
        cache_dir = os.path.join(basedir, 'cache')
        if not os.path.exists(cache_dir):
            return
        
        current_time = time.time()
        expired_files = []
        
        for filename in os.listdir(cache_dir):
            try:
                filepath = os.path.join(cache_dir, filename)
                if os.path.isfile(filepath):
                    # 检查文件修改时间
                    file_mtime = os.path.getmtime(filepath)
                    if current_time - file_mtime > 3600:  # 1小时 = 3600秒
                        os.remove(filepath)
                        expired_files.append(filename)
            except Exception as e:
                logger.error(f"清理文件 {filename} 时出错: {str(e)}", exc_info=True)
                continue
        
        return {
            'status': 'completed',
            'cleaned_files': expired_files
        }
    except Exception as e:
        logger.error(f"清理过期视频文件时出错: {str(e)}", exc_info=True)
        return {
            'status': 'failure',
            'error': str(e)
        }