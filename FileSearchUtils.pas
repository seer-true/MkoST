/// <summary>
///   ���������� ������ ������ ������ �� ����� � ��������� ����� ������. ��������� ��������� - ���������� ���������
///   ������, ��������, ������� ���������: (�*.txt�, �P:\Documents\�). �������������: o ������� ������ ������ �����
///   ��������� ������. <br />o ����������� ��������� ���� ������ ������ ��������� ��������� ����� ��� �����������
///   �������� �������������� ��������� ������ �� ���������� �����������. <br />
/// </summary>
unit FileSearchUtils;
interface
uses
  System.Classes, System.Types, System.SysUtils, System.IOUtils, System.Generics.Collections;
type
  TFileSearchOptions = set of (fsRecursive, // ������ � ���������
    fsCaseSensitive, // ��������� ������� � ������
    fsHiddenFiles, // �������� ������� �����
    fsSystemFiles // �������� ��������� �����
    );
function FindFilesByMask(const Masks: array of string; // ����� ������ (��������, ['*.txt', '*.doc'])
  const StartDir: string; // ��������� �����
  out FileList: TStringList; // ������ ��������� ������ (������ ����)
  Options: TFileSearchOptions = [fsRecursive] // ���. ��������� ������
  ): Integer; // ���������� ���������� ��������� ������
implementation
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
// �������� ������ ��� ������
  FileAttrs := faAnyFile;
  if not(fsHiddenFiles in Options) then
    FileAttrs := FileAttrs and not faHidden;
  if not(fsSystemFiles in Options) then
    FileAttrs := FileAttrs and not faSysFile;
  try  // ����� �� ������ �����
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
      // ��������� ��������� ����� � ������
      FileList.AddStrings(Files);
    end;
    // ���������� ���������� ��������� ������
    Result := FileList.Count;
  except
    on E: Exception do
    begin
      FileList.Free;
      raise Exception.Create('������ ������ ������: ' + E.Message);
    end;
  end;
end;
end.
