# AIChat 9x

[English](README.md) | **简体中文**

> 为 Windows 95/NT 等遗留系统打造的 AI 聊天客户端，通过局域网代理实现与现代 AI API 的对话。

---

## 目录

- [简介](#简介)
- [项目架构](#项目架构)
- [快速开始](#快速开始)
- [配置说明](#配置说明)
- [项目结构](#项目结构)
- [技术限制](#技术限制)

---

## 简介

**AIChat 9x** 由两部分组成：

1. **AIChat 客户端** — 基于 Delphi 7 开发的 Windows 桌面应用，使用 WinInet 发送 HTTP 请求，支持 Windows 95/NT 等无法运行现代浏览器的老旧系统。
2. **AIChatProxy 代理** — 基于 Python Flask 的 HTTP 代理服务，负责将客户端的请求转发至远程 AI API（HTTPS），并处理 GBK/UTF-8 编码转换。

**为什么需要代理？** 遗留 Windows 系统不支持现代 TLS 协议，无法直接访问 HTTPS API。客户端通过局域网以明文 HTTP 将请求发送到代理，由代理完成加密通信。

---

## 项目架构

```
+---------------------+     HTTP (JSON, multi-turn)         +------------------+
|   AIChat Client     |  ────────────────────────────────   |  AIChatProxy     |
|   (Delphi 7)        |     {"messages":[...]}              |  (Python Flask)  |
|   Windows 95/NT     |     UTF-8 / token auth              |  LAN server      |
+---------------------+                                     +--------┬─────────+
                                                                    │ HTTPS
                                                                    ▼
                                                         +------------------+
                                                         |   AI API         |
                                                         | (OpenAI 等等)    |
                                                         +------------------+
```

客户端维护多轮对话历史，发送时截取最近 200 条（约 100 轮），以 JSON 格式提交（`{"messages":[...]}`）；代理校验共享令牌后转为标准 messages 数组，自动插入系统提示词。

---

## 快速开始

### 前置条件

- **客户端**：Delphi 7 IDE（用于编译 `AIChat/AIChat.dpr`）
- **代理**：Python 3.8+
- 一台运行代理的局域网机器（可以是现代 Windows、Linux 或 macOS）

### 1. 启动代理

```bash
cd AIChatProxy
cp .env.example .env
# 编辑 .env，填入你的 API Key
pip install -r requirements.txt
python proxy.py
```

验证代理是否运行：

```bash
curl http://localhost:8080/ping    # 健康检查
curl http://localhost:8080/status  # 代理配置信息（不含密钥）
```

### 2. 编译客户端

用 Delphi 7 打开 `AIChat/AIChat.dpr`，按 `Ctrl+F9` 编译。

### 3. 配置客户端

运行客户端后点击右上角「设置」，填写代理地址、端口和访问令牌（可选）。配置保存在当前用户的注册表 `HKEY_CURRENT_USER\Software\AIChat9x` 中，无需手工编辑配置文件。

### 4. 运行

将编译好的 `AIChat.exe` 复制到目标 Windows 95/NT 机器上运行即可。

---

## 配置说明

代理的所有配置通过 `AIChatProxy/.env` 文件管理：

| 变量 | 说明 | 默认值 |
|---|---|---|
| `AICHAT_API_KEY` | AI 服务的 API 密钥 | *(必填)* |
| `AICHAT_API_BASE` | API 基础地址 | `https://api.openai.com/v1` |
| `AICHAT_MODEL` | 使用的模型 | `gpt-3.5-turbo` |
| `AICHAT_MAX_TOKENS` | 最大生成 token 数 | `1024` |
| `AICHAT_TIMEOUT` | 请求超时（秒） | `60` |
| `AICHAT_HOST` | 代理监听地址 | `0.0.0.0` |
| `AICHAT_PORT` | 代理监听端口 | `8080` |
| `AICHAT_SYSTEM_PROMPT` | 自定义系统提示词 | *(空)* |
| `AICHAT_SHARED_SECRET` | 客户端与代理的共享令牌 | *(空)* |
| `AICHAT_LOG_MESSAGES` | 日志记录消息全文，1=开 | `0` |

---

## 项目结构

```
aichat9x/
├── AIChat/                   # Delphi 7 客户端
│   ├── AIChat.dpr            # 项目入口
│   ├── AIChatMain.pas/.dfm   # 主窗体与逻辑
│   ├── AIChatCtrls.pas       # 自绘 UI 控件
│   ├── AIChatHttp.pas        # WinInet HTTP 客户端
│   ├── AIChat.ico            # 16 色复古图标
│   ├── AIChat.res            # 图标资源（MAINICON）
│   ├── AIChat.rc             # 图标资源脚本
│   ├── AIChat.chat           # 聊天记录（运行时生成）
│   └── BIN/                  # 编译输出
│       └── AIChat.exe
├── AIChatProxy/              # Python 代理
│   ├── proxy.py              # 代理服务
│   ├── requirements.txt      # Python 依赖
│   ├── .env.example          # 配置模板
│   └── .env                  # 运行时配置（已忽略）
├── .gitignore
├── AGENTS.md
├── README.md                 # English documentation
└── README.zh-CN.md           # 本文件（简体中文）
```

---

## 技术限制

- **GDI 限制**：客户端仅使用 `gdi32.dll` 和 `user32.dll` 中的 GDI 函数，不依赖 `msimg32.dll`（Windows 95/NT 不提供）。
- **多轮对话**：客户端在内存中维护完整消息历史，发送时截取最近 200 条（约 100 轮）并以 JSON 提交至代理；聊天历史可保存/加载至 `.chat` 文件。
- **界面**：无系统边框的紫色自绘主题（参考 wenyinos.com 视觉风格），包含渐变标题栏、自绘窗口按钮、胶囊按钮、带头像的圆角消息卡片和空状态引导页，应用图标为 16 色复古风格（16×16 + 32×32）。窗口固定 760×600，支持最大化/还原。Enter 发送、Shift+Enter 换行；Ctrl+N 清空、Ctrl+O 加载、Ctrl+S 保存、F5 测试连接；聊天区右键可复制单条或全部消息。
- **编码处理**：客户端与代理间使用 UTF-8 JSON；代理与 AI API 间使用 UTF-8 JSON。代理的纯文本兼容接口使用 GBK。
- **连接测试**：客户端「更多 → 测试连接」可验证代理是否可达。
- **文件编码**：Delphi 源文件（`.pas`、`.dfm`、`.dpr`）必须为 CRLF 换行且不含 BOM；含中文时必须保存为 GBK（CP936），不能使用 UTF-8。
