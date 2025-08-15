# YouTube视频下载网站API接口文档

## 1. 下载视频接口

### 请求地址
`POST /download`

### 请求头
```
Content-Type: application/json
```

### 请求参数
| 参数名 | 类型   | 必填 | 说明                     |
| ------ | ------ | ---- | ------------------------ |
| url    | string | 是   | YouTube视频URL地址       |

### 请求示例
```bash
curl -X POST http://vkdown.com/download \\
     -H "Content-Type: application/json" \\
     -d '{"url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}'
```

### 响应结果
```json
{
  "message": "Download started",
  "task_id": "任务ID"
}
```

### 响应字段说明
| 字段名   | 类型   | 说明         |
| -------- | ------ | ------------ |
| message  | string | 响应消息     |
| task_id  | string | 下载任务ID   |

### 状态码
| 状态码 | 说明             |
| ------ | ---------------- |
| 202    | 下载任务已启动   |
| 400    | URL参数缺失或无效|
| 429    | 请求频率超限     |

## 2. 查询任务状态接口

### 请求地址
`GET /status/<task_id>`

### 请求参数
| 参数名  | 类型   | 必填 | 说明     |
| ------- | ------ | ---- | -------- |
| task_id | string | 是   | 任务ID   |

### 请求示例
```bash
curl http://vkdown.com/status/任务ID
```

### 响应结果(PENDING状态)
```json
{
  "state": "PENDING",
  "status": "Task is waiting to be processed"
}
```

### 响应结果(PROGRESS状态)
```json
{
  "state": "PROGRESS",
  "status": "下载进度信息"
}
```

### 响应结果(SUCCESS状态)
```json
{
  "state": "SUCCESS",
  "status": "completed",
  "filename": "视频文件名.mp4"
}
```

### 响应结果(FAILURE状态)
```json
{
  "state": "FAILURE",
  "status": "下载失败原因"
}
```

### 状态说明
| 状态    | 说明         |
| ------- | ------------ |
| PENDING | 任务等待中   |
| PROGRESS| 下载进行中   |
| SUCCESS | 下载完成     |
| FAILURE | 下载失败     |

## 3. 获取视频文件接口

### 请求地址
`GET /video/<filename>`

### 请求参数
| 参数名   | 类型   | 必填 | 说明       |
| -------- | ------ | ---- | ---------- |
| filename | string | 是   | 视频文件名 |

### 请求示例
```bash
curl http://vkdown.com/video/视频文件名.mp4 -o 下载的视频.mp4
```

### 响应结果
直接返回视频文件内容，浏览器会提示下载。

### 状态码
| 状态码 | 说明         |
| ------ | ------------ |
| 200    | 文件存在     |
| 404    | 文件不存在   |
| 429    | 请求频率超限 |

## 4. 频率限制说明

- 每个IP每小时最多访问600次
- 超过限制将返回429状态码

## 5. 支持的平台

- YouTube
- Bilibili
- VK
- TikTok
- 其他支持yt-dlp的平台

## 6. 使用流程

1. 调用下载视频接口，获取任务ID
2. 定期调用查询任务状态接口，监控下载进度
3. 下载完成后，使用返回的文件名调用获取视频文件接口

## 7. 错误处理

- 所有API接口都可能返回429状态码（频率限制）
- 下载失败时，查询任务状态接口会返回FAILURE状态及错误信息
- 文件不存在时，获取视频文件接口会返回404状态码