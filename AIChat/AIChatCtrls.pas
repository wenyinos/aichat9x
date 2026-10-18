unit AIChatCtrls;

interface

uses
  Windows, Messages, Classes, SysUtils, Graphics, Controls, Menus, Clipbrd;

type
  TGlowStyle = (gbGhost, gbPrimary);
  TWindowButtonKind = (wbMinimize, wbMaximize, wbRestore, wbClose);

  { 1. TGradientPanel - purple gradient header with logo and text }
  TGradientPanel = class(TGraphicControl)
  private
    FColorFrom: TColor;
    FColorTo: TColor;
    FTitle: string;
    FSubTitle: string;
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property ColorFrom: TColor read FColorFrom write FColorFrom;
    property ColorTo: TColor read FColorTo write FColorTo;
    property Title: string read FTitle write FTitle;
    property SubTitle: string read FSubTitle write FSubTitle;
    property OnMouseDown;
  end;

  { 2. TGlowButton - pill button with ghost/primary styles }
  TGlowButton = class(TCustomControl)
  private
    FMouseIn: Boolean;
    FDown: Boolean;
    FBtnCaption: string;
    FButtonStyle: TGlowStyle;
    FOnClick: TNotifyEvent;
    procedure WMEraseBkgnd(var Msg: TWMEraseBkgnd); message WM_ERASEBKGND;
  protected
    procedure Paint; override;
    procedure CreateWnd; override;
    procedure SetBounds(ALeft, ATop, AWidth, AHeight: Integer); override;
    procedure UpdateRegion;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure CMMouseEnter(var Msg: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Msg: TMessage); message CM_MOUSELEAVE;
    procedure Click; dynamic;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property BtnCaption: string read FBtnCaption write FBtnCaption;
    property ButtonStyle: TGlowStyle read FButtonStyle write FButtonStyle;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
  end;

  { 3. TWindowButton - caption-less window control button }
  TWindowButton = class(TCustomControl)
  private
    FKind: TWindowButtonKind;
    FMouseIn: Boolean;
    FDown: Boolean;
    FOnClick: TNotifyEvent;
    procedure SetKind(AValue: TWindowButtonKind);
    procedure WMEraseBkgnd(var Msg: TWMEraseBkgnd); message WM_ERASEBKGND;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure CMMouseEnter(var Msg: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Msg: TMessage); message CM_MOUSELEAVE;
    procedure Click; dynamic;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Kind: TWindowButtonKind read FKind write SetKind;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
  end;

  { 4. TChatBubblePanel - dark chat area with cards, avatars and hero state }
  PChatMsg = ^TChatMsg;
  TChatMsg = record
    Role: string;
    Text: string;
    Time: string;
    Top: Integer;
    Bottom: Integer;
  end;

  TChatBubblePanel = class(TCustomControl)
  private
    FList: TList;
    FScrollY: Integer;
    FTotalHeight: Integer;
    FPopup: TPopupMenu;
    FHitIndex: Integer;
    procedure WMEraseBkgnd(var Msg: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure WMSize(var Msg: TWMSize); message WM_SIZE;
    procedure WMMouseWheel(var Msg: TMessage); message WM_MOUSEWHEEL;
    procedure WMVScroll(var Msg: TWMScroll); message WM_VSCROLL;
    procedure UpdateScrollbar;
    function HitTest(Y: Integer): Integer;
    procedure DoCopyOne(Sender: TObject);
    procedure DoCopyAll(Sender: TObject);
    procedure DrawHero;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AddMsg(const ARole, AText: string);
    procedure Clear;
    procedure ScrollToEnd;
  end;

implementation

function RoleDisplayName(const ARole: string): string;
begin
  if SameText(ARole, 'You') then
    Result := '你'
  else if SameText(ARole, 'System') then
    Result := '系统'
  else
    Result := ARole;
end;

procedure SetUIFont(AFont: TFont; ASize: Integer);
begin
  AFont.Charset := GB2312_CHARSET;
  AFont.Name := '宋体';
  AFont.Size := ASize;
end;

function DrawTextT(ACanvas: TCanvas; const AText: string;
  const ARect: TRect; AFlags: Integer): Integer;
var
  R: TRect;
begin
  R := ARect;
  SetBkMode(ACanvas.Handle, TRANSPARENT);
  Result := DrawText(ACanvas.Handle, PAnsiChar(AText), -1, R, AFlags);
end;

procedure PaintRoundRect(ACanvas: TCanvas; const R: TRect;
  Radius: Integer; AColor: TColor);
begin
  ACanvas.Brush.Color := AColor;
  ACanvas.Pen.Color := AColor;
  ACanvas.RoundRect(R.Left, R.Top, R.Right, R.Bottom, Radius, Radius);
end;

{ TGradientPanel }

constructor TGradientPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  FColorFrom := RGB(124, 92, 255);
  FColorTo := RGB(58, 36, 140);
  Width := 240;
  Height := 72;
end;

procedure TGradientPanel.Paint;
var
  I, R1, G1, B1, R2, G2, B2: Integer;
  Ratio: Double;
  R: TRect;
begin
  R1 := GetRValue(FColorFrom); G1 := GetGValue(FColorFrom); B1 := GetBValue(FColorFrom);
  R2 := GetRValue(FColorTo);   G2 := GetGValue(FColorTo);   B2 := GetBValue(FColorTo);
  for I := 0 to Height - 1 do
  begin
    if Height > 1 then Ratio := I / (Height - 1) else Ratio := 0;
    Canvas.Pen.Color := RGB(
      R1 + Round((R2 - R1) * Ratio),
      G1 + Round((G2 - G1) * Ratio),
      B1 + Round((B2 - B1) * Ratio));
    Canvas.MoveTo(0, I);
    Canvas.LineTo(Width, I);
  end;
  SetBkMode(Canvas.Handle, TRANSPARENT);

  { Logo tile: white rounded square with purple "AI" }
  R := Rect(18, 16, 58, 56);
  PaintRoundRect(Canvas, R, 12, RGB(245, 243, 255));
  SetUIFont(Canvas.Font, 12);
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := RGB(78, 52, 190);
  DrawTextT(Canvas, 'AI', R,
    DT_CENTER or DT_VCENTER or DT_SINGLELINE);

  { Title and subtitle }
  SetUIFont(Canvas.Font, 14);
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := clWhite;
  R := Rect(72, 10, Width - 300, 38);
  DrawTextT(Canvas, FTitle, R,
    DT_LEFT or DT_SINGLELINE or DT_END_ELLIPSIS);

  SetUIFont(Canvas.Font, 9);
  Canvas.Font.Style := [];
  Canvas.Font.Color := RGB(210, 200, 245);
  R := Rect(72, 38, Width - 300, 60);
  DrawTextT(Canvas, FSubTitle, R,
    DT_LEFT or DT_SINGLELINE or DT_END_ELLIPSIS);
end;

{ TGlowButton }

constructor TGlowButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque, csDoubleClicks];
  Width := 80;
  Height := 28;
  FMouseIn := False;
  FDown := False;
  FButtonStyle := gbGhost;
end;

procedure TGlowButton.WMEraseBkgnd(var Msg: TWMEraseBkgnd);
begin
  Msg.Result := 1;
end;

procedure TGlowButton.CreateWnd;
begin
  inherited;
  UpdateRegion;
end;

procedure TGlowButton.SetBounds(ALeft, ATop, AWidth, AHeight: Integer);
begin
  inherited;
  UpdateRegion;
end;

procedure TGlowButton.UpdateRegion;
var
  Rgn: HRGN;
begin
  if HandleAllocated then
  begin
    { Clip the window to a pill so the corners show the parent background. }
    Rgn := CreateRoundRectRgn(0, 0, Width + 1, Height + 1, Height, Height);
    if Rgn <> 0 then
      if SetWindowRgn(Handle, Rgn, True) = 0 then
        DeleteObject(Rgn);
  end;
end;

procedure TGlowButton.Paint;
var
  R: TRect;
  Bg, Bd, Tx: TColor;
begin
  R := ClientRect;
  if FButtonStyle = gbPrimary then
  begin
    if not Enabled then
    begin Bg := RGB(150, 140, 175); Bd := Bg; Tx := RGB(225, 220, 240); end
    else if FDown then
    begin Bg := RGB(210, 202, 245); Bd := Bg; Tx := RGB(70, 45, 170); end
    else if FMouseIn then
    begin Bg := RGB(255, 255, 255); Bd := Bg; Tx := RGB(70, 45, 170); end
    else
    begin Bg := RGB(245, 243, 255); Bd := Bg; Tx := RGB(70, 45, 170); end;
  end
  else
  begin
    if not Enabled then
    begin Bg := RGB(46, 34, 86); Bd := RGB(60, 46, 110); Tx := RGB(120, 110, 155); end
    else if FDown then
    begin Bg := RGB(52, 34, 120); Bd := RGB(150, 130, 235); Tx := clWhite; end
    else if FMouseIn then
    begin Bg := RGB(96, 72, 200); Bd := RGB(180, 165, 255); Tx := clWhite; end
    else
    begin Bg := RGB(72, 50, 160); Bd := RGB(130, 110, 220); Tx := clWhite; end;
  end;
  Canvas.Brush.Color := Bg;
  Canvas.Pen.Color := Bd;
  Canvas.RoundRect(0, 0, Width, Height, Height, Height);
  SetBkMode(Canvas.Handle, TRANSPARENT);
  SetUIFont(Canvas.Font, 9);
  Canvas.Font.Color := Tx;
  DrawTextT(Canvas, FBtnCaption, R,
    DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_END_ELLIPSIS);
end;

procedure TGlowButton.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  inherited;
  if Button = mbLeft then begin FDown := True; Invalidate; end;
end;

procedure TGlowButton.MouseUp(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  inherited;
  if FDown then begin FDown := False; Invalidate; Click; end;
end;

procedure TGlowButton.CMMouseEnter(var Msg: TMessage);
begin
  FMouseIn := True; Invalidate;
end;

procedure TGlowButton.CMMouseLeave(var Msg: TMessage);
begin
  FMouseIn := False; FDown := False; Invalidate;
end;

procedure TGlowButton.Click;
begin
  if Assigned(FOnClick) then FOnClick(Self);
end;

{ TWindowButton }

constructor TWindowButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque, csDoubleClicks];
  Width := 32;
  Height := 28;
  FKind := wbMinimize;
  FMouseIn := False;
  FDown := False;
end;

procedure TWindowButton.WMEraseBkgnd(var Msg: TWMEraseBkgnd);
begin
  Msg.Result := 1;
end;

procedure TWindowButton.SetKind(AValue: TWindowButtonKind);
begin
  if FKind <> AValue then
  begin
    FKind := AValue;
    Invalidate;
  end;
end;

procedure TWindowButton.Paint;
var
  Bg: TColor;
  X, Y: Integer;
begin
  if not Enabled then
    Bg := RGB(84, 62, 170)
  else if FKind = wbClose then
  begin
    if FDown then Bg := RGB(160, 30, 40)
    else if FMouseIn then Bg := RGB(220, 50, 60)
    else Bg := RGB(91, 64, 198);
  end
  else
  begin
    if FDown then Bg := RGB(70, 48, 160)
    else if FMouseIn then Bg := RGB(120, 94, 230)
    else Bg := RGB(91, 64, 198);
  end;

  Canvas.Brush.Color := Bg;
  Canvas.Pen.Color := Bg;
  Canvas.FillRect(ClientRect);

  Canvas.Pen.Color := clWhite;
  Canvas.Pen.Width := 1;
  X := Width div 2;
  Y := Height div 2;
  case FKind of
    wbMinimize:
      begin
        Canvas.MoveTo(X - 6, Y + 4);
        Canvas.LineTo(X + 6, Y + 4);
      end;
    wbMaximize:
      Canvas.Rectangle(X - 6, Y - 5, X + 6, Y + 5);
    wbRestore:
      begin
        Canvas.Rectangle(X - 2, Y - 6, X + 7, Y + 1);
        Canvas.Rectangle(X - 7, Y - 1, X + 2, Y + 6);
      end;
    wbClose:
      begin
        Canvas.MoveTo(X - 5, Y - 5);
        Canvas.LineTo(X + 5, Y + 5);
        Canvas.MoveTo(X + 5, Y - 5);
        Canvas.LineTo(X - 5, Y + 5);
      end;
  end;
end;

procedure TWindowButton.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  inherited;
  if Button = mbLeft then begin FDown := True; Invalidate; end;
end;

procedure TWindowButton.MouseUp(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  inherited;
  if FDown then begin FDown := False; Invalidate; Click; end;
end;

procedure TWindowButton.CMMouseEnter(var Msg: TMessage);
begin
  FMouseIn := True; Invalidate;
end;

procedure TWindowButton.CMMouseLeave(var Msg: TMessage);
begin
  FMouseIn := False; FDown := False; Invalidate;
end;

procedure TWindowButton.Click;
begin
  if Assigned(FOnClick) then FOnClick(Self);
end;

{ TChatBubblePanel }

constructor TChatBubblePanel.Create(AOwner: TComponent);
var
  Item: TMenuItem;
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  FList := TList.Create;
  FScrollY := 0;
  FTotalHeight := 0;
  FHitIndex := -1;
  Width := 200;
  Height := 200;

  FPopup := TPopupMenu.Create(Self);
  Item := TMenuItem.Create(FPopup);
  Item.Caption := '复制此条';
  Item.OnClick := DoCopyOne;
  FPopup.Items.Add(Item);
  Item := TMenuItem.Create(FPopup);
  Item.Caption := '复制全部';
  Item.OnClick := DoCopyAll;
  FPopup.Items.Add(Item);
end;

destructor TChatBubblePanel.Destroy;
begin
  Clear;
  FPopup.Free;
  FList.Free;
  inherited;
end;

procedure TChatBubblePanel.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := Params.Style or WS_VSCROLL;
end;

procedure TChatBubblePanel.WMEraseBkgnd(var Msg: TWMEraseBkgnd);
begin
  Msg.Result := 1;
end;

procedure TChatBubblePanel.UpdateScrollbar;
var
  si: TScrollInfo;
begin
  if not HandleAllocated then Exit;
  FillChar(si, SizeOf(si), 0);
  si.cbSize := SizeOf(si);
  si.fMask := SIF_RANGE or SIF_PAGE or SIF_POS;
  si.nMin := 0;
  si.nMax := FTotalHeight;
  si.nPage := Height;
  if FTotalHeight > Height then
    si.nPos := -FScrollY
  else
    si.nPos := 0;
  SetScrollInfo(Handle, SB_VERT, si, True);
end;

procedure TChatBubblePanel.WMVScroll(var Msg: TWMScroll);
var
  si: TScrollInfo;
  NewPos: Integer;
begin
  si.cbSize := SizeOf(si);
  si.fMask := SIF_ALL;
  GetScrollInfo(Handle, SB_VERT, si);
  NewPos := si.nPos;
  case Msg.ScrollCode of
    SB_LINEUP:        Dec(NewPos, 24);
    SB_LINEDOWN:      Inc(NewPos, 24);
    SB_PAGEUP:        Dec(NewPos, Integer(si.nPage));
    SB_PAGEDOWN:      Inc(NewPos, Integer(si.nPage));
    SB_THUMBPOSITION: NewPos := si.nTrackPos;
    SB_THUMBTRACK:    NewPos := si.nTrackPos;
    SB_TOP:           NewPos := 0;
    SB_BOTTOM:        NewPos := si.nMax;
  end;
  if NewPos < 0 then NewPos := 0;
  if NewPos > si.nMax - Integer(si.nPage) then
    NewPos := si.nMax - Integer(si.nPage);
  if NewPos < 0 then NewPos := 0;
  FScrollY := -NewPos;
  UpdateScrollbar;
  Invalidate;
end;

function TChatBubblePanel.HitTest(Y: Integer): Integer;
var
  I: Integer;
  M: PChatMsg;
begin
  Result := -1;
  for I := 0 to FList.Count - 1 do
  begin
    M := PChatMsg(FList[I]);
    if (Y >= M^.Top) and (Y <= M^.Bottom) then
    begin
      Result := I;
      Exit;
    end;
  end;
end;

procedure TChatBubblePanel.DoCopyOne(Sender: TObject);
var
  M: PChatMsg;
begin
  if (FHitIndex >= 0) and (FHitIndex < FList.Count) then
  begin
    M := PChatMsg(FList[FHitIndex]);
    Clipboard.AsText := M^.Text;
  end;
end;

procedure TChatBubblePanel.DoCopyAll(Sender: TObject);
var
  I: Integer;
  S: string;
  M: PChatMsg;
begin
  S := '';
  for I := 0 to FList.Count - 1 do
  begin
    M := PChatMsg(FList[I]);
    if S <> '' then S := S + #13#10;
    S := S + RoleDisplayName(M^.Role) + ': ' + M^.Text;
  end;
  Clipboard.AsText := S;
end;

procedure TChatBubblePanel.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  P: TPoint;
begin
  inherited;
  if Button = mbRight then
  begin
    FHitIndex := HitTest(Y);
    P := ClientToScreen(Point(X, Y));
    FPopup.Popup(P.X, P.Y);
  end;
end;

procedure TChatBubblePanel.AddMsg(const ARole, AText: string);
var
  M: PChatMsg;
begin
  New(M);
  M^.Role := ARole;
  M^.Text := AText;
  M^.Time := FormatDateTime('hh:nn', Now);
  M^.Top := 0;
  M^.Bottom := 0;
  FList.Add(M);
  ScrollToEnd;
  Invalidate;
end;

procedure TChatBubblePanel.Clear;
var
  I: Integer;
begin
  for I := 0 to FList.Count - 1 do
    Dispose(PChatMsg(FList[I]));
  FList.Clear;
  FScrollY := 0;
  FTotalHeight := 0;
  UpdateScrollbar;
  Invalidate;
end;

procedure TChatBubblePanel.ScrollToEnd;
var
  TotalH: Integer;
begin
  TotalH := FTotalHeight;
  if FList.Count > 0 then
    Inc(TotalH, 80);
  if TotalH > Height then
    FScrollY := -(TotalH - Height + 20)
  else
    FScrollY := 0;
  UpdateScrollbar;
  Invalidate;
end;

procedure TChatBubblePanel.WMSize(var Msg: TWMSize);
begin
  inherited;
  if FScrollY > 0 then FScrollY := 0;
  UpdateScrollbar;
  Invalidate;
end;

procedure TChatBubblePanel.WMMouseWheel(var Msg: TMessage);
var
  D, MaxScroll: Integer;
begin
  D := SmallInt(HiWord(Msg.WParam));
  FScrollY := FScrollY + (D div 120) * 48;
  MaxScroll := FTotalHeight - Height;
  if MaxScroll < 0 then MaxScroll := 0;
  if -FScrollY > MaxScroll then FScrollY := -MaxScroll;
  if FScrollY > 0 then FScrollY := 0;
  UpdateScrollbar;
  Invalidate;
end;

procedure TChatBubblePanel.DrawHero;
var
  R: TRect;
  CY: Integer;
begin
  CY := Height div 2 - 90;
  if CY < 32 then CY := 32;

  R := Rect((ClientWidth - 56) div 2, CY, (ClientWidth + 56) div 2, CY + 56);
  PaintRoundRect(Canvas, R, 16, RGB(124, 92, 255));
  SetBkMode(Canvas.Handle, TRANSPARENT);
  SetUIFont(Canvas.Font, 16);
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := clWhite;
  DrawTextT(Canvas, 'AI', R,
    DT_CENTER or DT_VCENTER or DT_SINGLELINE);

  SetUIFont(Canvas.Font, 16);
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := clWhite;
  R := Rect(0, CY + 76, ClientWidth, CY + 110);
  DrawTextT(Canvas, 'AI 聊天助手', R,
    DT_CENTER or DT_SINGLELINE);

  SetUIFont(Canvas.Font, 10);
  Canvas.Font.Style := [];
  Canvas.Font.Color := RGB(200, 190, 235);
  R := Rect(0, CY + 116, ClientWidth, CY + 142);
  DrawTextT(Canvas, '随时开始一段对话', R,
    DT_CENTER or DT_SINGLELINE);

  SetUIFont(Canvas.Font, 8);
  Canvas.Font.Color := RGB(140, 130, 180);
  R := Rect(0, CY + 150, ClientWidth, CY + 172);
  DrawTextT(Canvas, 'Enter 发送 · Shift+Enter 换行 · 右键复制消息', R,
    DT_CENTER or DT_SINGLELINE);
end;

procedure TChatBubblePanel.Paint;
var
  I, Y, MaxW, W, TH: Integer;
  M: PChatMsg;
  BR, TR, AR: TRect;
  Bg, TxC: TColor;
  IsUser, IsSys: Boolean;
const
  AvatarSize = 24;
  Gap = 12;
begin
  Canvas.Brush.Color := RGB(24, 16, 54);
  Canvas.FillRect(ClientRect);

  if FList.Count = 0 then
  begin
    DrawHero;
    FTotalHeight := 0;
    UpdateScrollbar;
    Exit;
  end;

  Y := 14 + FScrollY;
  MaxW := ClientWidth * 68 div 100;
  if MaxW < 180 then MaxW := 180;

  for I := 0 to FList.Count - 1 do
  begin
    M := PChatMsg(FList[I]);
    IsUser := SameText(M^.Role, 'You');
    IsSys := SameText(M^.Role, 'System');

    if IsSys then
    begin
      SetUIFont(Canvas.Font, 9);
      Canvas.Font.Color := RGB(150, 140, 190);
      TR := Rect(24, Y, ClientWidth - 24, Y + 2000);
      TH := DrawTextT(Canvas, M^.Text, TR,
        DT_CENTER or DT_WORDBREAK or DT_CALCRECT);
      TR := Rect(24, Y, ClientWidth - 24, Y + TH);
      DrawTextT(Canvas, M^.Text, TR, DT_CENTER or DT_WORDBREAK);
      Y := Y + TH + 14;
      Continue;
    end;

    { Estimate a compact card width from the text length. }
    W := Length(M^.Text) * 6 + 28;
    if W > MaxW then W := MaxW;
    if W < 150 then W := 150;

    if IsUser then
    begin
      BR := Rect(ClientWidth - 44 - W, Y, ClientWidth - 44, 0);
      AR := Rect(ClientWidth - 34, Y + 2, ClientWidth - 10, Y + 2 + AvatarSize);
    end
    else
    begin
      BR := Rect(44, Y, 44 + W, 0);
      AR := Rect(10, Y + 2, 10 + AvatarSize, Y + 2 + AvatarSize);
    end;

    TR := Rect(BR.Left + 12, Y + 22, BR.Right - 12, Y + 2000);
    SetUIFont(Canvas.Font, 9);
    TH := DrawTextT(Canvas, M^.Text, TR,
      DT_WORDBREAK or DT_CALCRECT);
    BR.Bottom := Y + 22 + TH + 10;

    if IsUser then begin Bg := RGB(108, 76, 240); TxC := clWhite; end
    else begin Bg := RGB(44, 32, 88); TxC := RGB(235, 230, 250); end;

    PaintRoundRect(Canvas, BR, 12, Bg);

    { Avatar circle with role initial }
    if IsUser then PaintRoundRect(Canvas, AR, AvatarSize, RGB(124, 92, 255))
    else PaintRoundRect(Canvas, AR, AvatarSize, RGB(86, 64, 180));
    SetBkMode(Canvas.Handle, TRANSPARENT);
    SetUIFont(Canvas.Font, 7);
    Canvas.Font.Color := clWhite;
    if IsUser then
      DrawTextT(Canvas, '你', AR,
        DT_CENTER or DT_VCENTER or DT_SINGLELINE)
    else
      DrawTextT(Canvas, 'AI', AR,
        DT_CENTER or DT_VCENTER or DT_SINGLELINE);

    { Role name and timestamp }
    SetUIFont(Canvas.Font, 8);
    SetBkMode(Canvas.Handle, TRANSPARENT);
    Canvas.Font.Color := RGB(210, 200, 240);
    Canvas.TextOut(BR.Left + 12, BR.Top + 5, RoleDisplayName(M^.Role));
    if M^.Time <> '' then
    begin
      Canvas.Font.Color := RGB(160, 150, 200);
      Canvas.TextOut(BR.Left + 12 +
        Canvas.TextWidth(RoleDisplayName(M^.Role)) + 8,
        BR.Top + 5, M^.Time);
    end;

    { Message body }
    SetUIFont(Canvas.Font, 9);
    Canvas.Font.Color := TxC;
    TR := Rect(BR.Left + 12, BR.Top + 22, BR.Right - 12, BR.Bottom - 10);
    DrawTextT(Canvas, M^.Text, TR, DT_WORDBREAK);

    M^.Top := BR.Top;
    M^.Bottom := BR.Bottom;

    Y := BR.Bottom + Gap;
    if Y > Height + 2000 then Break;
  end;

  FTotalHeight := Y - FScrollY - 14;
  if FTotalHeight < 0 then FTotalHeight := 0;
  UpdateScrollbar;
end;

end.
