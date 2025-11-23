# Render.com 部署指南

## 方式1：通过GitHub部署（推荐）

### 1. 准备Git仓库
```bash
cd f:\QQ\Downloads\hok_card\server
git init
git add .
git commit -m "Initial commit"

# 推送到GitHub
git remote add origin https://github.com/你的用户名/hok-card-server.git
git push -u origin main
```

### 2. 在Render.com创建Web Service
1. 访问 https://render.com
2. 注册/登录账号
3. 点击"New +" → "Web Service"
4. 连接GitHub仓库
5. 选择 `hok-card-server` 仓库

### 3. 配置服务
```
Name: hok-card-server
Environment: Node
Build Command: npm install
Start Command: npm start
Plan: Free
```

### 4. 部署
点击"Create Web Service"，等待部署完成（约2-3分钟）

### 5. 获取URL
部署完成后，获得URL：
```
https://hok-card-server.onrender.com
```

**注意**：Render免费版使用HTTP，需要在客户端使用`ws://`而非`wss://`

---

## 方式2：手动上传部署

### 1. 创建Web Service
在Render.com点击"New +" → "Web Service" → "Build and deploy from a Git repository"

### 2. 手动上传代码
- 使用Render CLI上传
- 或直接在设置中连接GitHub/GitLab

---

## 修改客户端连接地址

### NetworkManager.gd
```gdscript
# 修改服务器URL
const SERVER_URL = "ws://hok-card-server.onrender.com"  # 你的Render URL

# 或使用环境变量
var server_url = OS.get_environment("SERVER_URL") if OS.has_environment("SERVER_URL") else "ws://localhost:3000"
```

---

## 本地测试服务器

```bash
cd f:\QQ\Downloads\hok_card\server
npm install
npm start
```

访问 http://localhost:3000 查看状态

---

## 常见问题

### Q: 部署后无法连接？
A: 检查：
1. Render服务是否running状态
2. 客户端URL是否正确（`ws://`不是`wss://`）
3. 查看Render日志是否有错误

### Q: 15分钟后休眠怎么办？
A: 免费版限制，有两种解决方案：
1. 升级到付费版（$7/月）
2. 使用定时ping服务保持唤醒（不推荐）

### Q: 性能够用吗？
A: 免费版可以支持10-20个并发房间，适合MVP测试。正式运营建议升级到付费版。
