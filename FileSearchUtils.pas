/// <summary>
/// ���������� ������ ������ ������ �� ����� � ��������� ����� ������. ��������� ��������� - ���������� ���������
/// ������, ��������, ������� ���������: (�*.txt�, �P:\Documents\�). �������������: o ������� ������ ������ �����
/// ��������� ������. <br />o ����������� ��������� ���� ������ ������ ��������� ��������� ����� ��� �����������
/// �������� �������������� ��������� ������ �� ���������� �����������. <br />
/// </summary>
unit FileSearchUtils;

interface

uses
  System.Classes, System.Types, System.SysUtils, System.IOUtils, System.Generics.Collections;

type
  TExportInfo = record
    Name: string;
    Ordinal: Word;
  end;

  /// <summary>
  /// ��������� ������ ������������������ ��������
  /// </summary>
  TBinarySearchResult = record
    Pattern: AnsiString;
    Positions: TArray<Int64>;
    function Count: Integer;
  end;

  TBinarySearchResults = TArray<TBinarySearchResult>;
  /// <summary>
  ///   ����� ������
  /// </summary>
  TFileSearchOptions = set of (fsRecursive, // � ���������
    fsCaseSensitive, // ��������� �������
    fsHiddenFiles, // ������� �����
    fsSystemFiles // ��������� �����
    );
/// <summary>
///   ����� �� �����
/// </summary>
function FindFilesByMask(const Masks: array of string; // ����� ������ (��������, ['*.txt', '*.doc'])
  const StartDir: string; // ��������� �����
  out FileList: TStringList; // ������ ��������� ������ (������ ����)
  Options: TFileSearchOptions = [fsRecursive] // ���. ��������� ������
  ): Integer; // ���������� ���������� ��������� ������
/// <summary>
/// ����� ��������� ������������������ �������� � ����� DLL
/// </summary>
function FindBinaryPatternsInFile(const FileName: string; const Patterns: array of AnsiString; MaxResults: Integer = 0): TBinarySearchResults;

implementation

{ TBinarySearchResult }
function TBinarySearchResult.Count: Integer;
begin
  Result := Length(Positions);
end;

function FindFilesByMask(const Masks: array of string; const StartDir: string; out FileList: TStringList; Options: TFileSearchOptions = [fsRecursive]
  ): Integer;
var
  SearchOption: TSearchOption;
  Mask: string;
  Files: TStringDynArray;
  FileAttrs: Integer;
begin
  Result := 0;
  FileList := TStringList.Create;
// ������� ������
  if fsRecursive in Options then
    SearchOption := TSearchOption.soAllDirectories
  else
    SearchOption := TSearchOption.soTopDirectoryOnly;

// �������� ������
  FileAttrs := faAnyFile;
  if not(fsHiddenFiles in Options) then
    FileAttrs := FileAttrs and not faHidden;
  if not(fsSystemFiles in Options) then
    FileAttrs := FileAttrs and not faSysFile;

  try // ����� �� ������ �����
    for Mask in Masks do begin
      Files := TDirectory.GetFiles(StartDir, Mask, SearchOption,
        function(const Path: string; const SearchRec: TSearchRec): Boolean
        begin
          // ������ �� ���������
          Result := (SearchRec.Attr and FileAttrs) = SearchRec.Attr;
          // �������� �������� (���� ���������)
          if fsCaseSensitive in Options then
            Result := Result and (ExtractFileName(Path) = SearchRec.Name);
        end);
      FileList.AddStrings(Files);
    end;
    // ���������� ��������� ������
    Result := FileList.Count;
  except
    on E: Exception do
    begin
      FileList.Free;
      raise Exception.Create('������ ������ ������: ' + E.Message);
    end;
  end;
end;

function FindBinaryPatternsInFile(const FileName: string; const Patterns: array of AnsiString; MaxResults: Integer = 0): TBinarySearchResults;
var
  FileStream: TFileStream;
  Buffer: array of Byte;
  BytesRead: Integer;
  i, j, k: Integer;
  PatternFound: Boolean;
  FileSize, TotalRead: Int64;
  MaxBufferSize: Integer;
begin
  if not FileExists(FileName) then
    raise Exception.Create('���� �� ������: ' + FileName);
  if Length(Patterns) = 0 then
    raise Exception.Create('�� ������ ������� ��� ������');

  SetLength(Result, Length(Patterns));
  for i := 0 to High(Result) do
  begin
    Result[i].Pattern := Patterns[i];
    SetLength(Result[i].Positions, 0);
  end;
  FileStream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    FileSize := FileStream.Size;
    TotalRead := 0;
    MaxBufferSize := 1024 * 1024; // 1MB �����
    // ����������� ������ ������ (����. ����� ������� + ����������)
    for i := 0 to High(Patterns) do
      if Length(Patterns[i]) > MaxBufferSize then
        MaxBufferSize := Length(Patterns[i]) * 2;
    SetLength(Buffer, MaxBufferSize);
    // ������ ���� �������
    while TotalRead < FileSize do
    begin
      BytesRead := FileStream.Read(Buffer[0], MaxBufferSize);
      if BytesRead = 0 then
        Break;
      // ����� ������� ������� � ������� ������
      for i := 0 to High(Patterns) do
      begin
        // ���������� ���� ��� ����� ������������ ���������� �����������
        if (MaxResults > 0) and (Result[i].Count >= MaxResults) then
          Continue;
        for j := 0 to BytesRead - Length(Patterns[i]) do
        begin
          PatternFound := True;
          for k := 1 to Length(Patterns[i]) do
          begin
            if Buffer[j + k - 1] <> Ord(Patterns[i][k]) then
            begin
              PatternFound := False;
              Break;
            end;
          end;
          if PatternFound then
          begin
            // ��������� ������� (� ������ ����� ����������� ������)
            SetLength(Result[i].Positions, Length(Result[i].Positions) + 1);
            Result[i].Positions[High(Result[i].Positions)] := TotalRead + j;
            // ����� ������ ���� �������� MaxResults
            if (MaxResults > 0) and (Result[i].Count >= MaxResults) then
              Break;
          end;
        end;
      end;
      Inc(TotalRead, BytesRead);
      // ����� ��� ���������� (����� �� ���������� ������� �� ������� ������)
      if TotalRead < FileSize then
        FileStream.Position := FileStream.Position - Length(Patterns[High(Patterns)]) + 1;
    end;
  finally
    FileStream.Free;
  end;
end;

end.
