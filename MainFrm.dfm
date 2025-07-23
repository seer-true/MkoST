object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'frmMain'
  ClientHeight = 494
  ClientWidth = 666
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  PixelsPerInch = 96
  TextHeight = 15
  object mRes: TMemo
    Left = 0
    Top = 0
    Width = 481
    Height = 454
    Align = alClient
    TabOrder = 0
  end
  object Panel1: TPanel
    Left = 0
    Top = 454
    Width = 666
    Height = 40
    Align = alBottom
    TabOrder = 1
    DesignSize = (
      666
      40)
    object btnDll: TButton
      Left = 157
      Top = 6
      Width = 120
      Height = 25
      Anchors = [akRight, akBottom]
      Caption = #1060'-'#1094#1080#1080' DLL'
      TabOrder = 0
      OnClick = btnDllClick
    end
    object btnSearch: TButton
      Left = 283
      Top = 6
      Width = 120
      Height = 25
      Anchors = [akRight, akBottom]
      Caption = #1055#1086#1080#1089#1082' '#1092#1072#1081#1083#1086#1074
      TabOrder = 1
      OnClick = btnSearchClick
    end
    object btnBinSearch: TButton
      Left = 409
      Top = 6
      Width = 120
      Height = 25
      Anchors = [akRight, akBottom]
      Caption = #1055#1086#1080#1089#1082' '#1074' '#1092#1072#1083#1072#1093
      TabOrder = 2
      OnClick = btnBinSearchClick
    end
    object btnShellCommand: TButton
      Left = 535
      Top = 6
      Width = 120
      Height = 25
      Anchors = [akRight, akBottom]
      Caption = #1040#1088#1093#1080#1074#1080#1088#1086#1074#1072#1085#1080#1077
      TabOrder = 3
      OnClick = btnShellCommandClick
    end
  end
  object grpAtrFiles: TGroupBox
    Left = 481
    Top = 0
    Width = 185
    Height = 454
    Align = alRight
    Caption = #1052#1072#1089#1082#1080' '#1080' '#1072#1090#1088#1080#1073#1091#1090#1099' '#1092#1072#1081#1083#1086#1074
    TabOrder = 2
    object mMaskFiles: TMemo
      Left = 2
      Top = 17
      Width = 181
      Height = 418
      Align = alClient
      Lines.Strings = (
        '*.ini')
      TabOrder = 0
    end
    object chHiddenSys: TCheckBox
      Left = 2
      Top = 435
      Width = 181
      Height = 17
      Align = alBottom
      Caption = #1057#1082#1088#1099#1090#1099#1077' '#1080' '#1089#1080#1089#1090#1077#1084#1085#1099#1077
      Checked = True
      State = cbChecked
      TabOrder = 1
    end
  end
  object FileOpenDialog1: TFileOpenDialog
    FavoriteLinks = <>
    FileTypes = <>
    Options = []
    Left = 128
    Top = 104
  end
end
