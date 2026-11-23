unit ServerSession;

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses Classes, ConnectionSettings, ibase60dyn;

type
  TServerSession=class
  private
    FHandle:isc_svc_handle;
    FLoaded:Boolean;
    FSettings:TConnectionSettings;
    FUserName,FPassword,FRole:string;
    procedure Check(Code:ISC_STATUS;var Status:array of ISC_STATUS);
  public
    constructor Create;
    destructor Destroy;override;
    procedure Login(const Settings:TConnectionSettings;const UserName,Password,Role:string);
    procedure Logout;
    function IsLoggedIn:Boolean;
    function Matches(const Settings:TConnectionSettings):Boolean;
    function GetLoginCredentials(const Settings:TConnectionSettings;out UserName,Password,Role:string):Boolean;
    procedure ReadInformation(out Version:string;Databases:TStrings;out DatabaseCount,AttachmentCount:LongWord);
  end;

implementation

uses SysUtils;

procedure TServerSession.ReadInformation(out Version:string;Databases:TStrings;out DatabaseCount,AttachmentCount:LongWord);
var Status:array[0..19] of ISC_STATUS;Buffer:array[0..65534] of Byte;
    Tag:AnsiChar;P,L:Integer;Item:Byte;S:string;
  procedure Query(Value:Byte);
  begin
    FillChar(Buffer,SizeOf(Buffer),0);FillChar(Status,SizeOf(Status),0);Tag:=AnsiChar(Value);
    Check(isc_service_query(@Status[0],@FHandle,nil,0,nil,1,@Tag,SizeOf(Buffer),PChar(@Buffer[0])),Status);
    if Buffer[0]<>Value then raise Exception.Create('サーバー情報を取得できませんでした。');
    P:=1;
  end;
  function Number(Bytes:Integer):LongWord;
  var I:Integer;
  begin
    if P+Bytes>SizeOf(Buffer) then raise Exception.Create('サーバー情報の応答が不正です。');
    Result:=0;for I:=0 to Bytes-1 do Result:=Result or (LongWord(Buffer[P+I]) shl (8*I));Inc(P,Bytes);
  end;
begin
  if not IsLoggedIn then raise Exception.Create('サーバーへログインしてください。');
  Databases.Clear;DatabaseCount:=0;AttachmentCount:=0;
  Query(isc_info_svc_server_version);L:=Number(2);
  if P+L>SizeOf(Buffer) then raise Exception.Create('バージョン情報の応答が不正です。');
  SetString(Version,PChar(@Buffer[P]),L);
  Query(isc_info_svc_svr_db_info);
  while P<SizeOf(Buffer) do begin
    Item:=Buffer[P];Inc(P);
    case Item of
      isc_info_end,isc_info_flag_end:Exit;
      isc_spb_num_att:AttachmentCount:=Number(4);
      isc_spb_num_db:DatabaseCount:=Number(4);
      isc_spb_dbname:begin
        L:=Number(2);if P+L>SizeOf(Buffer) then raise Exception.Create('DB一覧の応答が不正です。');
        SetString(S,PChar(@Buffer[P]),L);Databases.Add(S);Inc(P,L);
      end;
      else raise Exception.Create('サーバー情報が未対応の形式、または応答サイズの上限を超えています。');
    end;
  end;
  raise Exception.Create('サーバー情報の終端を取得できませんでした。');
end;

constructor TServerSession.Create;
begin inherited Create;FHandle:=0;FLoaded:=False;end;

destructor TServerSession.Destroy;
begin try Logout except end;inherited Destroy;end;

procedure TServerSession.Check(Code:ISC_STATUS;var Status:array of ISC_STATUS);
var P:PISC_STATUS;Buf:array[0..2047] of AnsiChar;S:string;
begin
  if Code=0 then Exit;
  P:=@Status[0];S:='';
  while isc_interprete(@Buf[0],@P)>0 do begin
    if S<>'' then S:=S+LineEnding;S:=S+StrPas(@Buf[0]);
  end;
  if S='' then S:='Firebird service error '+IntToStr(Code);
  raise Exception.Create(S);
end;

procedure TServerSession.Login(const Settings:TConnectionSettings;const UserName,Password,Role:string);
var Status:array[0..19] of ISC_STATUS;Host,ServiceName,SPB:string;Code:ISC_STATUS;
begin
  if IsLoggedIn then begin
    if Matches(Settings) then Exit;
    raise Exception.Create('別のサーバーにログイン中です。先にログアウトしてください。');
  end;
  if Settings.Mode=cmConnectionString then raise Exception.Create('サーバーログインには登録済みTCP/IPサーバーを指定してください。');
  if not FileExists(Settings.ClientLibrary) then raise Exception.Create('Firebirdクライアントライブラリが見つかりません。');
  if (Length(UserName)>255) or (Length(Password)>255) or (Length(Role)>255) then
    raise Exception.Create('ユーザー名、パスワード、ロールは255バイト以内で指定してください。');
  if Settings.Mode=cmLocalTCP then Host:='localhost' else Host:=Trim(Settings.Host);
  if Pos(':',Host)>0 then Host:='['+Host+']';
  ServiceName:=Host+'/'+IntToStr(Settings.Port)+':service_mgr';
  SPB:=Chr(isc_spb_version)+Chr(isc_spb_current_version)+
    Chr(isc_spb_user_name)+Chr(Length(UserName))+UserName+
    Chr(isc_spb_password)+Chr(Length(Password))+Password;
  if Role<>'' then SPB:=SPB+Chr(isc_spb_sql_role_name)+Chr(Length(Role))+Role;
  SPB:=SPB+Chr(118)+Chr(0);
  FillChar(Status,SizeOf(Status),0);FHandle:=0;
  InitialiseIBase60(AnsiString(Settings.ClientLibrary));FLoaded:=True;
  try
    Code:=isc_service_attach(@Status[0],Length(ServiceName),PChar(ServiceName),@FHandle,Length(SPB),PChar(SPB));
    Check(Code,Status);FSettings:=Settings;
    FUserName:=UserName;FPassword:=Password;FRole:=Role;
  except
    if FLoaded then begin ReleaseIBase60;FLoaded:=False;end;
    FHandle:=0;FUserName:='';FPassword:='';FRole:='';raise;
  end;
  SPB:='';
end;

procedure TServerSession.Logout;
var Status:array[0..19] of ISC_STATUS;Code:ISC_STATUS;
begin
  if not FLoaded then Exit;
  try
    if FHandle<>0 then begin FillChar(Status,SizeOf(Status),0);Code:=isc_service_detach(@Status[0],@FHandle);Check(Code,Status);end;
  finally
    FHandle:=0;FLoaded:=False;FUserName:='';FPassword:='';FRole:='';ReleaseIBase60;
  end;
end;

function TServerSession.IsLoggedIn:Boolean;
begin Result:=FLoaded and (FHandle<>0);end;

function TServerSession.Matches(const Settings:TConnectionSettings):Boolean;
begin
  Result:=IsLoggedIn and (FSettings.Mode=Settings.Mode) and
    SameText(FSettings.Host,Settings.Host) and (FSettings.Port=Settings.Port);
end;

function TServerSession.GetLoginCredentials(const Settings:TConnectionSettings;
  out UserName,Password,Role:string):Boolean;
begin
  Result:=Matches(Settings);
  if Result then begin UserName:=FUserName;Password:=FPassword;Role:=FRole;end
  else begin UserName:='';Password:='';Role:='';end;
end;

end.
