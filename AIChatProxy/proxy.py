"""
AIChatProxy - HTTP proxy for Delphi 7 AI Chat on legacy Windows.
Receives plain-text HTTP POST (GBK-encoded) or JSON, forwards to AI API via HTTPS.

Usage:
  1. Copy .env.example to .env and set your API key
  2. pip install -r requirements.txt
  3. python proxy.py
"""

import json
import logging
import os
import sys

from dotenv import load_dotenv
import requests
from flask import Flask, request, Response

load_dotenv(os.path.join(os.path.dirname(os.path.abspath(__file__)), '.env'))

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s'
)
log = logging.getLogger('aiproxy')

API_KEY    = os.getenv('AICHAT_API_KEY', '')
API_BASE   = os.getenv('AICHAT_API_BASE', 'https://api.openai.com/v1')
MODEL      = os.getenv('AICHAT_MODEL', 'gpt-3.5-turbo')
MAX_TOK    = int(os.getenv('AICHAT_MAX_TOKENS', '1024'))
TIMEOUT    = int(os.getenv('AICHAT_TIMEOUT', '60'))
HOST       = os.getenv('AICHAT_HOST', '0.0.0.0')
PORT       = int(os.getenv('AICHAT_PORT', '8080'))
SYS_PROMPT = os.getenv('AICHAT_SYSTEM_PROMPT', '')
SECRET     = os.getenv('AICHAT_SHARED_SECRET', '')
LOG_MSGS   = os.getenv('AICHAT_LOG_MESSAGES', '0') == '1'

if not API_KEY or API_KEY == 'sk-your-key-here':
    log.error('Set AICHAT_API_KEY in .env file')
    sys.exit(1)

if SYS_PROMPT:
    log.info('System prompt loaded (%d chars)', len(SYS_PROMPT))

app = Flask(__name__)


def decode_client_text(raw_bytes):
    """Decode raw POST body from legacy Windows client.
    The Delphi client sends GBK (Chinese Windows ANSI); UTF-8 is the fallback.
    """
    try:
        return raw_bytes.decode('gbk')
    except UnicodeDecodeError:
        return raw_bytes.decode('utf-8', errors='replace')


def json_error(msg, status=400):
    """Return a UTF-8 JSON error response."""
    body = json.dumps({'reply': '', 'error': msg}, ensure_ascii=False)
    return Response(body.encode('utf-8'), status=status,
                    mimetype='application/json; charset=utf-8')


def json_ok(reply):
    """Return a UTF-8 JSON success response."""
    body = json.dumps({'reply': reply, 'error': ''}, ensure_ascii=False)
    return Response(body.encode('utf-8'),
                    mimetype='application/json; charset=utf-8')


def call_ai_api(messages):
    """Call the AI chat completions API with a messages list.
    Returns (reply_text, error_str).
    """
    payload = {'model': MODEL, 'max_tokens': MAX_TOK, 'messages': messages}
    headers = {'Authorization': f'Bearer {API_KEY}',
               'Content-Type': 'application/json'}
    try:
        r = requests.post(f'{API_BASE}/chat/completions',
                          json=payload, headers=headers, timeout=TIMEOUT)
        r.raise_for_status()
        reply = r.json()['choices'][0]['message']['content'].strip()
        return reply, ''
    except requests.exceptions.Timeout:
        log.error('API timeout after %ds', TIMEOUT)
        return '', 'AI 接口请求超时'
    except requests.exceptions.ConnectionError as e:
        log.error('API connection error: %s', e)
        return '', '无法连接 AI 接口服务器'
    except requests.exceptions.HTTPError:
        log.error('API returned %d', r.status_code)
        return '', f'AI 接口返回 HTTP {r.status_code}'
    except Exception as e:
        log.error('Unexpected error: %s', e)
        return '', '代理内部错误'


@app.route('/chat', methods=['POST'])
def chat():
    if SECRET and request.headers.get('X-AIChat-Token', '') != SECRET:
        if 'json' in (request.content_type or ''):
            return json_error('访问令牌无效', 401)
        return Response('错误: 访问令牌无效'.encode('gbk'), status=401,
                        mimetype='text/plain; charset=gbk')

    content_type = request.content_type or ''
    raw = request.get_data()

    # --- JSON mode: client sends {"messages": [...]} ---
    if 'json' in content_type:
        try:
            data = json.loads(raw.decode('utf-8'))
        except (json.JSONDecodeError, UnicodeDecodeError):
            return json_error('无效的 JSON')
        messages = data.get('messages', [])
        if not isinstance(messages, list) or not messages:
            return json_error('消息列表为空')
        log.info('JSON request with %d messages', len(messages))
    else:
        # --- Legacy plain-text mode ---
        user_msg = decode_client_text(raw).strip()
        if not user_msg:
            return Response('错误: 消息为空'.encode('gbk'), status=400,
                            mimetype='text/plain; charset=gbk')
        if LOG_MSGS:
            log.info('Text request: %.80s', user_msg)
        else:
            log.info('Text request: %d chars', len(user_msg))
        # Parse multi-turn: "You: msg\nAI: reply\nYou: msg"
        messages = []
        for line in user_msg.split('\n'):
            line = line.strip()
            if line.startswith('You: '):
                messages.append({'role': 'user', 'content': line[5:]})
            elif line.startswith('AI: '):
                messages.append({'role': 'assistant', 'content': line[4:]})
        if not messages:
            messages = [{'role': 'user', 'content': user_msg}]

    # Map client display roles to API roles
    role_map = {'You': 'user', 'AI': 'assistant', 'System': 'system'}
    for m in messages:
        m['role'] = role_map.get(m['role'], m['role'])

    # Prepend system prompt if configured and not already present
    if SYS_PROMPT:
        if not messages or messages[0].get('role') != 'system':
            messages.insert(0, {'role': 'system', 'content': SYS_PROMPT})

    reply, error = call_ai_api(messages)

    if error:
        if 'json' in content_type:
            return json_error(error, 502)
        else:
            return Response(f'错误: {error}'.encode('gbk'),
                            status=502, mimetype='text/plain; charset=gbk')

    if LOG_MSGS:
        log.info('Reply: %.80s', reply)
    else:
        log.info('Reply: %d chars', len(reply))

    if 'json' in content_type:
        return json_ok(reply)
    else:
        gbk_bytes = reply.encode('gbk', errors='replace')
        return Response(gbk_bytes, mimetype='text/plain; charset=gbk')


@app.route('/ping', methods=['GET'])
def ping():
    return Response('OK', mimetype='text/plain')


@app.route('/status', methods=['GET'])
def status():
    """Connection test endpoint — returns proxy config (no secrets)."""
    info = {'model': MODEL, 'max_tokens': MAX_TOK, 'timeout': TIMEOUT,
            'has_system_prompt': bool(SYS_PROMPT),
            'auth_enabled': bool(SECRET)}
    body = json.dumps(info, ensure_ascii=False)
    return Response(body.encode('utf-8'),
                    mimetype='application/json; charset=utf-8')


if __name__ == '__main__':
    log.info('AIChatProxy starting on %s:%d (model=%s, auth=%s)',
             HOST, PORT, MODEL, 'on' if SECRET else 'off')
    log.info('Endpoints:  POST /chat   GET /ping   GET /status')
    app.run(host=HOST, port=PORT)
