//https://www.gunsmoker.ru/2009/01/blog-post.html
//https://www.gunsmoker.ru/2019/06/developing-DLL-API.html
library SearchFile;

uses
{$IFDEF DEBUG}
  //FastMM4 in '..\FastMM4\FastMM4.pas'
{$ENDIF }
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  System.IOUtils,
  System.Types,
  CommonMkos in 'CommonMkos.pas';
{$R *.res}

///<summary>
///������� ��� ������������ ������ ������
///</summary>
function SearchFiles(Masks: PChar; StartDir: PChar; var FileCount: Integer; var FileArr: WideString): Boolean; stdcall;
var
  MaskArray: TArray<string>;
  Mask: string;
  FoundFiles: TStringDynArray;
begin
  Result := False;
  FileCount := 0;
  FileArr := '';
  //��������� ����� �� ������ � �������
  MaskArray := string(Masks).Split([';'], TStringSplitOptions.ExcludeEmpty);
  try
    for Mask in MaskArray do
    begin //��� ������ �����
      FoundFiles := TDirectory.GetFiles(string(StartDir), Mask.Trim, TSearchOption.soAllDirectories);
      //����������
      for var I := 0 to High(FoundFiles) do
        FileArr := FileArr + sLineBreak + FoundFiles[I];
      FileCount := FileCount + High(FoundFiles) + 1;
    end;
    Result := True;
  except
    on E: Exception do
    begin
      FileCount := -1;
    end;
  end;
end;

function SearchInFile(FileName: PChar; Patterns: PChar; out Results: PChar; out TotalMatches: Integer): Boolean; stdcall;
var
  PatternsArray: TArray<string>;
  FileStream: TFileStream;
  Buffer: TBytes;
  FileSize, BytesRead, PatternLength: Int64;
  I, j, k: Integer;
  Matches: array of TSearchResult;
  PatternBytesArray: array of TBytes;
  FilePos: Int64;
  ResultStr: string;
  TempStr: string;
begin
  Result := False;
  TotalMatches := 0;
  Results := nil;
  try
    //��������� ������� �� ';'
    PatternsArray := string(Patterns).Split([';'], TStringSplitOptions.ExcludeEmpty);
    //������������� �������� ����������� � ���������� �������� ������������� ��������
    SetLength(Matches, Length(PatternsArray));
    SetLength(PatternBytesArray, Length(PatternsArray));
    for I := 0 to High(PatternsArray) do
    begin
      PatternsArray[I] := PatternsArray[I].Trim;
      Matches[I].Pattern := PatternsArray[I];
      PatternBytesArray[I] := TEncoding.UTF8.GetBytes(PatternsArray[I]);
      SetLength(Matches[I].Positions, 0);
    end;
    //��������� ���� ��� ������
    FileStream := TFileStream.Create(string(FileName), fmOpenRead or fmShareDenyWrite);
    try
      FileSize := FileStream.Size;
      SetLength(Buffer, 1024 * 1024); //����� 1MB
      FilePos := 0;
      //������ ���� �������
      while FilePos < FileSize do
      begin
        BytesRead := FileStream.Read(Buffer[0], Length(Buffer));
        if BytesRead = 0 then
          Break;
        //����� ��� ������� �������
        for I := 0 to High(PatternsArray) do
        begin
          PatternLength := Length(PatternBytesArray[I]);
          if PatternLength = 0 then
            Continue;
          if BytesRead < PatternLength then
            Continue;
          j := 0;
          while j <= BytesRead - PatternLength do
          begin
            //������� �������� ������� �����
            if Buffer[j] = PatternBytesArray[I][0] then
            begin
              //�������� ��������� ������
              k := 1;
              while (k < PatternLength) and (Buffer[j + k] = PatternBytesArray[I][k]) do
                Inc(k);
              if k = PatternLength then
              begin
                //������� ����������
                SetLength(Matches[I].Positions, Length(Matches[I].Positions) + 1);
                Matches[I].Positions[High(Matches[I].Positions)] := FilePos + j;
                Inc(TotalMatches);
                //���������� ����� ������� ��� ����������������� ����������
                Inc(j, PatternLength);
                Continue;
              end;
            end;
            Inc(j);
          end;
        end;
        Inc(FilePos, BytesRead);
      end;
    finally
      FileStream.Free;
    end;
    //��������� ���������� � ���� ������
    ResultStr := '';
    for I := 0 to High(Matches) do
    begin
      //��������� ���������� � ������� � ���������� ����������
      ResultStr := ResultStr + Matches[I].Pattern + ' : ������� ' + IntToStr(Length(Matches[I].Positions)) + ' ���������' + #13#10;
      //��������� ������� ����������
      for j := 0 to High(Matches[I].Positions) do
      begin
        TempStr := ' �������: ' + IntToStr(Matches[I].Positions[j]) + #13#10;
        ResultStr := ResultStr + TempStr;
      end;
    end;
    //�������� ���������
    GetMem(Results, Length(ResultStr) + 10);
    StrMove(Results, PChar(ResultStr), Length(ResultStr) + 10);
    Result := True;
  except
    on E: Exception do
    begin
      if Results <> nil then
        StrDispose(Results);
      Results := StrAlloc(Length(E.Message) + 1);
      StrPCopy(Results, E.Message);
    end;
  end;
end;
{$STACKFRAMES ON}

function SearchPattern(FileName: PChar; Pattern: PChar; var Results: TArray<Int64>; var TotalMatches: Int64): Boolean; stdcall;
const
  BufferSize = 1024 * 1024; //1MB ����� ��� ������ �����
var
  FS: TFileStream;
  PatternLen, BytesRead, I, j: Integer;
  Buffer, PrevBuffer: TBytes;
  PatternBytes: TBytes;
  MaxMatches: Int64;
  Found: Boolean;
  CurrentPos: Int64;
begin
  Result := False;
  try
    //�������� ������� ����������
    if (FileName = nil) or (Pattern = nil) then
      Exit;
    //�������� ����� �������
    PatternLen := Length(Pattern);
    if PatternLen = 0 then
      Exit;
    //����������� ������ � ������ ����
    SetLength(PatternBytes, PatternLen * SizeOf(Char));
    Move(Pattern^, PatternBytes[0], Length(PatternBytes));
    //�������������
    SetLength(Results, 0);
    FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      SetLength(Buffer, BufferSize + PatternLen - 1);
      SetLength(PrevBuffer, PatternLen - 1);
      MaxMatches := TotalMatches;
      TotalMatches := 0;
      SetLength(Results, 0); //���� �������������� ������ �����������
      CurrentPos := 0;
      //������ ����� �������
      while True do
      begin
        //������ ����� ����
        BytesRead := FS.Read(Buffer[0], BufferSize);
        //���� ��� �� ������ ����, ��������� ����� ����������� �����
        if BytesRead < BufferSize then
        begin
          //��������� ���� - ��������� �����
          SetLength(Buffer, BytesRead + Length(PrevBuffer));
          Move(PrevBuffer[0], Buffer[BytesRead], Length(PrevBuffer));
        end
        else
          if Length(PrevBuffer) > 0 then
          begin
          //��������� ����� ����������� ����� � ������ ��������
            Move(PrevBuffer[0], Buffer[BytesRead], Length(PrevBuffer));
          end;
        //����� ������� � ������� ������
        for I := 0 to Length(Buffer) - PatternLen do
        begin
          Found := True;
          for j := 0 to PatternLen - 1 do
          begin
            if Buffer[I + j] <> PatternBytes[j] then
            begin
              Found := False;
              Break;
            end;
          end;
          if Found then begin
            //������� ����������
            SetLength(Results, Length(Results) + 1); //AV
            Results[High(Results)] := CurrentPos + I;

            Inc(TotalMatches);
            //���������, �� �������� �� ������������� ���������� ����������
            if (MaxMatches > 0) and (TotalMatches >= MaxMatches) then
            begin
              TotalMatches := TotalMatches - 1;
              Result := True;
              Break;
            end;
          end;
        end;
        //��������� ������� ������� � �����
        CurrentPos := CurrentPos + BytesRead;
        //��������� ����� �������� ����� ��� ��������� ��������
        if BytesRead > 0 then
        begin
          SetLength(PrevBuffer, PatternLen - 1);
          if BytesRead >= PatternLen - 1 then
            Move(Buffer[BytesRead - (PatternLen - 1)], PrevBuffer[0], Length(PrevBuffer))
          else
          begin
            //��������� ������� �� ����������� PrevBuffer
            if Length(PrevBuffer) > BytesRead then
              Move(PrevBuffer[BytesRead], PrevBuffer[0], Length(PrevBuffer) - BytesRead);
            Move(Buffer[0], PrevBuffer[Length(PrevBuffer) - BytesRead], BytesRead);
          end;
        end;
        //��������� ����� �����
        if BytesRead < BufferSize then
          Break;
      end;
      Result := True;
    finally
      FS.Free;
    end;
  except
    Result := False;
  end;
end;
{$STACKFRAMES OFF}

function SearchPattern2(FileName: PChar; Pattern: PChar; var TotalMatches: Int64; SearchCallback: TSearchCallback): Boolean; stdcall;
const
  BufferSize = 1024 * 1024; //1MB ����� ��� ������ �����
var
  FS: TFileStream;
  PatternLen, BytesRead: Integer;
  I, j: Integer;
  Buffer, PrevBuffer: TBytes;
  PatternBytes: TBytes;
  MaxMatches: Int64;
  Found: Boolean;
  CurrentPos: Int64;
begin
  Result := False;
  if not Assigned(SearchCallback) then
    Exit;

  try
    //�������� ������� ����������
    if (FileName = nil) or (Pattern = nil) then
      Exit;

    //�������� ����� �������
    PatternLen := Length(Pattern);
    if PatternLen = 0 then
      Exit;
    //����������� ������ � ������ ����
    SetLength(PatternBytes, PatternLen * SizeOf(Char));
    Move(Pattern^, PatternBytes[0], Length(PatternBytes));
    //�������������
    FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      SetLength(Buffer, BufferSize + PatternLen - 1);
      SetLength(PrevBuffer, PatternLen - 1);
      MaxMatches := TotalMatches;
      TotalMatches := 0;
      CurrentPos := 0;
      //������ ����� �������
      while True do
      begin
        //������ ����� ����
        BytesRead := FS.Read(Buffer[0], BufferSize);
        //���� ��� �� ������ ����, ��������� ����� ����������� �����
        if BytesRead < BufferSize then
        begin
          //��������� ���� - ��������� �����
          SetLength(Buffer, BytesRead + Length(PrevBuffer));
          Move(PrevBuffer[0], Buffer[BytesRead], Length(PrevBuffer));
        end
        else
          if Length(PrevBuffer) > 0 then
          begin
          //��������� ����� ����������� ����� � ������ ��������
            Move(PrevBuffer[0], Buffer[BytesRead], Length(PrevBuffer));
          end;
        //����� ������� � ������� ������
        for I := 0 to Length(Buffer) - PatternLen do
        begin
          Found := True;
          for j := 0 to PatternLen - 1 do
          begin
            if Buffer[I + j] <> PatternBytes[j] then
            begin
              Found := False;
              Break;
            end;
          end;
          if Found then begin
            //������� ����������
(* SetLength(Results, Length(Results) + 1); // AV
            Results[High(Results)] := CurrentPos + I; *)
//            �������������� Delphi
            Inc(TotalMatches);
            //���������, �� �������� �� ������������� ���������� ����������
            if (MaxMatches > 0) and (TotalMatches >= MaxMatches) then
            begin
              TotalMatches := TotalMatches - 1;
              Result := True;
              Break;
            end;
          end;
        end;
        //��������� ������� ������� � �����
        CurrentPos := CurrentPos + BytesRead;
        //��������� ����� �������� ����� ��� ��������� ��������
        if BytesRead > 0 then
        begin
          SetLength(PrevBuffer, PatternLen - 1);
          if BytesRead >= PatternLen - 1 then
            Move(Buffer[BytesRead - (PatternLen - 1)], PrevBuffer[0], Length(PrevBuffer))
          else
          begin
            //��������� ������� �� ����������� PrevBuffer
            if Length(PrevBuffer) > BytesRead then
              Move(PrevBuffer[BytesRead], PrevBuffer[0], Length(PrevBuffer) - BytesRead);
            Move(Buffer[0], PrevBuffer[Length(PrevBuffer) - BytesRead], BytesRead);
          end;
        end;
        //��������� ����� �����
        if BytesRead < BufferSize then
          Break;
      end;
      Result := True;
    finally
      FS.Free;
    end;
  except
    Result := False;
  end;
end;

//�������������� �������
exports
  SearchFiles,
  SearchInFile,
  SearchPattern,
  SearchPattern2 name 'SearchPattern2';

begin
{$IFDEF DEBUG}
  //ReportMemoryLeaksOnShutdown := true; // ������������ ������ ������
{$ENDIF}

 end.
