unit AIChatHttp;

interface

{ Send JSON body to proxy; returns UTF-8 JSON response.
  ABody must be UTF-8 encoded JSON. AToken may be empty. }
function HttpPost(const AHost: string; APort: Word;
  const APath, AToken, ABody: string; JsonMode: Boolean): string;

{ Simple GET request for /ping health check. Returns body or '' on error. }
function HttpGet(const AHost: string; APort: Word;
  const APath: string): string;

implementation

uses Windows, SysUtils, WinInet;

const
  HTTP_CONNECT_TIMEOUT = 30000;  // 30 s
  HTTP_READ_TIMEOUT    = 300000; // 5 min (AI replies can be slow)

procedure ApplyTimeouts(hReq: HINTERNET);
var
  T: DWORD;
begin
  T := HTTP_CONNECT_TIMEOUT;
  InternetSetOption(hReq, INTERNET_OPTION_CONNECT_TIMEOUT, @T, SizeOf(T));
  T := HTTP_READ_TIMEOUT;
  InternetSetOption(hReq, INTERNET_OPTION_RECEIVE_TIMEOUT, @T, SizeOf(T));
end;

function HttpPost(const AHost: string; APort: Word;
  const APath, AToken, ABody: string; JsonMode: Boolean): string;
var
  hSes, hCon, hReq: HINTERNET;
  hdr: string;
  buf: array[0..4095] of AnsiChar;
  n: DWORD;
  BodyBytes: AnsiString;
  Code: DWORD;
begin
  Result := '';
  hSes := InternetOpen('AIChat/1.0', INTERNET_OPEN_TYPE_DIRECT, nil, nil, 0);
  if hSes = nil then Exit;
  try
    hCon := InternetConnect(hSes, PChar(AHost), APort,
      nil, nil, INTERNET_SERVICE_HTTP, 0, 0);
    if hCon = nil then
    begin
      Result := '错误: 无法连接代理';
      Exit;
    end;
    try
      hReq := HttpOpenRequest(hCon, 'POST', PChar(APath),
        'HTTP/1.1', nil, nil,
        INTERNET_FLAG_RELOAD or INTERNET_FLAG_NO_UI, 0);
      if hReq = nil then Exit;
      try
        ApplyTimeouts(hReq);
        if JsonMode then
          BodyBytes := UTF8Encode(ABody)
        else
          BodyBytes := AnsiString(ABody);
        if JsonMode then
          hdr := 'Content-Type: application/json; charset=utf-8' + #13#10
               + 'Content-Length: ' + IntToStr(Length(BodyBytes)) + #13#10
        else
          hdr := 'Content-Type: text/plain; charset=gbk' + #13#10
               + 'Content-Length: ' + IntToStr(Length(BodyBytes)) + #13#10;
        if AToken <> '' then
          hdr := hdr + 'X-AIChat-Token: ' + AToken + #13#10;
        if not HttpSendRequest(hReq, PChar(hdr), Length(hdr),
          PAnsiChar(BodyBytes), Length(BodyBytes)) then
        begin
          Code := GetLastError;
          if Code = ERROR_INTERNET_TIMEOUT then
            Result := '错误: 连接超时'
          else
            Result := '错误: 发送失败（代码 ' + IntToStr(Code) + '）';
          Exit;
        end;
        repeat
          FillChar(buf, SizeOf(buf), 0);
          if not InternetReadFile(hReq, @buf, SizeOf(buf), n) then Break;
          if n > 0 then Result := Result + Copy(buf, 1, n);
        until n = 0;
        if JsonMode and (Result <> '') then
          Result := UTF8Decode(Result);
      finally
        InternetCloseHandle(hReq);
      end;
    finally
      InternetCloseHandle(hCon);
    end;
  except
    on E: Exception do
    begin
      Code := GetLastError;
      if Code = ERROR_INTERNET_TIMEOUT then
        Result := '错误: 请求超时'
      else if Code = ERROR_INTERNET_CANNOT_CONNECT then
        Result := '错误: 连接被拒绝'
      else
        Result := '错误: ' + E.Message + '（代码 ' + IntToStr(Code) + '）';
    end;
  end;
  InternetCloseHandle(hSes);
end;

function HttpGet(const AHost: string; APort: Word;
  const APath: string): string;
var
  hSes, hCon, hReq: HINTERNET;
  buf: array[0..4095] of AnsiChar;
  n: DWORD;
begin
  Result := '';
  hSes := InternetOpen('AIChat/1.0', INTERNET_OPEN_TYPE_DIRECT, nil, nil, 0);
  if hSes = nil then Exit;
  try
    hCon := InternetConnect(hSes, PChar(AHost), APort,
      nil, nil, INTERNET_SERVICE_HTTP, 0, 0);
    if hCon = nil then Exit;
    try
      hReq := HttpOpenRequest(hCon, 'GET', PChar(APath),
        'HTTP/1.1', nil, nil,
        INTERNET_FLAG_RELOAD or INTERNET_FLAG_NO_UI, 0);
      if hReq = nil then Exit;
      try
        ApplyTimeouts(hReq);
        if not HttpSendRequest(hReq, nil, 0, nil, 0) then Exit;
        repeat
          FillChar(buf, SizeOf(buf), 0);
          if not InternetReadFile(hReq, @buf, SizeOf(buf), n) then Break;
          if n > 0 then Result := Result + Copy(buf, 1, n);
        until n = 0;
      finally
        InternetCloseHandle(hReq);
      end;
    finally
      InternetCloseHandle(hCon);
    end;
  finally
    InternetCloseHandle(hSes);
  end;
end;

end.
