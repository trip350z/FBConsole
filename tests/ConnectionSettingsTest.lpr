program ConnectionSettingsTest;
{$mode objfpc}{$H+}
uses Classes, SysUtils, IniFiles, ConnectionSettings;
var S, Loaded: TConnectionSettings; ConfigPath: string; I: TIniFile; Lines: TStringList;

procedure Check(Condition: Boolean; const Description: string);
begin
  if not Condition then raise Exception.Create('FAIL: ' + Description);
  WriteLn('PASS: ', Description);
end;

procedure Reject(const Description: string);
var Failed: Boolean;
begin
  Failed := False;
  try ConnectionString(S); except on E: Exception do Failed := True; end;
  Check(Failed, Description);
end;

begin
  S := DefaultSettings;
  S.Database := 'employee';
  Check(ConnectionString(S) = 'inet://localhost:3050/employee', 'local uses explicit TCP, not embedded');
  S.Mode := cmRemoteTCP;
  S.Host := '192.168.100.252';
  S.Database := '/var/firebird/timecard.fdb';
  Check(ConnectionString(S) = 'inet://192.168.100.252:3050//var/firebird/timecard.fdb', 'remote Linux absolute path');
  S.Host := 'db.example.test';
  S.Port := 3052;
  S.Database := 'D:\Databases\sample.fdb';
  Check(ConnectionString(S) = 'inet://db.example.test:3052/D:\Databases\sample.fdb', 'remote Windows path and custom port');
  S.Host := '2001:db8::1';
  S.Database := 'alias';
  Check(ConnectionString(S) = 'inet://[2001:db8::1]:3052/alias', 'IPv6 literal');
  S.Host := '[::1]';
  Check(ConnectionString(S) = 'inet://[::1]:3052/alias', 'bracketed IPv6 literal');
  S.Port := 0;
  Reject('invalid port rejected');
  S.Port := 3050;
  S.Host := 'server/3050';
  Reject('host cannot contain connection-string separators');
  S.Host := '';
  Reject('empty remote host rejected');
  S.Host := 'server';
  S.Database := '';
  Reject('empty database rejected');
  S.Database := 'alias' + #10 + 'bad';
  Reject('control characters rejected');
  S.Mode := cmConnectionString;
  S.Database := 'oldserver/3051:/srv/data.fdb';
  Check(ConnectionString(S) = S.Database, 'legacy full connection string preserved');

  ConfigPath := ExpandFileName(ParamStr(1));
  if (ParamCount <> 1) or FileExists(ConfigPath) then
    raise Exception.Create('Provide a new scratch INI path');
  S.Name := 'Test profile';
  S.Mode := cmRemoteTCP;
  S.Host := '192.168.100.252';
  S.Port := 3050;
  S.Database := '/var/firebird/timecard.fdb';
  S.Role := 'APP_ROLE';
  S.ClientLibrary := 'C:\Client\fbclient.dll';
  WriteSettings(ConfigPath, S);
  ReadSettings(ConfigPath, S.Name, Loaded);
  Check(ConnectionString(Loaded) = ConnectionString(S), 'saved host, mode, port and database round trip');
  Check((Loaded.Role = S.Role) and (Loaded.UserName = S.UserName) and
    (Loaded.ClientLibrary = S.ClientLibrary), 'saved identity and client library round trip');
  I := TIniFile.Create(ConfigPath);
  Lines := TStringList.Create;
  try
    Check(not I.ValueExists(S.Name, 'Password'), 'password not persisted');
    I.WriteString('Old profile', 'Database', 'oldserver:/srv/old.fdb');
    I.UpdateFile;
    ReadSettings(ConfigPath, 'Old profile', Loaded);
    Check((Loaded.Mode = cmConnectionString) and
      (ConnectionString(Loaded) = 'oldserver:/srv/old.fdb'), '0.1 profile migration');
  finally
    Lines.Free;
    I.Free;
  end;
end.
