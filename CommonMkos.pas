unit CommonMkos;

interface

uses
  WinApi.Windows,
  System.Classes,
  System.SysUtils,
  TasksFunc;

type

  TSearchResult = record
    Pattern: string;
    Positions: TArray<Int64>;
  end;

//  TSearchResults = array of TSearchResult;

//  TSearchResults = array[0..999] of Int64;
//  TSearchResults = array of Int64;
  TSearchResults = TArray<Int64>;

  ///<summary>
  ///Тип функции поска файлов в DLL
  ///</summary>
  TSearchFilesFunc = function(Masks: PChar; StartDir: PChar; var FileCount: Integer; var FileList: WideString): Boolean; stdcall;

  TSearchInFileFunc = function(FileName: PChar; Patterns: PChar; out Results: PChar; out TotalMatches: Int64): Boolean stdcall;

//  TSearchPattern = function(FileName: PChar; Pattern: PChar; var Results: TArray<Int64>; var TotalMatches: Int64): Boolean; stdcall;
  TSearchPattern = function(FileName: PChar; Pattern: PChar; var Results: TSearchResults; var TotalMatches: Int64): Boolean; stdcall;

  TSearchCallback = procedure(Msg: PChar) of object; stdcall;
  TSearchPattern2 = function(FileName: PChar; Pattern: PChar; var TotalMatches: Int64; SearchCallback: TSearchCallback): Boolean; stdcall;

  TLogCallback = procedure(Msg: PChar) of object; stdcall;
  TArchiveFolderFunc = function(FolderPath, ArchiveName: PChar; LogCallback: Pointer(*TLogCallback*)): Boolean; stdcall;

  ///<summary>
  ///Статус задачи
  ///</summary>
  TTaskStatus = (tsWaiting = 0, //Ожидание
    tsRunning, //Выполняется
    tsCompleted, //Отменено
    tsError, //Ошибка
    tsCancelled); //Завершено

  ///<summary>
  ///о конкретной задаче
  ///</summary>
(*  TTaskInfo = record
    ID: Integer;
    Name: string;
    Status: TTaskStatus;
    StartTime: TDateTime;
    EndTime: TDateTime;
    FThread: TThread;
  end;*)

  ///<summary>
  ///Имена экспортируемый функций из DLL
  ///</summary>
procedure ShowDllExports(const hDll: THandle; OutputList: TStringList);

const
  RealTasks: array[0..2] of string = ('SearchFiles', 'SearchPattern', (*'SearchPattern2',*) 'ArchiveFolder');

var
  FSearchDLL: THandle;
  F7ZipDLL: THandle;

  FCancelled: Boolean;
//  FTasks: TArray<TTaskInfo>; // массив задач

implementation

procedure ShowDllExports(const hDll: THandle; OutputList: TStringList);
var
  pExportDir: PImageExportDirectory;
  pNameRVAs: PDWORD;
  pName: PAnsiChar;
  i: Cardinal; //Integer;
  ExportName: string;
//  ExportOrdinal: Word;
  DllBase: Pointer;
  DosHeader: PImageDosHeader;
  NTHeader: PImageNtHeaders;
begin

(* if not Assigned(OutputList) then
    raise Exception.Create('Параметр OutputList не может быть nil');
  OutputList.Clear;
  if not FileExists(DllFileName) then
    raise Exception.Create('Файл не найден: ' + DllFileName);
  hDll := LoadLibraryEx(PChar(DllFileName), 0, DONT_RESOLVE_DLL_REFERENCES);
  if hDll = 0 then
    raise Exception.Create('Не удалось загрузить DLL: ' + SysErrorMessage(GetLastError)); *)

//  try
    DllBase := Pointer(hDll);
    DosHeader := DllBase;
    if DosHeader^.e_magic <> IMAGE_DOS_SIGNATURE then
      raise Exception.Create('Неверный формат PE-файла');
    NTHeader := PImageNtHeaders(PByte(DllBase) + DosHeader^._lfanew);
    if NTHeader^.Signature <> IMAGE_NT_SIGNATURE then
      raise Exception.Create('Неверная сигнатура PE-файла');
    pExportDir := PImageExportDirectory(PByte(DllBase) + NTHeader^.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT].VirtualAddress);
    if not Assigned(pExportDir) then
      Exit; //нет функций
    pNameRVAs := PDWORD(PByte(DllBase) + pExportDir^.AddressOfNames);
    for i := 0 to pExportDir^.NumberOfNames - 1 do
    begin
      pName := PAnsiChar(PByte(DllBase) + pNameRVAs^);
      ExportName := string(pName);
//      ExportOrdinal := pExportDir^.Base + i;
      OutputList.Add(ExportName);
      Inc(pNameRVAs);
    end;

(* finally
    FreeLibrary(hDll);
  end; *)
end;

end.
