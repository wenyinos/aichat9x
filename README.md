# AIChat 9x

**English** | [简体中文](README.zh-CN.md)

> An AI chat client for legacy Windows (95/NT), bridging the gap to modern AI APIs via a LAN proxy.

---

## Table of Contents

- [Introduction](#introduction)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Project Structure](#project-structure)
- [Technical Constraints](#technical-constraints)

---

## Introduction

**AIChat 9x** consists of two components:

1. **AIChat Client** — A Delphi 7 Windows desktop application using WinInet for HTTP requests, targeting legacy systems like Windows 95/NT that cannot run modern browsers.
2. **AIChatProxy** — A Python Flask HTTP proxy that forwards requests from the client to a remote AI API over HTTPS, handling GBK/UTF-8 encoding conversion.

**Why a proxy?** Legacy Windows systems lack modern TLS support and cannot connect to HTTPS APIs directly. The client sends plain-text HTTP requests to the proxy over the LAN, and the proxy handles the encrypted communication.

---

## Architecture

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
                                                         | (OpenAI, etc.)   |
                                                         +------------------+
```

The client keeps multi-turn history and sends the latest 200 messages (about 100 turns) as JSON (`{"messages":[...]}`). After validating the shared token, the proxy forwards them as a standard messages array and prepends a system prompt if configured.

---

## Quick Start

### Prerequisites

- **Client**: Delphi 7 IDE (to compile `AIChat/AIChat.dpr`)
- **Proxy**: Python 3.8+
- A machine on the same LAN to run the proxy (modern Windows, Linux or macOS)

### 1. Start the Proxy

```bash
cd AIChatProxy
cp .env.example .env
# Edit .env and set your API key
pip install -r requirements.txt
python proxy.py
```

Verify the proxy is running:

```bash
curl http://localhost:8080/ping    # health check
curl http://localhost:8080/status  # proxy config (no secrets)
```

### 2. Build the Client

Open `AIChat/AIChat.dpr` in the Delphi 7 IDE and compile with `Ctrl+F9`.

### 3. Configure the Client

Click **Settings** in the top-right corner after launching the client, then enter the proxy host, port and optional access token. Settings are stored in the registry under `HKEY_CURRENT_USER\Software\AIChat9x`, so no config file needs to be edited.

### 4. Run

Copy the compiled `AIChat.exe` to the target Windows 95/NT machine and run it.

---

## Configuration

All proxy settings live in `AIChatProxy/.env`:

| Variable | Description | Default |
|---|---|---|
| `AICHAT_API_KEY` | API key for the AI service | *(required)* |
| `AICHAT_API_BASE` | API base URL | `https://api.openai.com/v1` |
| `AICHAT_MODEL` | Model name | `gpt-3.5-turbo` |
| `AICHAT_MAX_TOKENS` | Max tokens to generate | `1024` |
| `AICHAT_TIMEOUT` | Request timeout (seconds) | `60` |
| `AICHAT_HOST` | Proxy listen address | `0.0.0.0` |
| `AICHAT_PORT` | Proxy listen port | `8080` |
| `AICHAT_SYSTEM_PROMPT` | Custom system prompt | *(empty)* |
| `AICHAT_SHARED_SECRET` | Shared client-proxy token | *(empty)* |
| `AICHAT_LOG_MESSAGES` | Log full message text, 1=on | `0` |

---

## Project Structure

```
aichat9x/
├── AIChat/                   # Delphi 7 client
│   ├── AIChat.dpr            # Project entry point
│   ├── AIChatMain.pas/.dfm   # Main form and logic
│   ├── AIChatCtrls.pas       # Custom-drawn UI controls
│   ├── AIChatHttp.pas        # WinInet HTTP client
│   ├── AIChat.ico            # 16-colour retro icon
│   ├── AIChat.res            # Icon resource (MAINICON)
│   ├── AIChat.rc             # Icon resource script
│   ├── AIChat.chat           # Chat history (runtime)
│   └── BIN/                  # Build output
│       └── AIChat.exe
├── AIChatProxy/              # Python proxy
│   ├── proxy.py              # Proxy server
│   ├── requirements.txt      # Dependencies
│   ├── .env.example          # Config template
│   └── .env                  # Runtime config (gitignored)
├── .gitignore
├── AGENTS.md
├── README.md                 # This file (English)
└── README.zh-CN.md           # Chinese documentation
```

---

## Technical Constraints

- **GDI limitation**: The client only uses GDI functions from `gdi32.dll` and `user32.dll`; it does not depend on `msimg32.dll` (unavailable on Windows 95/NT).
- **Multi-turn conversation**: The client keeps full history in memory and sends the latest 200 messages (about 100 turns) as JSON. Chat history can be saved/loaded to a `.chat` file. Right-click the chat panel to copy one message or all of them.
- **UI**: Borderless purple self-drawn theme inspired by wenyinos.com, with a gradient title bar, custom window buttons, pill buttons, avatar chat cards, an empty-state hero and a 16-colour retro icon (16x16 + 32x32). The window is fixed at 760×600 with maximize/restore support. Enter sends, Shift+Enter inserts a newline; Ctrl+N clears, Ctrl+O loads, Ctrl+S saves, F5 tests the connection; right-click the chat area to copy one message or all.
- **Encoding**: Client and proxy exchange UTF-8 JSON; proxy and AI API exchange UTF-8 JSON. The proxy's plain-text compatibility endpoint uses GBK.
- **Connection test**: Client menu `File → Test Connection` verifies proxy reachability.
- **File encoding**: Delphi source files (`.pas`, `.dfm`, `.dpr`) must use CRLF line endings without BOM; files containing Chinese must be saved as GBK (CP936), never UTF-8.
