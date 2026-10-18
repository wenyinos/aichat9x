# Repository Guidelines

## Project Structure & Module Organization

This project is a two-component AI chat system targeting legacy Windows (95/NT):

- **`AIChat/`** — Delphi 7 client application. Source files: `.pas` (Pascal units), `.dfm` (form definitions), `.dpr` (project file). Client settings (proxy host/port/token) are edited in the in-app Settings dialog and stored under `HKEY_CURRENT_USER\Software\AIChat9x`.
  - `AIChatCtrls.pas` — Custom-drawn UI controls (gradient header, pill buttons, window buttons, avatar chat cards with scrollbar and copy menu)
  - `AIChatHttp.pas` — WinInet-based HTTP POST client
  - `AIChatMain.pas` / `.dfm` — Main form and application logic
  - `AIChat.dpr` — Project entry point
  - `AIChat.ico` / `AIChat.res` / `AIChat.rc` — 16-colour retro application icon (16x16 + 32x32, 4bpp DIB)
- **`AIChatProxy/`** — Python Flask HTTP proxy that bridges legacy clients to modern AI APIs over HTTPS.
  - `proxy.py` — Single-file proxy server
  - `.env` — Runtime configuration (API key, model, port); never commit this file
  - `.env.example` — Template with documented fields

## Build, Test, and Development Commands

**Delphi client** — Open `AIChat/AIChat.dpr` in Delphi 7 IDE, compile with `Ctrl+F9`.

**Python proxy:**
```bash
cd AIChatProxy
pip install -r requirements.txt   # install dependencies
python proxy.py                    # start proxy on port 8080
curl http://localhost:8080/ping    # health check
```

## Coding Style & Naming Conventions

**Delphi (`.pas`, `.dfm`, `.dpr`):**
- All files must use **CRLF** line endings with **no BOM**. Pure-ASCII files stay ASCII; files containing Chinese must be saved as **GBK (CP936)**, never UTF-8.
- Component names use `F` prefix for fields (`FScrollY`), `pnl`/`mem`/`btn`/`lbl` prefixes for UI controls.
- Only use GDI functions from `gdi32.dll`/`user32.dll`; do not depend on `msimg32.dll` (unavailable on Win95/NT).
- DFM component declaration order must match the PAS class field declaration order.

**Python (`proxy.py`):**
- Standard PEP 8 style. Single-file architecture preferred for the proxy.

## Security & Configuration

- Never commit `.env` files or hardcode API keys.
- The proxy handles encoding conversion (Delphi sends GBK, AI returns UTF-8); both directions are converted server-side.
- `AICHAT_SYSTEM_PROMPT` in `.env` allows custom system prompts without code changes.

## Architecture Notes

The proxy exists because legacy Windows cannot handle modern TLS. The client sends JSON over plain-text HTTP to the proxy on the LAN; the proxy validates the shared token, forwards the messages to the AI API over HTTPS, and returns UTF-8 JSON.

The main form uses `BorderStyle = bsNone` with a self-drawn gradient title bar. Dragging is handled in `HeaderMouseDown` via `WM_NCLBUTTONDOWN`/`HTCAPTION`; maximize respects the taskbar work area through `WM_GETMINMAXINFO`.
