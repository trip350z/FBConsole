unit DatabaseAdmin;

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses Classes, ConnectionSettings;

procedure CreateRemoteDatabase(const Settings:TConnectionSettings;const UserName,Password,Role:string;
  Files,PageLengths:TStrings;PageSize:Integer;const CharacterSet:string;Dialect:Integer);
procedure DropRemoteDatabase(const Settings:TConnectionSettings;const UserName,Password,Role:string);

implementation

uses SysUtils, IBConnection, ibase60dyn;

function QuoteSQLString(const S:string):string;
begin
  if (Pos(#0,S)>0) or (Pos(#13,S)>0) or (Pos(#10,S)>0) then raise Exception.Create('SQL文字列に制御文字は使用できません。');
  Result:=''''+StringReplace(S,'''','''''',[rfReplaceAll])+'''';
end;

function ServerDatabaseSpec(const Settings:TConnectionSettings;const DatabasePath:string):string;
var Host:string;
begin
  if Settings.Mode=cmConnectionString then raise Exception.Create('接続文字列を直接指定する接続ではこの操作を使えません。');
  if Settings.Mode=cmLocalTCP then Host:='localhost' else Host:=Trim(Settings.Host);
  if Host='' then raise Exception.Create('サーバー名がありません。');
  if (Pos(':',Host)>0) and (Host[1]<>'[') then Host:='['+Host+']';
  Result:=Host+'/'+IntToStr(Settings.Port)+':'+DatabasePath;
end;

procedure RaiseClientError(Code:ISC_STATUS;var Status:array of ISC_STATUS);
var P:PISC_STATUS;Buf:array[0..2047] of AnsiChar;S:string;
begin
  if Code=0 then Exit;
  P:=@Status[0];S:='';
  while isc_interprete(@Buf[0],@P)>0 do begin
    if S<>'' then S:=S+LineEnding;
    S:=S+StrPas(@Buf[0]);
  end;
  if S='' then S:='Firebird client error '+IntToStr(Code);
  raise Exception.Create(S);
end;

procedure CreateRemoteDatabase(const Settings:TConnectionSettings;const UserName,Password,Role:string;
  Files,PageLengths:TStrings;PageSize:Integer;const CharacterSet:string;Dialect:Integer);
var SQL,DBSpec,LengthText:string;I,SQLDialect:Integer;Status:array[0..19] of ISC_STATUS;
    DBHandle:isc_db_handle;TranHandle:isc_tr_handle;Code:ISC_STATUS;Loaded:Boolean;
  procedure ExecuteImmediate(const Statement:string;SQLDialect:Integer);
  begin
    if Length(Statement)>65535 then raise Exception.Create('CREATE DATABASE文が長すぎます。');
    FillChar(Status,SizeOf(Status),0);
    Code:=isc_dsql_execute_immediate(@Status[0],@DBHandle,@TranHandle,
      Length(Statement),PChar(Statement),SQLDialect,nil);
    RaiseClientError(Code,Status);
  end;
begin
  if (Files=nil) or (Files.Count=0) then raise Exception.Create('DBファイル名を1つ以上指定してください。');
  if (PageLengths=nil) or (PageLengths.Count<>Files.Count) then raise Exception.Create('ファイルサイズの指定が不正です。');
  if not FileExists(Settings.ClientLibrary) then raise Exception.Create('Firebirdクライアントライブラリが見つかりません。');
  DBSpec:=ServerDatabaseSpec(Settings,Files[0]);
  SQL:='CREATE DATABASE '+QuoteSQLString(DBSpec)+
    ' USER '+QuoteSQLString(UserName)+' PASSWORD '+QuoteSQLString(Password);
  if Role<>'' then SQL:=SQL+' ROLE '+QuoteSQLString(Role);
  SQL:=SQL+' PAGE_SIZE '+IntToStr(PageSize);
  LengthText:=Trim(PageLengths[0]);if LengthText<>'' then SQL:=SQL+' LENGTH '+LengthText+' PAGES';
  SQL:=SQL+' DEFAULT CHARACTER SET '+CharacterSet;
  for I:=1 to Files.Count-1 do begin
    SQL:=SQL+' FILE '+QuoteSQLString(Files[I]);
    LengthText:=Trim(PageLengths[I]);if LengthText<>'' then SQL:=SQL+' LENGTH '+LengthText+' PAGES';
  end;
  if Dialect=1 then SQLDialect:=1 else SQLDialect:=3;
  Loaded:=False;DBHandle:=0;TranHandle:=0;
  try
    InitialiseIBase60(AnsiString(Settings.ClientLibrary));Loaded:=True;
    if SQLDialect=1 then ExecuteImmediate('SET SQL DIALECT 1',1);
    ExecuteImmediate(SQL,SQLDialect);
  finally
    if Loaded then ReleaseIBase60;
  end;
end;

procedure DropRemoteDatabase(const Settings:TConnectionSettings;const UserName,Password,Role:string);
var DB:TIBConnection;Path:string;
begin
  Path:=Trim(Settings.Database);
  if Path='' then raise Exception.Create('削除対象のDBパスがありません。');
  if not FileExists(Settings.ClientLibrary) then raise Exception.Create('Firebirdクライアントライブラリが見つかりません。');
  DB:=TIBConnection.Create(nil);
  try
    if Settings.Mode=cmLocalTCP then DB.HostName:='localhost' else DB.HostName:=Settings.Host;
    DB.Port:=Settings.Port;DB.DatabaseName:=Path;DB.UserName:=UserName;DB.Password:=Password;
    DB.Role:=Role;DB.CharSet:='UTF8';DB.Dialect:=3;DB.LoginPrompt:=False;
    DB.DropDB;
  finally
    DB.Password:='';DB.Free;
  end;
end;

end.
