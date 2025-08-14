# YouTube视频下载网站API接口文档

## 1. 下载视频接口

### 请求地址
`POST /download`

### 请求参数
```json
{
  "url": "https://www.youtube.com/watch?v=视频ID"
}
```

### 响应结果
```json
{
  "message": "Download started",
  "task_id": "任务ID"
}
```

### 状态码
- 202: 下载任务已启动
- 400: URL参数缺失
- 429: 请求频率超限

## 2. 查询任务状态接口

### 请求地址
`GET /status/<task_id>`

### 响应结果
```json
{
  "state": "PROGRESS",
  "status": "下载进度信息"
}
```

### 状态说明
- PENDING: 任务等待中
- PROGRESS: 下载进行中
- SUCCESS: 下载完成
- FAILURE: 下载失败

## 3. 获取视频文件接口

### 请求地址
`GET /video/<filename>`

### 响应结果
```json
{
  "message": "File found",
  "filepath": "文件路径"
}
```

### 状态码
- 200: 文件存在
- 404: 文件不存在
- 429: 请求频率超限

## 4. 频率限制说明

- 每个IP每小时最多访问600次
- 超过限制将返回429状态码