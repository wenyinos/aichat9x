object frmAIChat: TfrmAIChat
  Left = 200
  Top = 100
  Width = 760
  Height = 600
  Caption = 'AI 聊天助手'
  Color = clBtnFace
  Font.Charset = 134
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = '宋体'
  Font.Style = []
  BorderStyle = bsNone
  KeyPreview = True
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  OnKeyDown = FormKeyDown
  OnResize = FormResize
  PixelsPerInch = 96
  TextHeight = 16
  Constraints.MinHeight = 600
  Constraints.MinWidth = 760
  object pnlHeader: TPanel
    Left = 0
    Top = 0
    Width = 760
    Height = 72
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
  end
  object pnlStatus: TPanel
    Left = 0
    Top = 576
    Width = 760
    Height = 24
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object lblStatus: TLabel
      Left = 12
      Top = 4
      Width = 30
      Height = 16
      Caption = '就绪'
    end
    object lblCount: TLabel
      Left = 220
      Top = 4
      Width = 80
      Height = 16
      Caption = '消息数: 0'
    end
    object lblHint: TLabel
      Left = 420
      Top = 4
      Width = 100
      Height = 16
      Caption = '右键复制消息'
    end
  end
  object pnlInput: TPanel
    Left = 0
    Top = 484
    Width = 760
    Height = 92
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    object DividerTop: TPanel
      Left = 0
      Top = 0
      Width = 760
      Height = 1
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 0
    end
    object lblInput: TLabel
      Left = 16
      Top = 10
      Width = 220
      Height = 16
      Caption = 'Enter 发送 · Shift+Enter 换行'
    end
    object memInput: TMemo
      Left = 16
      Top = 34
      Width = 624
      Height = 44
      Anchors = [akTop, akLeft, akRight]
      BorderStyle = bsNone
      TabOrder = 1
      OnKeyDown = memInputKeyDown
    end
  end
  object pnlChatHost: TPanel
    Left = 0
    Top = 72
    Width = 760
    Height = 412
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 3
  end
end
