object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'MKOS - '#1052#1086#1076#1091#1083#1100#1085#1086#1077' '#1087#1088#1080#1083#1086#1078#1077#1085#1080#1077
  ClientHeight = 563
  ClientWidth = 600
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OnCreate = FormCreate
  TextHeight = 13
  object mResults: TMemo
    Left = 0
    Top = 329
    Width = 600
    Height = 193
    Align = alClient
    ScrollBars = ssBoth
    TabOrder = 0
    ExplicitWidth = 596
    ExplicitHeight = 192
  end
  object pLower: TPanel
    Left = 0
    Top = 522
    Width = 600
    Height = 41
    Align = alBottom
    TabOrder = 1
    ExplicitTop = 521
    ExplicitWidth = 596
    object btnCancelTask: TButton
      Left = 333
      Top = 6
      Width = 120
      Height = 25
      Caption = #1055#1088#1077#1088#1074#1072#1090#1100' '#1079#1072#1076#1072#1095#1091
      TabOrder = 0
      OnClick = btnCancelTaskClick
    end
    object btnViewResults: TButton
      Left = 459
      Top = 6
      Width = 120
      Height = 25
      Caption = #1055#1088#1086#1089#1084#1086#1090#1088' '#1088#1077#1079#1091#1083#1100#1090#1072#1090#1086#1074
      TabOrder = 1
      OnClick = btnViewResultsClick
    end
  end
  object pSearchFiles: TPanel
    Left = 0
    Top = 0
    Width = 600
    Height = 191
    Align = alTop
    TabOrder = 2
    ExplicitWidth = 596
    object lblMasks: TLabel
      Left = 8
      Top = 39
      Width = 76
      Height = 13
      Caption = #1052#1072#1089#1082#1080' '#1092#1072#1081#1083#1086#1074':'
    end
    object lblSearchInFile: TLabel
      Left = 8
      Top = 112
      Width = 216
      Height = 13
      Caption = #1055#1086#1089#1083#1077#1076#1086#1074#1072#1090#1077#1083#1100#1085#1086#1089#1090#1080' '#1076#1083#1103' '#1087#1086#1080#1089#1082#1072' '#1074' '#1092#1072#1081#1083#1077':'
    end
    object btnSelectFolder: TButton
      Left = 8
      Top = 85
      Width = 120
      Height = 25
      Caption = #1042#1099#1073#1088#1072#1090#1100' '#1087#1072#1087#1082#1091'...'
      TabOrder = 0
      OnClick = btnSelectFolderClick
    end
    object edtStartFolder: TEdit
      Left = 8
      Top = 12
      Width = 584
      Height = 21
      TabOrder = 1
      Text = 'D:\tmp\'
    end
    object btnSearchFiles: TButton
      Left = 134
      Top = 85
      Width = 120
      Height = 25
      Caption = #1055#1086#1080#1089#1082' '#1092#1072#1081#1083#1086#1074
      TabOrder = 3
      OnClick = btnSearchFilesClick
    end
    object eMasks: TEdit
      Left = 8
      Top = 58
      Width = 584
      Height = 21
      TabOrder = 2
      Text = '*.dpr;*.txt;*.pas;*.dfm'
    end
    object eSearchPatterns: TEdit
      Left = 8
      Top = 131
      Width = 584
      Height = 21
      TabOrder = 4
      Text = #9660';10'
      TextHint = #1042#1074#1077#1076#1080#1090#1077' '#1087#1086#1089#1083#1077#1076#1086#1074#1072#1090#1077#1083#1100#1085#1086#1089#1090#1080' '#1095#1077#1088#1077#1079' "|" ('#1085#1072#1087#1088#1080#1084#1077#1088': libsec|binsec)'
    end
    object btnSelectFile: TButton
      Left = 8
      Top = 160
      Width = 120
      Height = 25
      Caption = #1042#1099#1073#1088#1072#1090#1100' '#1092#1072#1081#1083'...'
      TabOrder = 5
      OnClick = btnSelectFileClick
    end
    object btnSearchInFile: TButton
      Left = 134
      Top = 158
      Width = 120
      Height = 25
      Caption = #1055#1086#1080#1089#1082' '#1074' '#1092#1072#1081#1083#1077
      TabOrder = 6
      OnClick = btnSearchInFileClick
    end
    object btnArchive: TButton
      Left = 472
      Top = 85
      Width = 120
      Height = 25
      Caption = #1040#1088#1093#1080#1074#1080#1088#1086#1074#1072#1090#1100
      TabOrder = 7
      OnClick = btnArchiveClick
    end
  end
  object pTasks: TPanel
    Left = 0
    Top = 191
    Width = 600
    Height = 138
    Align = alTop
    TabOrder = 3
    ExplicitWidth = 596
    object lvTasks: TListView
      Left = 1
      Top = 1
      Width = 598
      Height = 96
      Align = alTop
      Columns = <
        item
          Caption = 'ID'
        end
        item
          Caption = #1047#1072#1076#1072#1095#1072
          Width = 150
        end
        item
          Caption = #1057#1090#1072#1090#1091#1089
          Width = 100
        end
        item
          Caption = #1053#1072#1095#1072#1083#1086
          Width = 120
        end
        item
          Caption = #1054#1082#1086#1085#1095#1072#1085#1080#1077
          Width = 120
        end>
      GridLines = True
      RowSelect = True
      TabOrder = 0
      ViewStyle = vsReport
      ExplicitWidth = 594
    end
    object b1: TButton
      Left = 9
      Top = 103
      Width = 75
      Height = 25
      Caption = #1047#1072#1087#1091#1089#1082
      TabOrder = 1
      OnClick = b1Click
    end
    object b2: TButton
      Left = 90
      Top = 103
      Width = 75
      Height = 25
      Caption = #1057#1090#1086#1087
      TabOrder = 2
      OnClick = b2Click
    end
  end
  object OpenDialog: TFileOpenDialog
    FavoriteLinks = <>
    FileTypes = <
      item
        DisplayName = #1055#1072#1087#1082#1080
        FileMask = '*.*'
      end>
    Options = [fdoPickFolders]
    Left = 348
    Top = 8
  end
  object FileOpenDialog: TOpenTextFileDialog
    Left = 475
    Top = 395
  end
end
