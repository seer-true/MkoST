object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'frmMain'
  ClientHeight = 494
  ClientWidth = 624
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  TextHeight = 15
  object Memo1: TMemo
    Left = 0
    Top = 0
    Width = 624
    Height = 454
    Align = alClient
    Lines.Strings = (
      'Memo1')
    TabOrder = 0
    ExplicitWidth = 620
    ExplicitHeight = 440
  end
  object Panel1: TPanel
    Left = 0
    Top = 454
    Width = 624
    Height = 40
    Align = alBottom
    TabOrder = 1
    object btnDll: TButton
      Left = 30
      Top = 6
      Width = 75
      Height = 25
      Caption = 'btnDll'
      TabOrder = 0
      OnClick = btnDllClick
    end
    object btnSearch: TButton
      Left = 131
      Top = 6
      Width = 75
      Height = 25
      Caption = 'btnSearch'
      TabOrder = 1
      OnClick = btnSearchClick
    end
    object btnBinSearch: TButton
      Left = 228
      Top = 6
      Width = 75
      Height = 25
      Caption = 'btnBinSearch'
      TabOrder = 2
      OnClick = btnBinSearchClick
    end
  end
  object OpenDialog1: TOpenDialog
    Left = 340
    Top = 130
  end
end
