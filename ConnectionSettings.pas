unit ConnectionSettings;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses Classes, SysUtils, IniFiles;

type
  TConnectionMode = (cmLocalTCP, cmRemoteTCP, cmConnectionString);
  TConnectionSettings = record
    Name, Host, Database, UserName, Role, ClientLibrary: string;
    ServerAlias, Description: string;
    Port: Integer;
    Mode: TConnectionMode;
  end;

function DefaultSettings: TConnectionSettings;
function ConnectionString(const S: TConnectionSettings): string;
function ServerLabel(const S: TConnectionSettings): string;
procedure ReadSettings(const FileName, Name: string; out S: TConnectionSettings);
procedure WriteSettings(const FileName: string; const S: TConnectionSettings);

implementation

function DefaultSettings: TConnectionSettings;
begin
  Result.Name := UTF8Encode('新しい接続');
  Result.Host := 'localhost';
  Result.Port := 3050;
  Result.Database := '';
  Result.UserName := 'SYSDBA';
  Result.Role := '';
  Result.ClientLibrary := '';
  Result.ServerAlias := '';
  Result.Description := '';
  Result.Mode := cmLocalTCP;
end;

function ConnectionString(const S: TConnectionSettings): string;
var Host, Database: string; I: Integer;
begin
  Database := Trim(S.Database);
  if Database = '' then raise Exception.Create('DBの別名またはサーバー上のパスを入力してください。');
  for I := 1 to Length(Database) do
    if Ord(Database[I]) < 32 then raise Exception.Create('DBに制御文字は使用できません。');
  if S.Mode = cmConnectionString then Exit(Database);
  if (S.Port < 1) or (S.Port > 65535) then
    raise Exception.Create('ポートは1～65535で指定してください。');
  if S.Mode = cmLocalTCP then Host := 'localhost' else Host := Trim(S.Host);
  if Host = '' then raise Exception.Create('サーバー名またはIPアドレスを入力してください。');
  for I := 1 to Length(Host) do
    if (Ord(Host[I]) <= 32) or (Host[I] in ['/', '\', '@', '?', '#']) then
      raise Exception.Create('サーバー欄にはホスト名またはIPアドレスだけを入力してください。');
  if (Host[1] = '[') and (Host[Length(Host)] = ']') then
    Host := Copy(Host, 2, Length(Host) - 2);
  if Host = '' then raise Exception.Create('IPアドレスが空です。');
  if (Pos('[', Host) > 0) or (Pos(']', Host) > 0) then
    raise Exception.Create('IPアドレスの角括弧が正しくありません。');
  if Pos(':', Host) > 0 then Host := '[' + Host + ']';
  // URL syntax preserves both absolute Linux paths and Windows drive letters.
  Result := 'inet://' + Host + ':' + IntToStr(S.Port) + '/' + Database;
end;

function ServerLabel(const S: TConnectionSettings): string;
begin
  case S.Mode of
    cmLocalTCP: Result := 'Local Server (localhost:' + IntToStr(S.Port) + ')';
    cmRemoteTCP: Result := S.Host + ':' + IntToStr(S.Port) + ' (TCP/IP)';
    else Result := UTF8Encode('直接指定');
  end;
end;

procedure ReadSettings(const FileName, Name: string; out S: TConnectionSettings);
var I: TIniFile; M: Integer;
begin
  S := DefaultSettings;
  S.Name := Name;
  I := TIniFile.Create(FileName);
  try
    // Version 0.1 stored the full connection string in Database.
    M := I.ReadInteger(Name, 'Mode', Ord(cmConnectionString));
    if (M < Ord(Low(TConnectionMode))) or (M > Ord(High(TConnectionMode))) then
      M := Ord(cmConnectionString);
    S.Mode := TConnectionMode(M);
    S.Host := I.ReadString(Name, 'Host', 'localhost');
    S.Port := I.ReadInteger(Name, 'Port', 3050);
    S.Database := I.ReadString(Name, 'Database', '');
    S.UserName := I.ReadString(Name, 'User', 'SYSDBA');
    S.Role := I.ReadString(Name, 'Role', '');
    S.ClientLibrary := I.ReadString(Name, 'Library', '');
    S.ServerAlias := I.ReadString(Name, 'ServerAlias', '');
    S.Description := I.ReadString(Name, 'Description', '');
  finally
    I.Free;
  end;
end;

procedure WriteSettings(const FileName: string; const S: TConnectionSettings);
var I: TIniFile; N: string;
begin
  N := Trim(S.Name);
  if (N = '') or (Pos('[', N) > 0) or (Pos(']', N) > 0) or
     (Pos(#13, N) > 0) or (Pos(#10, N) > 0) then
    raise Exception.Create('接続名を入力してください。角括弧・改行は使用できません。');
  if Trim(S.Database)<>'' then ConnectionString(S)
  else begin
    if S.Mode=cmConnectionString then raise Exception.Create('接続文字列を直接指定する登録にはDBパスが必要です。');
    if (S.Port<1) or (S.Port>65535) then raise Exception.Create('ポートは1～65535で指定してください。');
    if (S.Mode=cmRemoteTCP) and (Trim(S.Host)='') then raise Exception.Create('サーバー名またはIPアドレスを入力してください。');
  end;
  ForceDirectories(ExtractFileDir(ExpandFileName(FileName)));
  I := TIniFile.Create(FileName);
  try
    I.WriteInteger(N, 'Mode', Ord(S.Mode));
    I.WriteString(N, 'Host', S.Host);
    I.WriteInteger(N, 'Port', S.Port);
    I.WriteString(N, 'Database', S.Database);
    I.WriteString(N, 'User', S.UserName);
    I.WriteString(N, 'Role', S.Role);
    I.WriteString(N, 'Library', S.ClientLibrary);
    I.WriteString(N, 'ServerAlias', S.ServerAlias);
    I.WriteString(N, 'Description', S.Description);
    I.DeleteKey(N, 'Password');
    I.UpdateFile;
  finally
    I.Free;
  end;
end;

end.
