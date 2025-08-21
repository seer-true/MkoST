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

function SearchPattern(FileName: PChar; Pattern: PChar; var Results: TSearchResults; var TotalMatches: Int64): Boolean; stdcall;
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
    PatternLen := Length(Pattern);

(* SetLength(PatternBytes, PatternLen * SizeOf(Char));
    Move(Pattern^, PatternBytes[0], Length(PatternBytes)); *)

    PatternBytes := TEncoding.ANSI.GetBytes(Pattern); //������ � ������������ ������

//SetLength(Results, 0); //�������������

    FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      SetLength(Buffer, BufferSize + PatternLen - 1);
      SetLength(PrevBuffer, PatternLen(* - 1*));
      MaxMatches := TotalMatches + 1;
      TotalMatches := 0;
      CurrentPos := 0;

      while True do begin //������ ����� �������
        BytesRead := FS.Read(Buffer[0], BufferSize); //������ ����
        if BytesRead < BufferSize then begin //���� ��� �� ������ ����
          SetLength(Buffer, BytesRead + Length(PrevBuffer)); //��������� ���� - ��������� �����
          Move(PrevBuffer[0], Buffer[BytesRead], Length(PrevBuffer));
        end
        else begin
          if Length(PrevBuffer) > 0 then
            Move(PrevBuffer[0], Buffer[BytesRead], Length(PrevBuffer));//����� ����������� ����� � ������ ��������
        end;
      //����� ������� � ������� ������
        for I := 0 to Length(Buffer) - PatternLen do begin
          Found := True; // ����������
          for j := 0 to PatternLen - 1 do begin // �������� ����������
            if Buffer[I + j] <> PatternBytes[j] then begin
              Found := False;
              Break;
            end;
          end;
          if Found then begin //����������
//SetLength(Results, Length(Results) + 1); //AV
            if TotalMatches < Length(Results) then
              Results[TotalMatches] := CurrentPos + I;

            Inc(TotalMatches);
          end;
          if (MaxMatches > 0) and (TotalMatches >= MaxMatches) then begin //������������ ���������� ����������
            Break;
          end;
        end; //for I := 0 to Length(Buffer) - PatternLen do

        if (MaxMatches > 0) and (TotalMatches >= MaxMatches) then begin //���    ��� ��� ������ �� ����� while
          Break;
        end;

        CurrentPos := CurrentPos + BytesRead; //������� ������� � �����

        if BytesRead > 0 then begin //����� �������� ����� ��� ��������� ��������
          SetLength(PrevBuffer, PatternLen - 1);
          if BytesRead >= PatternLen - 1 then
            Move(Buffer[BytesRead - (PatternLen - 1)], PrevBuffer[0], Length(PrevBuffer))
          else
          begin
            if Length(PrevBuffer) > BytesRead then //������� �� ����������� PrevBuffer
              Move(PrevBuffer[BytesRead], PrevBuffer[0], Length(PrevBuffer) - BytesRead);
            Move(Buffer[0], PrevBuffer[Length(PrevBuffer) - BytesRead], BytesRead);
          end;
        end;

        if BytesRead < BufferSize then //����� �����
          Break;
      end; //while True do begin

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
//  SearchInFile,
  SearchPattern;

begin
{$IFDEF DEBUG}
//  ReportMemoryLeaksOnShutdown := true;
{$ENDIF}

end.
