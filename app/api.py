from flask import Blueprint, request, jsonify, current_app, send_file
from app.tasks import download_video
from app.rate_limit import rate_limit
import os
import re

bp = Blueprint('api', __name__)

def is_valid_youtube_url(url):
    """验证是否为有效的YouTube URL"""
    if not url:
        return False
    
    # YouTube URL正则表达式
    youtube_regex = (
        r'(https?://)?(www\.)?'
        '(youtube|youtu|youtube-nocookie)\.(com|be)/'
        '(watch\?v=|embed/|v/|.+\?v=)?([^&=%\?]{11})'
    )
    
    return re.match(youtube_regex, url) is not None

@bp.route('/download', methods=['POST'])
@rate_limit(limit=600, window=3600)  # 限制每小时600次请求
def download_video_api():
    data = request.get_json()
    url = data.get('url')
    
    if not url:
        return jsonify({'error': 'URL is required'}), 400
    
    # 简单的URL格式验证
    if not url.startswith(('http://', 'https://')):
        return jsonify({'error': 'Invalid URL format'}), 400
    
    # 调用Celery任务
    task = download_video.delay(url)
    
    return jsonify({'message': 'Download started', 'task_id': task.id}), 202

@bp.route('/status/<task_id>', methods=['GET'])
# @rate_limit(limit=600, window=3600)  # 限制每小时600次请求
def get_status(task_id):
    # 获取Celery任务状态
    task = download_video.AsyncResult(task_id)
    
    if task.state == 'PENDING':
        response = {
            'state': task.state,
            'status': 'Task is waiting to be processed'
        }
    elif task.state != 'FAILURE':
        response = {
            'state': task.state,
            'status': task.info.get('status', '')
        }
        if 'filename' in task.info:
            response['filename'] = task.info['filename']
    else:
        # 任务失败
        response = {
            'state': task.state,
            'status': str(task.info)
        }
    
    return jsonify(response)

@bp.route('/video/<filename>', methods=['GET'])
@rate_limit(limit=600, window=3600)  # 限制每小时600次请求
def get_video(filename):
    # 检查文件是否存在
    cache_dir = current_app.config.get('CACHE_DIR', 'cache')
    filepath = os.path.join(os.getcwd(), cache_dir, filename)
    if not os.path.exists(filepath):
        return jsonify({'error': 'File not found'}), 404
    
    # 实现视频文件访问
    try:
        return send_file(filepath, as_attachment=True)
    except Exception as e:
        return jsonify({'error': 'Failed to serve file'}), 500