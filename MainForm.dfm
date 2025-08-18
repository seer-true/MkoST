object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'MKOS - '#1052#1086#1076#1091#1083#1100#1085#1086#1077' '#1087#1088#1080#1083#1086#1078#1077#1085#1080#1077
  ClientHeight = 624
  ClientWidth = 600
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object mResults: TMemo
    Left = 0
    Top = 346
    Width = 600
    Height = 237
    Align = alClient
    ScrollBars = ssBoth
    TabOrder = 0
  end
  object pLower: TPanel
    Left = 0
    Top = 583
    Width = 600
    Height = 41
    Align = alBottom
    TabOrder = 1
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
      Caption = #1054#1095#1080#1089#1090#1080#1090#1100
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
    object eFile_s: TEdit
      Left = 8
      Top = 12
      Width = 584
      Height = 21
      TabOrder = 1
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
      Left = 9
      Top = 131
      Width = 584
      Height = 21
      TabOrder = 3
      Text = '71i;100'
      TextHint = #1042#1074#1077#1076#1080#1090#1077' '#1087#1086#1089#1083#1077#1076#1086#1074#1072#1090#1077#1083#1100#1085#1086#1089#1090#1080' '#1095#1077#1088#1077#1079' ";" ('#1085#1072#1087#1088#1080#1084#1077#1088': libsec;binsec)'
    end
    object btnSelectFile: TButton
      Left = 8
      Top = 160
      Width = 120
      Height = 25
      Caption = #1042#1099#1073#1088#1072#1090#1100' '#1092#1072#1081#1083'...'
      TabOrder = 4
      OnClick = btnSelectFileClick
    end
    object btnArchive: TButton
      Left = 473
      Top = 85
      Width = 120
      Height = 25
      Caption = #1040#1088#1093#1080#1074#1080#1088#1086#1074#1072#1090#1100
      TabOrder = 5
      OnClick = btnArchiveClick
    end
  end
  object pTasks: TPanel
    Left = 0
    Top = 191
    Width = 600
    Height = 155
    Align = alTop
    TabOrder = 3
    object bStartTask: TButton
      Left = 9
      Top = 122
      Width = 119
      Height = 25
      Caption = #1047#1072#1087#1091#1089#1082
      TabOrder = 0
      OnClick = bStartTaskClick
    end
    object bStopTask: TButton
      Left = 134
      Top = 122
      Width = 120
      Height = 25
      Caption = #1057#1090#1086#1087
      TabOrder = 1
      OnClick = bStopTaskClick
    end
    object dbgTasks: TDBGrid
      Left = 1
      Top = 1
      Width = 598
      Height = 115
      Align = alTop
      DataSource = dsTask
      TabOrder = 2
      TitleFont.Charset = DEFAULT_CHARSET
      TitleFont.Color = clWindowText
      TitleFont.Height = -11
      TitleFont.Name = 'Tahoma'
      TitleFont.Style = []
    end
    object b1: TButton
      Left = 330
      Top = 125
      Width = 75
      Height = 25
      Caption = 'b1'
      TabOrder = 3
      OnClick = b1Click
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
    Left = 355
    Top = 100
  end
  object cdsTasks: TClientDataSet
    Aggregates = <>
    Params = <>
    OnCalcFields = cdsTasksCalcFields
    Left = 500
    Top = 231
    object cdsTasksID: TIntegerField
      DisplayWidth = 10
      FieldName = 'ID'
    end
    object cdsTasksTask: TStringField
      DisplayLabel = #1047#1072#1076#1072#1095#1072
      DisplayWidth = 20
      FieldName = 'Task'
    end
    object cdsTasksStatus: TSmallintField
      FieldName = 'Status'
    end
    object cdsTasksSStatus: TStringField
      DisplayLabel = #1057#1090#1072#1090#1091#1089
      DisplayWidth = 27
      FieldKind = fkCalculated
      FieldName = 'SStatus'
      Calculated = True
    end
    object cdsTasksTimeStart: TDateTimeField
      DisplayLabel = #1053#1072#1095#1072#1083#1086
      DisplayWidth = 13
      FieldName = 'TimeStart'
    end
    object cdsTasksTimeEnd: TDateTimeField
      DisplayLabel = #1047#1072#1074#1077#1088#1096#1077#1085#1080#1077
      DisplayWidth = 15
      FieldName = 'TimeEnd'
    end
    object cdsTasksFThread: TLargeintField
      FieldName = 'FThread'
    end
  end
  object dsTask: TDataSource
    DataSet = cdsTasks
    Left = 545
    Top = 231
  end
end
