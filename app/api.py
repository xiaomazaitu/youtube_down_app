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
        r'(youtube|youtu|youtube-nocookie)\.(com|be)/'
        r'(watch\?v=|embed/|v/|.+\?v=)?([^&=%\?]{11})'
    )
    
    return re.match(youtube_regex, url) is not None

@bp.route('/download', methods=['POST'])
@rate_limit(limit=600, window=3600)  # 限制每小时600次请求
def download_video_api():
    try:
        data = request.get_json()
        if not data:
            return jsonify({'error': 'Invalid JSON data'}), 400
            
        url = data.get('url')
        
        if not url:
            return jsonify({'error': 'URL is required'}), 400
        
        # 使用更严格的URL验证
        if not is_valid_youtube_url(url):
            return jsonify({'error': 'Invalid YouTube URL'}), 400
        
        # 调用Celery任务
        task = download_video.delay(url)
        
        return jsonify({'message': 'Download started', 'task_id': task.id}), 202
        
    except Exception as e:
        # 捕获所有未处理的异常
        return jsonify({'error': 'Internal server error'}), 500

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
        # 安全地处理task.info，防止为None时调用get()方法出错
        task_info = task.info if task.info is not None else {}
        response = {
            'state': task.state,
            'status': task_info.get('status', '')
        }
        if 'filename' in task_info:
            response['filename'] = task_info['filename']
    else:
        # 任务失败
        response = {
            'state': task.state,
            'status': str(task.info) if task.info is not None else 'Unknown error'
        }
    
    return jsonify(response)

@bp.route('/video/<filename>', methods=['GET'])
@rate_limit(limit=600, window=3600)  # 限制每小时600次请求
def get_video(filename):
    # 安全检查：防止路径遍历攻击
    # 确保文件名不包含路径分隔符
    if '..' in filename or '/' in filename or '\\' in filename:
        return jsonify({'error': 'Invalid filename'}), 400
    
    # 验证文件名格式（支持哈希文件名格式：32位十六进制字符 + 扩展名）
    import re
    if not re.match(r'^[0-9a-f]{32}(\.[a-zA-Z0-9]+)?$', filename):
        return jsonify({'error': 'Invalid filename format'}), 400
    
    # 检查文件是否存在
    cache_dir = current_app.config.get('CACHE_DIR', 'cache')
    filepath = os.path.join(os.getcwd(), cache_dir, filename)
    
    # 再次验证文件路径是否在缓存目录内
    cache_dir_abs = os.path.abspath(cache_dir)
    filepath_abs = os.path.abspath(filepath)
    if not filepath_abs.startswith(cache_dir_abs):
        return jsonify({'error': 'Invalid filename'}), 400
    
    if not os.path.exists(filepath):
        return jsonify({'error': 'File not found'}), 404
    
    # 实现视频文件访问
    try:
        return send_file(filepath, as_attachment=True)
    except Exception as e:
        return jsonify({'error': 'Failed to serve file'}), 500