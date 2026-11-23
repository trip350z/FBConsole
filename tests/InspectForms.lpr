program InspectForms;
{$mode objfpc}{$H+}
uses Classes, SysUtils;
var Input, Output: TMemoryStream; P: PByte; I: PtrInt; S: TStringList;
begin
  Input := TMemoryStream.Create;
  Output := TMemoryStream.Create;
  S := TStringList.Create;
  try
    Input.LoadFromFile(ParamStr(1));
    P := Input.Memory;
    for I := 0 to Input.Size - 5 do
      if (P[I] = 84) and (P[I+1] = 80) and (P[I+2] = 70) and (P[I+3] = 48) then
      begin
        Input.Position := I;
        Output.Clear;
        try
          ObjectBinaryToText(Input, Output);
          Output.Position := 0;
          S.LoadFromStream(Output);
          if (Pos('frmMain:', S[0]) > 0) or (Pos('frmServerRegister:', S[0]) > 0) or
             (Pos('frmDBRegister:', S[0]) > 0) or (Pos('frmSQL:', S[0]) > 0) then
          begin
            WriteLn(S[0]);
            S.SaveToFile(IncludeTrailingPathDelimiter(ParamStr(2)) + IntToStr(I) + '.dfm.txt');
          end;
        except
          // Not every occurrence is a valid root object stream.
        end;
      end;
  finally
    S.Free;
    Output.Free;
    Input.Free;
  end;
end.
