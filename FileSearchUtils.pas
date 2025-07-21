unit FileSearchUtils;

interface

uses
  System.Classes, System.Types, System.SysUtils, System.IOUtils, System.Generics.Collections;

type
  TFileSearchOptions = set of (fsRecursive, // Искать в подпапках
    fsCaseSensitive, // Учитывать регистр в масках
    fsHiddenFiles, // Включать скрытые файлы
    fsSystemFiles // Включать системные файлы
    );
function FindFilesByMask(const Masks: array of string; // Маски файлов (например, ['*.txt', '*.doc'])
  const StartDir: string; // Стартовая папка
  out FileList: TStringList; // Список найденных файлов (полные пути)
  Options: TFileSearchOptions = [fsRecursive] // Доп. параметры поиска
  ): Integer; // Возвращает количество найденных файлов

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
  // Определяем глубину поиска
  if fsRecursive in Options then
    SearchOption := TSearchOption.soAllDirectories
  else
    SearchOption := TSearchOption.soTopDirectoryOnly;
  // Настраиваем атрибуты файлов для поиска
  FileAttrs := faAnyFile;
  if not(fsHiddenFiles in Options) then
    FileAttrs := FileAttrs and not faHidden;
  if not(fsSystemFiles in Options) then
    FileAttrs := FileAttrs and not faSysFile;
  try
    // Ищем файлы по каждой маске
    for Mask in Masks do
    begin
      // Используем TDirectory.GetFiles для поиска
      Files := TDirectory.GetFiles(StartDir, Mask, SearchOption,
        function(const Path: string; const SearchRec: TSearchRec): Boolean
        begin
          // Фильтр по атрибутам
          Result := (SearchRec.Attr and FileAttrs) = SearchRec.Attr;
          // Проверка регистра (если требуется)
          if fsCaseSensitive in Options then
            Result := Result and (ExtractFileName(Path) = SearchRec.Name);
        end);
      // Добавляем найденные файлы в список
      FileList.AddStrings(Files);
    end;
    // Возвращаем количество найденных файлов
    Result := FileList.Count;
  except
    on E: Exception do
    begin
      FileList.Free;
      raise Exception.Create('Ошибка поиска файлов: ' + E.Message);
    end;
  end;
end;

end.
