# AIChat 9x

> 为 Windows 95/NT 等遗留系统打造的 AI 聊天客户端，通过局域网代理实现与现代 AI API 的对话。

> An AI chat client for legacy Windows (95/NT), bridging the gap to modern AI APIs via a LAN proxy.

---

## 目录 / Table of Contents

- [简介 / Introduction](#简介--introduction)
- [项目架构 / Architecture](#项目架构--architecture)
- [快速开始 / Quick Start](#快速开始--quick-start)
- [配置说明 / Configuration](#配置说明--configuration)
- [项目结构 / Project Structure](#项目结构--project-structure)
- [技术限制 / Technical Constraints](#技术限制--technical-constraints)

---

## 简介 / Introduction

**AIChat 9x** 由两部分组成：

1. **AIChat 客户端** — 基于 Delphi 7 开发的 Windows 桌面应用，使用 WinInet 发送 HTTP 请求，支持 Windows 95/NT 等无法运行现代浏览器的老旧系统。
2. **AIChatProxy 代理** — 基于 Python Flask 的 HTTP 代理服务，负责将客户端的明文请求转发至远程 AI API（HTTPS），并处理 GBK/UTF-8 编码转换。

**AIChat 9x** consists of two components:

1. **AIChat Client** — A Delphi 7 Windows desktop application using WinInet for HTTP requests, targeting legacy systems like Windows 95/NT that cannot run modern browsers.
2. **AIChatProxy** — A Python Flask HTTP proxy that forwards plain-text requests from the client to a remote AI API over HTTPS, handling GBK/UTF-8 encoding conversion.

**为什么需要代理？** 遗留 Windows 系统不支持现代 TLS 协议，无法直接访问 HTTPS API。客户端通过局域网以明文 HTTP 将请求发送到代理，由代理完成加密通信。

**Why a proxy?** Legacy Windows systems lack modern TLS support and cannot connect to HTTPS APIs directly. The client sends plain-text HTTP requests to the proxy over the LAN, and the proxy handles the encrypted communication.

---

## 项目架构 / Architecture

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

The client keeps multi-turn history and sends the latest 200 messages (about 100 turns) as JSON (`{"messages":[...]}`). After validating the shared token, the proxy forwards them as a standard messages array and prepends a system prompt if configured.

---

## 快速开始 / Quick Start

### 前置条件 / Prerequisites

- **客户端**：Delphi 7 IDE（用于编译 `AIChat/AIChat.dpr`）
- **代理**：Python 3.8+
- 一台运行代理的局域网机器（可以是现代 Windows、Linux 或 macOS）

### 1. 启动代理 / Start the Proxy

```bash
cd AIChatProxy
cp .env.example .env
# 编辑 .env，填入你的 API Key
# Edit .env and set your API key
pip install -r requirements.txt
python proxy.py
```

验证代理是否运行 / Verify the proxy is running:

```bash
curl http://localhost:8080/ping    # 健康检查 / health check
curl http://localhost:8080/status  # 代理配置信息（不含密钥）/ proxy config (no secrets)
```

### 2. 编译客户端 / Build the Client

用 Delphi 7 打开 `AIChat/AIChat.dpr`，按 `Ctrl+F9` 编译。

Open `AIChat/AIChat.dpr` in Delphi 7 IDE and compile with `Ctrl+F9`.

### 3. 配置客户端 / Configure the Client

运行客户端后点击右上角「设置」，填写代理地址、端口和访问令牌（可选）。配置保存在当前用户的注册表 `HKEY_CURRENT_USER\Software\AIChat9x` 中，无需手工编辑配置文件。

Click 「设置」 (Settings) in the top-right corner after launching the client, then enter the proxy host, port and optional access token. Settings are stored in `HKEY_CURRENT_USER\Software\AIChat9x`, so no config file needs to be edited.

### 4. 运行 / Run

将编译好的 `AIChat.exe` 复制到目标 Windows 95/NT 机器上运行即可。

Copy the compiled `AIChat.exe` to the target Windows 95/NT machine and run.

---

## 配置说明 / Configuration

代理的所有配置通过 `AIChatProxy/.env` 文件管理：

All proxy settings are managed via `AIChatProxy/.env`:

| 变量 / Variable | 说明 / Description | 默认值 / Default |
|---|---|---|
| `AICHAT_API_KEY` | AI 服务的 API 密钥 / API key for the AI service | *(必填 / required)* |
| `AICHAT_API_BASE` | API 基础地址 / API base URL | `https://api.openai.com/v1` |
| `AICHAT_MODEL` | 使用的模型 / Model name | `gpt-3.5-turbo` |
| `AICHAT_MAX_TOKENS` | 最大生成 token 数 / Max tokens to generate | `1024` |
| `AICHAT_TIMEOUT` | 请求超时（秒）/ Request timeout (seconds) | `60` |
| `AICHAT_HOST` | 代理监听地址 / Proxy listen address | `0.0.0.0` |
| `AICHAT_PORT` | 代理监听端口 / Proxy listen port | `8080` |
| `AICHAT_SYSTEM_PROMPT` | 自定义系统提示词 / Custom system prompt | *(空 / empty)* |
| `AICHAT_SHARED_SECRET` | 客户端与代理的共享令牌 / Shared client-proxy token | *(空 / empty)* |
| `AICHAT_LOG_MESSAGES` | 日志记录消息全文，1=开 / Log full message text | `0` |

---

## 项目结构 / Project Structure

```
aichat9x/
├── AIChat/                   # Delphi 7 客户端 / Delphi 7 client
│   ├── AIChat.dpr            # 项目入口 / Project entry point
│   ├── AIChatMain.pas/.dfm   # 主窗体与逻辑 / Main form and logic
│   ├── AIChatCtrls.pas       # 自绘 UI 控件 / Custom-drawn UI controls
│   ├── AIChatHttp.pas        # WinInet HTTP 客户端 / WinInet HTTP client
│   ├── AIChat.ico            # 16 色复古图标 / 16-colour retro icon
│   ├── AIChat.res            # 图标资源（MAINICON）/ Icon resource
│   ├── AIChat.rc             # 图标资源脚本 / Icon resource script
│   ├── AIChat.chat           # 聊天记录（运行时生成）/ Chat history (runtime)
│   └── BIN/                  # 编译输出 / Build output
│       └── AIChat.exe
├── AIChatProxy/              # Python 代理 / Python proxy
│   ├── proxy.py              # 代理服务 / Proxy server
│   ├── requirements.txt      # Python 依赖 / Dependencies
│   ├── .env.example          # 配置模板 / Config template
│   └── .env                  # 运行时配置（已忽略）/ Runtime config (gitignored)
├── .gitignore
├── AGENTS.md
└── README.md
```

---

## 技术限制 / Technical Constraints

- **GDI 限制**：客户端仅使用 `gdi32.dll` 和 `user32.dll` 中的 GDI 函数，不依赖 `msimg32.dll`（Windows 95/NT 不提供）。
- **多轮对话**：客户端在内存中维护完整消息历史，发送时截取最近 200 条（约 100 轮）并以 JSON 提交至代理；聊天历史可保存/加载至 `.chat` 文件。聊天面板右键可复制单条或全部消息。
- **界面**：无系统边框的紫色自绘主题（参考 wenyinos.com 视觉风格），包含渐变标题栏、自绘窗口按钮、胶囊按钮、带头像的圆角消息卡片和空状态引导页，应用图标为 16 色复古风格（16×16 + 32×32）。窗口固定 760×600，支持最大化/还原。Enter 发送、Shift+Enter 换行；Ctrl+N 清空、Ctrl+O 加载、Ctrl+S 保存、F5 测试连接；聊天区右键可复制单条或全部消息。
- **编码处理**：客户端与代理间使用 UTF-8 JSON；代理与 AI API 间使用 UTF-8 JSON。代理的纯文本兼容接口使用 GBK。
- **连接测试**：客户端菜单 `文件 → 测试连接` 可验证代理是否可达。
- **文件编码**：Delphi 源文件（`.pas`、`.dfm`、`.dpr`）必须为 CRLF 换行且不含 BOM；含中文时必须保存为 GBK（CP936），不能使用 UTF-8。
- **GDI limitation**: The client only uses GDI functions from `gdi32.dll` and `user32.dll`; it does not depend on `msimg32.dll` (unavailable on Windows 95/NT).
- **Multi-turn conversation**: The client keeps full history in memory and sends the latest 200 messages (about 100 turns) as JSON. Chat history can be saved/loaded to a `.chat` file. Right-click the chat panel to copy one message or all of them.
- **UI**: Borderless purple self-drawn theme inspired by wenyinos.com, with a gradient title bar, custom window buttons, pill buttons, avatar chat cards, an empty-state hero and a 16-colour retro icon (16x16 + 32x32). The window is fixed at 760×600 with maximize/restore support. Enter sends, Shift+Enter inserts a newline; Ctrl+N clears, Ctrl+O loads, Ctrl+S saves, F5 tests the connection; right-click the chat area to copy one message or all.
- **Encoding**: Client and proxy exchange UTF-8 JSON; proxy and AI API exchange UTF-8 JSON. The proxy's plain-text compatibility endpoint uses GBK.
- **Connection test**: Client menu `文件 → 测试连接` (File → Test Connection) verifies proxy reachability.
- **File encoding**: Delphi source files (`.pas`, `.dfm`, `.dpr`) must use CRLF line endings without BOM; files containing Chinese must be saved as GBK (CP936), never UTF-8.
