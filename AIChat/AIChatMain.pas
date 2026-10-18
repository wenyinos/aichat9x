unit AIChatMain;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, Menus, Registry, AIChatCtrls, AIChatHttp;

const
  WM_AI_REPLY      = WM_USER + 101;
  MAX_HISTORY_MSGS = 200;  // 最多发送最近 200 条消息（约 100 轮问答）

type
  THistoryItem = record
    Role: string;
    Content: string;
  end;

  TSendThread = class(TThread)
  private
    FHost: string;
    FPort: Word;
    FToken: string;
    FBody: string;
    FWnd: HWND;
    FReply: string;
  protected
    procedure Execute; override;
  public
    constructor Create(AWnd: HWND; const AHost: string; APort: Word;
      const AToken, ABody: string);
    property Reply: string read FReply;
  end;

  TfrmAIChat = class(TForm)
    pnlHeader: TPanel;
    pnlStatus: TPanel;
    lblStatus: TLabel;
    lblCount: TLabel;
    lblHint: TLabel;
    pnlInput: TPanel;
    DividerTop: TPanel;
    lblInput: TLabel;
    memInput: TMemo;
    pnlChatHost: TPanel;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormResize(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure btnSendClick(Sender: TObject);
    procedure memInputKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure Clear1Click(Sender: TObject);
    procedure Exit1Click(Sender: TObject);
    procedure About1Click(Sender: TObject);
    procedure Settings1Click(Sender: TObject);
    procedure TestConn1Click(Sender: TObject);
    procedure LoadChat1Click(Sender: TObject);
    procedure SaveChat1Click(Sender: TObject);
    procedure BtnMinClick(Sender: TObject);
    procedure BtnMaxClick(Sender: TObject);
    procedure BtnCloseClick(Sender: TObject);
    procedure BtnMoreClick(Sender: TObject);
    procedure HeaderMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
  private
    FMsgCount: Integer;
    FProxyHost: string;
    FProxyPort: Word;
    FProxyToken: string;
    FHistory: array of THistoryItem;
    FSendThread: TSendThread;
    FGradient: TGradientPanel;
    FChat: TChatBubblePanel;
    FBtnSettings: TGlowButton;
    FBtnClear: TGlowButton;
    FBtnMore: TGlowButton;
    FBtnMin: TWindowButton;
    FBtnMax: TWindowButton;
    FBtnClose: TWindowButton;
    FBtnSend: TGlowButton;
    FMoreMenu: TPopupMenu;
    procedure WMAIReply(var Msg: TMessage); message WM_AI_REPLY;
    procedure WMGetMinMaxInfo(var Msg: TWMGetMinMaxInfo);
      message WM_GETMINMAXINFO;
    procedure LoadConfig;
    procedure SaveConfig;
    procedure AddMoreItem(const ACaption: string; AShortCut: TShortCut;
      AHandler: TNotifyEvent);
    procedure AddMessage(const ARole, AText: string);
    procedure UpdateStatus;
    procedure SaveChatToFile;
    procedure LoadChatFromFile;
    function EncodeMessages: AnsiString;
  public
  end;

var
  frmAIChat: TfrmAIChat;

implementation

{$R *.dfm}

const
  REG_KEY = 'Software\AIChat9x';

type
  TSettingsForm = class(TForm)
  private
    FEditHost: TEdit;
    FEditPort: TEdit;
    FEditToken: TEdit;
    FBtnSave: TGlowButton;
    FBtnCancel: TGlowButton;
    FBtnClose: TWindowButton;
    FHost: string;
    FPort: Word;
    FToken: string;
    procedure SaveClick(Sender: TObject);
    procedure CancelClick(Sender: TObject);
    procedure EditKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure FormPaint(Sender: TObject);
    procedure WMNCHitTest(var Msg: TWMNCHitTest); message WM_NCHITTEST;
    function GetSelHost: string;
    function GetSelPort: Word;
    function GetSelToken: string;
  public
    constructor CreateSettings(AOwner: TComponent);
    procedure SetValues(const AHost: string; APort: Word;
      const AToken: string);
    property SelHost: string read GetSelHost;
    property SelPort: Word read GetSelPort;
    property SelToken: string read GetSelToken;
  end;

constructor TSettingsForm.CreateSettings(AOwner: TComponent);
var
  L: TLabel;
begin
  inherited CreateNew(AOwner);
  Caption := '设置';
  BorderStyle := bsNone;
  Position := poMainFormCenter;
  ClientWidth := 400;
  ClientHeight := 320;
  Color := RGB(24, 16, 54);
  Font.Charset := GB2312_CHARSET;
  Font.Name := '宋体';
  Font.Size := 9;
  Font.Color := clWhite;
  KeyPreview := True;
  OnKeyDown := FormKeyDown;
  OnPaint := FormPaint;

  FBtnClose := TWindowButton.Create(Self);
  FBtnClose.Parent := Self;
  FBtnClose.Kind := wbClose;
  FBtnClose.SetBounds(ClientWidth - 36, 8, 28, 24);
  FBtnClose.OnClick := CancelClick;

  L := TLabel.Create(Self);
  L.Parent := Self;
  L.Left := 24;
  L.Top := 58;
  L.Caption := '代理地址';
  L.Font.Color := RGB(200, 190, 235);

  FEditHost := TEdit.Create(Self);
  FEditHost.Parent := Self;
  FEditHost.Font.Charset := GB2312_CHARSET;
  FEditHost.Font.Name := '宋体';
  FEditHost.Font.Size := 10;
  FEditHost.Font.Color := clWhite;
  FEditHost.Color := RGB(38, 26, 80);
  FEditHost.BorderStyle := bsNone;
  FEditHost.SetBounds(24, 78, 352, 24);
  FEditHost.OnKeyDown := EditKeyDown;

  L := TLabel.Create(Self);
  L.Parent := Self;
  L.Left := 24;
  L.Top := 114;
  L.Caption := '端口';
  L.Font.Color := RGB(200, 190, 235);

  FEditPort := TEdit.Create(Self);
  FEditPort.Parent := Self;
  FEditPort.Font.Charset := GB2312_CHARSET;
  FEditPort.Font.Name := '宋体';
  FEditPort.Font.Size := 10;
  FEditPort.Font.Color := clWhite;
  FEditPort.Color := RGB(38, 26, 80);
  FEditPort.BorderStyle := bsNone;
  FEditPort.SetBounds(24, 134, 120, 24);
  FEditPort.OnKeyDown := EditKeyDown;

  L := TLabel.Create(Self);
  L.Parent := Self;
  L.Left := 24;
  L.Top := 170;
  L.Caption := '访问令牌（留空则关闭鉴权）';
  L.Font.Color := RGB(200, 190, 235);

  FEditToken := TEdit.Create(Self);
  FEditToken.Parent := Self;
  FEditToken.Font.Charset := GB2312_CHARSET;
  FEditToken.Font.Name := '宋体';
  FEditToken.Font.Size := 10;
  FEditToken.Font.Color := clWhite;
  FEditToken.Color := RGB(38, 26, 80);
  FEditToken.BorderStyle := bsNone;
  FEditToken.SetBounds(24, 190, 352, 24);
  FEditToken.OnKeyDown := EditKeyDown;

  L := TLabel.Create(Self);
  L.Parent := Self;
  L.Left := 24;
  L.Top := 232;
  L.Caption := '保存后立即生效，配置保存在当前用户的注册表中。';
  L.Font.Size := 8;
  L.Font.Color := RGB(150, 140, 190);

  FBtnSave := TGlowButton.Create(Self);
  FBtnSave.Parent := Self;
  FBtnSave.ButtonStyle := gbPrimary;
  FBtnSave.BtnCaption := '保存';
  FBtnSave.SetBounds(204, 274, 80, 30);
  FBtnSave.OnClick := SaveClick;

  FBtnCancel := TGlowButton.Create(Self);
  FBtnCancel.Parent := Self;
  FBtnCancel.ButtonStyle := gbGhost;
  FBtnCancel.BtnCaption := '取消';
  FBtnCancel.SetBounds(296, 274, 80, 30);
  FBtnCancel.OnClick := CancelClick;

  ActiveControl := FEditHost;
end;

procedure TSettingsForm.SetValues(const AHost: string; APort: Word;
  const AToken: string);
begin
  FEditHost.Text := AHost;
  FEditPort.Text := IntToStr(APort);
  FEditToken.Text := AToken;
end;

procedure TSettingsForm.SaveClick(Sender: TObject);
var
  P: Integer;
begin
  P := StrToIntDef(Trim(FEditPort.Text), -1);
  if (Trim(FEditHost.Text) = '') or (P < 1) or (P > 65535) then
  begin
    MessageDlg('请输入有效的代理地址和端口（1-65535）。', mtError, [mbOK], 0);
    FEditHost.SetFocus;
    Exit;
  end;
  FHost := Trim(FEditHost.Text);
  FPort := P;
  FToken := Trim(FEditToken.Text);
  ModalResult := mrOk;
end;

procedure TSettingsForm.CancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TSettingsForm.EditKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    Key := 0;
    SaveClick(nil);
  end;
end;

procedure TSettingsForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
  begin
    Key := 0;
    ModalResult := mrCancel;
  end;
end;

procedure TSettingsForm.FormPaint(Sender: TObject);
var
  I, R1, G1, B1, R2, G2, B2: Integer;
  Ratio: Double;
begin
  R1 := 124; G1 := 92; B1 := 255;
  R2 := 58;  G2 := 36; B2 := 140;
  for I := 0 to 39 do
  begin
    Ratio := I / 39;
    Canvas.Pen.Color := RGB(
      R1 + Round((R2 - R1) * Ratio),
      G1 + Round((G2 - G1) * Ratio),
      B1 + Round((B2 - B1) * Ratio));
    Canvas.MoveTo(0, I);
    Canvas.LineTo(ClientWidth, I);
  end;
  Canvas.Pen.Color := RGB(70, 52, 140);
  Canvas.MoveTo(0, 40);
  Canvas.LineTo(ClientWidth, 40);

  Canvas.Font.Charset := GB2312_CHARSET;
  Canvas.Font.Name := '宋体';
  Canvas.Font.Size := 10;
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := clWhite;
  SetBkMode(Canvas.Handle, TRANSPARENT);
  Canvas.TextOut(16, 12, '设置');
end;

procedure TSettingsForm.WMNCHitTest(var Msg: TWMNCHitTest);
var
  P: TPoint;
begin
  inherited;
  P := ScreenToClient(Point(Msg.XPos, Msg.YPos));
  if (P.Y >= 0) and (P.Y < 40) then
    Msg.Result := HTCAPTION
  else
    Msg.Result := HTCLIENT;
end;

function TSettingsForm.GetSelHost: string;
begin
  Result := FHost;
end;

function TSettingsForm.GetSelPort: Word;
begin
  Result := FPort;
end;

function TSettingsForm.GetSelToken: string;
begin
  Result := FToken;
end;

function ChatFilePath: string;
begin
  Result := ChangeFileExt(Application.ExeName, '.chat');
end;

function JsonEscape(const S: string): string;
var
  I: Integer;
  C: Char;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    { Copy GBK double-byte characters as a unit: a trail byte may be 0x5C. }
    if ByteType(S, I) = mbLeadByte then
    begin
      Result := Result + S[I] + S[I + 1];
      Inc(I, 2);
      Continue;
    end;
    C := S[I];
    case C of
      '"':  Result := Result + '\"';
      '\':  Result := Result + '\\';
      #13:  ; // drop CR
      #10:  Result := Result + '\n';
      #9:   Result := Result + '\t';
    else
      if (Ord(C) >= 32) then
        Result := Result + C
      else
        Result := Result + '\u00' + IntToHex(Ord(C), 2);
    end;
    Inc(I);
  end;
end;

function JsonUnescape(const S: string): string;
var
  I, Code: Integer;
  C: Char;
  W: WideChar;
  Buf: array[0..7] of AnsiChar;
  N: Integer;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    { Preserve GBK double-byte characters; a trail byte may be 0x5C. }
    if ByteType(S, I) = mbLeadByte then
    begin
      Result := Result + S[I] + S[I + 1];
      Inc(I, 2);
      Continue;
    end;
    C := S[I];
    if C <> '\' then
    begin
      Result := Result + C;
      Inc(I);
      Continue;
    end;
    Inc(I);
    if I > Length(S) then Break;
    C := S[I];
    case C of
      '"': Result := Result + '"';
      '\': Result := Result + '\';
      '/': Result := Result + '/';
      'n': Result := Result + #10;
      'r': Result := Result + #13;
      't': Result := Result + #9;
      'b': Result := Result + #8;
      'f': Result := Result + #12;
      'u':
        begin
          if I + 4 <= Length(S) then
          begin
            Code := StrToIntDef('$' + Copy(S, I + 1, 4), -1);
            if Code >= 0 then
            begin
              Inc(I, 4);
              if Code < 256 then
                Result := Result + Chr(Code)
              else
              begin
                W := WideChar(Code);
                N := WideCharToMultiByte(CP_ACP, 0, @W, 1, Buf, SizeOf(Buf),
                  nil, nil);
                if N > 0 then
                  Result := Result + Copy(Buf, 1, N)
                else
                  Result := Result + '?';
              end;
            end;
          end;
        end;
    else
      Result := Result + C;
    end;
    Inc(I);
  end;
end;

{ TSendThread }

constructor TSendThread.Create(AWnd: HWND; const AHost: string; APort: Word;
  const AToken, ABody: string);
begin
  inherited Create(True);
  FWnd := AWnd;
  FHost := AHost;
  FPort := APort;
  FToken := AToken;
  FBody := ABody;
end;

procedure TSendThread.Execute;
begin
  FReply := HttpPost(FHost, FPort, '/chat', FToken, FBody, True);
  PostMessage(FWnd, WM_AI_REPLY, 0, 0);
end;

function TfrmAIChat.EncodeMessages: AnsiString;
var
  I, Start, Count: Integer;
  S: AnsiString;
  Item: THistoryItem;
begin
  { Keep only the most recent conversational messages. }
  Count := 0;
  I := High(FHistory);
  while (I >= 0) and (Count < MAX_HISTORY_MSGS) do
  begin
    if (FHistory[I].Role = 'You') or (FHistory[I].Role = 'AI') then
      Inc(Count);
    Dec(I);
  end;
  Start := I + 1;
  { Never start the payload with an assistant turn. }
  while (Start <= High(FHistory)) and (FHistory[Start].Role <> 'You') do
    Inc(Start);

  S := '{"messages":[';
  Count := 0;
  for I := Start to High(FHistory) do
  begin
    Item := FHistory[I];
    if (Item.Role <> 'You') and (Item.Role <> 'AI') then Continue;
    if Count > 0 then S := S + ',';
    S := S + '{"role":"' + AnsiString(Item.Role) + '","content":"'
       + AnsiString(JsonEscape(Item.Content)) + '"}';
    Inc(Count);
  end;
  Result := S + ']}';
end;

function ParseReply(const JsonStr: string; out Error: string): string;
var
  P1, P2: Integer;
begin
  Result := '';
  Error := '';
  // Check for "error":"<non-empty>"
  P1 := Pos('"error"', JsonStr);
  if P1 > 0 then
  begin
    Inc(P1, 7);
    while (P1 <= Length(JsonStr)) and (JsonStr[P1] <> '"') do Inc(P1);
    if P1 < Length(JsonStr) then
    begin
      Inc(P1);
      P2 := P1;
      while (P2 <= Length(JsonStr)) and (JsonStr[P2] <> '"') do Inc(P2);
      if (P2 > P1) then
      begin
        Error := JsonUnescape(Copy(JsonStr, P1, P2 - P1));
        Exit;
      end;
    end;
  end;
  // Extract "reply":"..."
  P1 := Pos('"reply"', JsonStr);
  if P1 = 0 then Exit;
  Inc(P1, 7);
  while (P1 <= Length(JsonStr)) and (JsonStr[P1] <> '"') do Inc(P1);
  if P1 >= Length(JsonStr) then Exit;
  Inc(P1);
  P2 := P1;
  while P2 <= Length(JsonStr) do
  begin
    if ByteType(JsonStr, P2) = mbLeadByte then
      Inc(P2, 2) // skip GBK double-byte char
    else if (JsonStr[P2] = '\') and (P2 < Length(JsonStr)) then
      Inc(P2, 2) // skip escaped char
    else if JsonStr[P2] = '"' then
      Break
    else
      Inc(P2);
  end;
  Result := JsonUnescape(Copy(JsonStr, P1, P2 - P1));
end;

procedure TfrmAIChat.LoadConfig;
var
  Reg: TRegistry;
begin
  FProxyHost := '127.0.0.1';
  FProxyPort := 8080;
  FProxyToken := '';
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKeyReadOnly(REG_KEY) then
    begin
      if Reg.ValueExists('ProxyHost') then
        FProxyHost := Reg.ReadString('ProxyHost');
      if Reg.ValueExists('ProxyPort') then
        FProxyPort := Reg.ReadInteger('ProxyPort');
      if Reg.ValueExists('ProxyToken') then
        FProxyToken := Reg.ReadString('ProxyToken');
      Reg.CloseKey;
    end;
  finally
    Reg.Free;
  end;
end;

procedure TfrmAIChat.SaveConfig;
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey(REG_KEY, True) then
    begin
      Reg.WriteString('ProxyHost', FProxyHost);
      Reg.WriteInteger('ProxyPort', FProxyPort);
      Reg.WriteString('ProxyToken', FProxyToken);
      Reg.CloseKey;
    end;
  finally
    Reg.Free;
  end;
end;

procedure TfrmAIChat.AddMessage(const ARole, AText: string);
var
  Len: Integer;
begin
  FChat.AddMsg(ARole, AText);
  Inc(FMsgCount);
  Len := Length(FHistory);
  SetLength(FHistory, Len + 1);
  FHistory[Len].Role := ARole;
  FHistory[Len].Content := AText;
  UpdateStatus;
end;

procedure TfrmAIChat.UpdateStatus;
begin
  lblStatus.Caption := '就绪';
  lblCount.Caption := '消息数: ' + IntToStr(FMsgCount);
end;

procedure TfrmAIChat.AddMoreItem(const ACaption: string; AShortCut: TShortCut;
  AHandler: TNotifyEvent);
var
  It: TMenuItem;
begin
  It := TMenuItem.Create(FMoreMenu);
  It.Caption := ACaption;
  if AShortCut <> 0 then It.ShortCut := AShortCut;
  It.OnClick := AHandler;
  FMoreMenu.Items.Add(It);
end;

procedure TfrmAIChat.FormCreate(Sender: TObject);
begin
  FMsgCount := 0;
  LoadConfig;

  { Purple theme }
  Color := RGB(24, 16, 54);
  pnlHeader.Color := RGB(58, 36, 140);
  pnlInput.Color := RGB(24, 16, 54);
  pnlChatHost.Color := RGB(24, 16, 54);
  pnlStatus.Color := RGB(18, 11, 42);
  DividerTop.Color := RGB(74, 52, 150);

  lblStatus.Font.Charset := GB2312_CHARSET;
  lblStatus.Font.Name := '宋体';
  lblStatus.Font.Size := 8;
  lblStatus.Font.Color := RGB(170, 160, 210);
  lblCount.Font.Charset := GB2312_CHARSET;
  lblCount.Font.Name := '宋体';
  lblCount.Font.Size := 8;
  lblCount.Font.Color := RGB(170, 160, 210);
  lblHint.Font.Charset := GB2312_CHARSET;
  lblHint.Font.Name := '宋体';
  lblHint.Font.Size := 8;
  lblHint.Font.Color := RGB(150, 140, 190);

  lblInput.Font.Charset := GB2312_CHARSET;
  lblInput.Font.Name := '宋体';
  lblInput.Font.Size := 8;
  lblInput.Font.Color := RGB(150, 140, 190);

  memInput.Color := RGB(38, 26, 80);
  memInput.Font.Charset := GB2312_CHARSET;
  memInput.Font.Name := '宋体';
  memInput.Font.Size := 9;
  memInput.Font.Color := clWhite;

  FGradient := TGradientPanel.Create(Self);
  FGradient.Parent := pnlHeader;
  FGradient.Align := alClient;
  FGradient.ColorFrom := RGB(124, 92, 255);
  FGradient.ColorTo := RGB(58, 36, 140);
  FGradient.Title := 'AI 聊天助手';
  FGradient.SubTitle := '代理: ' + FProxyHost + ':' + IntToStr(FProxyPort);
  FGradient.OnMouseDown := HeaderMouseDown;
  pnlHeader.OnMouseDown := HeaderMouseDown;

  FBtnSettings := TGlowButton.Create(Self);
  FBtnSettings.Parent := pnlHeader;
  FBtnSettings.ButtonStyle := gbGhost;
  FBtnSettings.SetBounds(pnlHeader.Width - 284, 22, 56, 28);
  FBtnSettings.Anchors := [akTop, akRight];
  FBtnSettings.BtnCaption := '设置';
  FBtnSettings.OnClick := Settings1Click;

  FBtnClear := TGlowButton.Create(Self);
  FBtnClear.Parent := pnlHeader;
  FBtnClear.ButtonStyle := gbGhost;
  FBtnClear.SetBounds(pnlHeader.Width - 224, 22, 56, 28);
  FBtnClear.Anchors := [akTop, akRight];
  FBtnClear.BtnCaption := '清空';
  FBtnClear.OnClick := Clear1Click;

  FBtnMore := TGlowButton.Create(Self);
  FBtnMore.Parent := pnlHeader;
  FBtnMore.ButtonStyle := gbGhost;
  FBtnMore.SetBounds(pnlHeader.Width - 164, 22, 56, 28);
  FBtnMore.Anchors := [akTop, akRight];
  FBtnMore.BtnCaption := '更多';
  FBtnMore.OnClick := BtnMoreClick;

  FBtnMin := TWindowButton.Create(Self);
  FBtnMin.Parent := pnlHeader;
  FBtnMin.Kind := wbMinimize;
  FBtnMin.SetBounds(pnlHeader.Width - 104, 22, 32, 28);
  FBtnMin.Anchors := [akTop, akRight];
  FBtnMin.OnClick := BtnMinClick;

  FBtnMax := TWindowButton.Create(Self);
  FBtnMax.Parent := pnlHeader;
  FBtnMax.Kind := wbMaximize;
  FBtnMax.SetBounds(pnlHeader.Width - 72, 22, 32, 28);
  FBtnMax.Anchors := [akTop, akRight];
  FBtnMax.OnClick := BtnMaxClick;

  FBtnClose := TWindowButton.Create(Self);
  FBtnClose.Parent := pnlHeader;
  FBtnClose.Kind := wbClose;
  FBtnClose.SetBounds(pnlHeader.Width - 40, 22, 32, 28);
  FBtnClose.Anchors := [akTop, akRight];
  FBtnClose.OnClick := BtnCloseClick;

  FMoreMenu := TPopupMenu.Create(Self);
  AddMoreItem('测试连接', ShortCut(VK_F5, []), TestConn1Click);
  AddMoreItem('加载对话', ShortCut(Ord('O'), [ssCtrl]), LoadChat1Click);
  AddMoreItem('保存对话', ShortCut(Ord('S'), [ssCtrl]), SaveChat1Click);
  AddMoreItem('-', 0, nil);
  AddMoreItem('关于', 0, About1Click);
  AddMoreItem('退出', 0, Exit1Click);

  FBtnSend := TGlowButton.Create(Self);
  FBtnSend.Parent := pnlInput;
  FBtnSend.ButtonStyle := gbPrimary;
  FBtnSend.SetBounds(pnlInput.Width - 104, 34, 88, 36);
  FBtnSend.Anchors := [akTop, akRight];
  FBtnSend.BtnCaption := '发送';
  FBtnSend.OnClick := btnSendClick;

  FChat := TChatBubblePanel.Create(Self);
  FChat.Parent := pnlChatHost;
  FChat.Align := alClient;

  UpdateStatus;
  OnClose := FormClose;
  ActiveControl := memInput;
end;

procedure TfrmAIChat.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if Assigned(FSendThread) then
  begin
    { Do not block shutdown waiting for a slow HTTP call. }
    FSendThread.FreeOnTerminate := True;
    FSendThread := nil;
  end;
end;

procedure TfrmAIChat.FormResize(Sender: TObject);
begin
  if Assigned(FBtnMax) then
  begin
    if WindowState = wsMaximized then
      FBtnMax.Kind := wbRestore
    else
      FBtnMax.Kind := wbMaximize;
  end;
end;

procedure TfrmAIChat.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if ssCtrl in Shift then
  begin
    case Key of
      Ord('N'): begin Key := 0; Clear1Click(Self); end;
      Ord('O'): begin Key := 0; LoadChat1Click(Self); end;
      Ord('S'): begin Key := 0; SaveChat1Click(Self); end;
    end;
  end
  else if Key = VK_F5 then
  begin
    Key := 0;
    TestConn1Click(Self);
  end;
end;

procedure TfrmAIChat.BtnMinClick(Sender: TObject);
begin
  WindowState := wsMinimized;
end;

procedure TfrmAIChat.BtnMaxClick(Sender: TObject);
begin
  if WindowState = wsMaximized then
    WindowState := wsNormal
  else
    WindowState := wsMaximized;
end;

procedure TfrmAIChat.BtnCloseClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmAIChat.BtnMoreClick(Sender: TObject);
var
  P: TPoint;
begin
  P := FBtnMore.ClientToScreen(Point(0, FBtnMore.Height));
  FMoreMenu.Popup(P.X, P.Y);
end;

procedure TfrmAIChat.HeaderMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
  begin
    if WindowState = wsMaximized then Exit;
    ReleaseCapture;
    Perform(WM_NCLBUTTONDOWN, HTCAPTION, 0);
  end;
end;

procedure TfrmAIChat.WMGetMinMaxInfo(var Msg: TWMGetMinMaxInfo);
var
  R: TRect;
begin
  inherited;
  if SystemParametersInfo(SPI_GETWORKAREA, 0, @R, 0) then
  begin
    Msg.MinMaxInfo^.ptMaxPosition := Point(R.Left, R.Top);
    Msg.MinMaxInfo^.ptMaxSize := Point(R.Right - R.Left, R.Bottom - R.Top);
  end;
end;

procedure TfrmAIChat.btnSendClick(Sender: TObject);
var
  UserMsg: string;
begin
  if Assigned(FSendThread) then Exit;
  UserMsg := Trim(memInput.Text);
  if UserMsg = '' then Exit;
  AddMessage('You', UserMsg);
  memInput.Clear;
  memInput.SetFocus;
  lblStatus.Caption := '正在思考...';
  FBtnSend.Enabled := False;
  FBtnSend.BtnCaption := '发送中...';
  Screen.Cursor := crHourGlass;
  FSendThread := TSendThread.Create(Handle, FProxyHost, FProxyPort,
    FProxyToken, string(EncodeMessages));
  FSendThread.Resume;
end;

procedure TfrmAIChat.WMAIReply(var Msg: TMessage);
var
  Reply, Err: string;
begin
  if not Assigned(FSendThread) then Exit;
  Reply := FSendThread.Reply;
  FSendThread.Free;
  FSendThread := nil;

  FBtnSend.Enabled := True;
  FBtnSend.BtnCaption := '发送';
  Screen.Cursor := crDefault;

  if Reply = '' then
    Reply := '错误: 代理无响应'
  else if Pos('错误: ', Reply) = 1 then
    { already an error message, show as-is }
  else if Reply[1] = '{' then
  begin
    Err := '';
    Reply := ParseReply(Reply, Err);
    if Err <> '' then
      Reply := '错误: ' + Err
    else if Reply = '' then
      Reply := '错误: AI 返回内容为空';
  end;

  AddMessage('AI', Reply);
  UpdateStatus;
  memInput.SetFocus;
end;

procedure TfrmAIChat.memInputKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    if ssShift in Shift then Exit; { Shift+Enter inserts a newline }
    Key := 0;
    btnSendClick(Self);
  end;
end;

procedure TfrmAIChat.Settings1Click(Sender: TObject);
var
  Dlg: TSettingsForm;
begin
  Dlg := TSettingsForm.CreateSettings(Self);
  try
    Dlg.SetValues(FProxyHost, FProxyPort, FProxyToken);
    if Dlg.ShowModal = mrOk then
    begin
      FProxyHost := Dlg.SelHost;
      FProxyPort := Dlg.SelPort;
      FProxyToken := Dlg.SelToken;
      SaveConfig;
      FGradient.SubTitle := '代理: ' + FProxyHost + ':' + IntToStr(FProxyPort);
      lblStatus.Caption := '设置已保存';
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TfrmAIChat.TestConn1Click(Sender: TObject);
var
  Reply: string;
begin
  Screen.Cursor := crHourGlass;
  try
    Reply := HttpGet(FProxyHost, FProxyPort, '/status');
  finally
    Screen.Cursor := crDefault;
  end;
  if Reply = '' then
    MessageDlg('无法连接代理 ' + FProxyHost + ':'
      + IntToStr(FProxyPort) + #13#10 + #13#10 +
      '请确认 proxy.py 正在运行，且「设置」中的地址和端口正确。',
      mtError, [mbOK], 0)
  else
    MessageDlg('代理连接正常。' + #13#10 + #13#10 + Reply,
      mtInformation, [mbOK], 0);
end;

procedure TfrmAIChat.SaveChatToFile;
var
  F: TextFile;
  I: Integer;
begin
  AssignFile(F, ChatFilePath);
  Rewrite(F);
  try
    for I := 0 to High(FHistory) do
      if FHistory[I].Role <> 'System' then
        WriteLn(F, '[' + FHistory[I].Role + '] ' + FHistory[I].Content);
  finally
    CloseFile(F);
  end;
end;

procedure TfrmAIChat.LoadChatFromFile;
var
  F: TextFile;
  Line, Role, Content: string;
  P: Integer;
begin
  if not FileExists(ChatFilePath) then Exit;
  { Replace the current conversation instead of appending duplicates. }
  FChat.Clear;
  FMsgCount := 0;
  SetLength(FHistory, 0);
  AssignFile(F, ChatFilePath);
  Reset(F);
  try
    while not Eof(F) do
    begin
      ReadLn(F, Line);
      if (Length(Line) > 3) and (Line[1] = '[') then
      begin
        P := Pos('] ', Line);
        if P > 2 then
        begin
          Role := Copy(Line, 2, P - 2);
          Content := Copy(Line, P + 2, MaxInt);
          FChat.AddMsg(Role, Content);
          Inc(FMsgCount);
          SetLength(FHistory, Length(FHistory) + 1);
          FHistory[High(FHistory)].Role := Role;
          FHistory[High(FHistory)].Content := Content;
        end;
      end;
    end;
  finally
    CloseFile(F);
  end;
end;

procedure TfrmAIChat.SaveChat1Click(Sender: TObject);
begin
  SaveChatToFile;
  MessageDlg('对话已保存至 ' + ChatFilePath, mtInformation, [mbOK], 0);
end;

procedure TfrmAIChat.LoadChat1Click(Sender: TObject);
begin
  LoadChatFromFile;
  UpdateStatus;
end;

procedure TfrmAIChat.Clear1Click(Sender: TObject);
begin
  FChat.Clear;
  FMsgCount := 0;
  SetLength(FHistory, 0);
  UpdateStatus;
  memInput.SetFocus;
end;

procedure TfrmAIChat.Exit1Click(Sender: TObject);
begin
  Close;
end;

procedure TfrmAIChat.About1Click(Sender: TObject);
begin
  MessageDlg('AI 聊天助手' + #13#10 +
    '版本 1.2' + #13#10 + #13#10 +
    '代理: ' + FProxyHost + ':' + IntToStr(FProxyPort) + #13#10 +
    '基于 Delphi 7 + WinInet 构建。',
    mtInformation, [mbOK], 0);
end;

end.
