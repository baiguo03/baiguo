# 李子本地后端

这个后端用于给 iOS App 做 AI 辅助解析和 AI 校验题库。当前阶段可以先跑在你的 Windows 电脑上，手机和电脑在同一个 Wi-Fi/热点下即可访问。

## 启动

```powershell
cd backend
$env:LIZI_AI_KEY="你的新密钥"
.\run_local_backend.ps1
```

没有配置 `LIZI_AI_KEY` 时，后端会用本地兜底解析返回结果，效果不如 AI。

## App 里填写

先查电脑局域网 IP：

```powershell
ipconfig
```

例如电脑 IP 是 `192.168.1.23`，App 的 API URL 填：

```text
http://192.168.1.23:8787/api/parse-questions
```

API Key 可以填新密钥；更安全的做法是只在后端设置 `LIZI_AI_KEY`，App 里留空。

## 打包迁移到服务器

```powershell
.\package_backend.ps1
```

生成：

```text
outputs/lizi-backend.zip
```

以后换服务器，把这个 zip 上传解压，设置环境变量 `LIZI_AI_KEY` 后运行 `python lizi_ai_backend.py` 即可。
