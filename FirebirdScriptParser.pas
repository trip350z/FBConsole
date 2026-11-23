unit FirebirdScriptParser;

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses Classes, SysUtils;

function SplitFirebirdScript(const ScriptText: string): TStringList;

implementation

function FirstCodeText(const S: string): string;
var I, J: Integer; InBlock: Boolean;
begin
  I := 1; InBlock := False;
  while I <= Length(S) do
  begin
    if InBlock then
    begin
      if (S[I] = '*') and (I < Length(S)) and (S[I+1] = '/') then
      begin Inc(I, 2); InBlock := False; Continue; end;
      Inc(I); Continue;
    end;
    if S[I] <= ' ' then begin Inc(I); Continue; end;
    if (S[I] = '-') and (I < Length(S)) and (S[I+1] = '-') then
    begin
      Inc(I,2);
      while (I <= Length(S)) and not (S[I] in [#10,#13]) do Inc(I);
      Continue;
    end;
    if (S[I] = '/') and (I < Length(S)) and (S[I+1] = '*') then
    begin Inc(I,2); InBlock := True; Continue; end;
    J := I;
    while (J <= Length(S)) and not (S[J] <= ' ') do Inc(J);
    Exit(Copy(S,I,J-I));
  end;
  Result := '';
end;

function SkipTrivia(const S: string; StartAt: Integer): Integer;
var InBlock: Boolean;
begin
  Result := StartAt;
  InBlock := False;
  while Result <= Length(S) do
  begin
    if S[Result] <= ' ' then begin Inc(Result); Continue; end;
    if (S[Result] = '-') and (Result < Length(S)) and (S[Result+1] = '-') then
    begin
      Inc(Result, 2);
      while (Result <= Length(S)) and not (S[Result] in [#10,#13]) do Inc(Result);
      Continue;
    end;
    if (S[Result] = '/') and (Result < Length(S)) and (S[Result+1] = '*') then
    begin
      Inc(Result, 2);
      InBlock := True;
      while (Result <= Length(S)) and InBlock do
      begin
        if (S[Result] = '*') and (Result < Length(S)) and (S[Result+1] = '/') then
        begin Inc(Result, 2); InBlock := False; end
        else Inc(Result);
      end;
      Continue;
    end;
    Break;
  end;
end;

function IsSetTerm(const S: string; out NewTerm: string): Boolean;
var T: TStringList; Clean, Rest: string; P: Integer;
begin
  Result := False; NewTerm := '';
  Clean := Trim(S);
  if not SameText(FirstCodeText(Clean),'SET') then Exit;
  P := SkipTrivia(Clean, 1);
  if not SameText(Copy(Clean,P,3),'SET') then Exit;
  Inc(P,3);
  P := SkipTrivia(Clean, P);
  if not SameText(Copy(Clean,P,4),'TERM') then Exit;
  Inc(P,4);
  P := SkipTrivia(Clean, P);
  Rest := Trim(Copy(Clean,P,MaxInt));
  if (Rest<>'') and (Rest[Length(Rest)]=';') then
    Delete(Rest,Length(Rest),1);
  T := TStringList.Create;
  try
    ExtractStrings([' ',#9,#10,#13],[],PChar(Rest),T);
    if T.Count <> 1 then
      raise Exception.Create('SET TERMの書式は SET TERM 新しい区切り文字 です。');
    NewTerm := T[0];
    if (NewTerm='') or (Length(NewTerm)>8) then
      raise Exception.Create('SET TERMの区切り文字は1～8文字で指定してください。');
    Result := True;
  finally T.Free; end;
end;

function SplitFirebirdScript(const ScriptText: string): TStringList;
var I, L: Integer; Delimiter, Segment, NewTerm: string;
    InSingle, InDouble, InLineComment, InBlockComment: Boolean;
    Buffer: TStringBuilder;
  procedure EmitSegment;
  var S: string;
  begin
    S := Trim(Buffer.ToString);
    Buffer.Clear;
    if S='' then Exit;
    if IsSetTerm(S,NewTerm) then Delimiter:=NewTerm
    else if FirstCodeText(S)<>'' then Result.Add(S);
  end;
begin
  Result := TStringList.Create;
  Delimiter := ';';
  InSingle := False; InDouble := False;
  InLineComment := False; InBlockComment := False;
  Buffer := TStringBuilder.Create;
  try
    try
      I := 1; L := Length(ScriptText);
      while I <= L do
      begin
      if InLineComment then
      begin
        Buffer.Append(ScriptText[I]);
        if ScriptText[I] in [#10,#13] then InLineComment:=False;
        Inc(I); Continue;
      end;
      if InBlockComment then
      begin
        Buffer.Append(ScriptText[I]);
        if (ScriptText[I]='*') and (I<L) and (ScriptText[I+1]='/') then
        begin Buffer.Append('/'); Inc(I,2); InBlockComment:=False; Continue; end;
        Inc(I); Continue;
      end;
      if InSingle then
      begin
        Buffer.Append(ScriptText[I]);
        if (ScriptText[I]='''') and (I<L) and (ScriptText[I+1]='''') then
        begin Buffer.Append(''''); Inc(I,2); Continue; end;
        if ScriptText[I]='''' then InSingle:=False;
        Inc(I); Continue;
      end;
      if InDouble then
      begin
        Buffer.Append(ScriptText[I]);
        if (ScriptText[I]='"') and (I<L) and (ScriptText[I+1]='"') then
        begin Buffer.Append('"'); Inc(I,2); Continue; end;
        if ScriptText[I]='"' then InDouble:=False;
        Inc(I); Continue;
      end;
      if (ScriptText[I]='-') and (I<L) and (ScriptText[I+1]='-') then
      begin Buffer.Append('--'); Inc(I,2); InLineComment:=True; Continue; end;
      if (ScriptText[I]='/') and (I<L) and (ScriptText[I+1]='*') then
      begin Buffer.Append('/*'); Inc(I,2); InBlockComment:=True; Continue; end;
      if ScriptText[I]='''' then begin Buffer.Append(ScriptText[I]); InSingle:=True; Inc(I); Continue; end;
      if ScriptText[I]='"' then begin Buffer.Append(ScriptText[I]); InDouble:=True; Inc(I); Continue; end;
      if (Delimiter<>'') and (I+Length(Delimiter)-1<=L) and
        (Copy(ScriptText,I,Length(Delimiter))=Delimiter) then
      begin
        EmitSegment;
        Inc(I,Length(Delimiter));
        Continue;
      end;
      Buffer.Append(ScriptText[I]);
      Inc(I);
      end;
      Segment := Trim(Buffer.ToString);
      if Segment<>'' then
      begin
        if IsSetTerm(Segment,NewTerm) then
          Delimiter:=NewTerm
        else if FirstCodeText(Segment)<>'' then
          Result.Add(Segment);
      end;
    except
      Result.Free;
      raise;
    end;
  finally
    Buffer.Free;
  end;
end;

end.
