program ServicesTest;
{$mode objfpc}{$H+}
uses SysUtils,SQLDBLib,IBConnection,SQLDB,FirebirdServices;
var L:TSQLDBLibraryLoader;C:TIBConnection;T:TSQLTransaction;Q:TSQLQuery;Source,Backup,Restored:string;
begin
  if ParamCount<>4 then raise Exception.Create('ServicesTest <client library> <scratch database> <new backup> <new restored database>');
  Source:=ExpandFileName(ParamStr(2));Backup:=ExpandFileName(ParamStr(3));Restored:=ExpandFileName(ParamStr(4));
  if FileExists(Backup) or FileExists(Restored) then raise Exception.Create('Refusing to reuse output files');
  L:=TSQLDBLibraryLoader.Create(nil);C:=TIBConnection.Create(nil);T:=TSQLTransaction.Create(nil);Q:=TSQLQuery.Create(nil);
  try
    L.ConnectionType:='Firebird';L.LibraryName:=ParamStr(1);L.Enabled:=True;
    RunService('service_mgr','SYSDBA','','',Source,Backup,soBackup,nil);
    if not FileExists(Backup) then raise Exception.Create('Backup missing');
    WriteLn('PASS: Services API backup');
    RunService('service_mgr','SYSDBA','','',Restored,Backup,soRestore,nil);
    if not FileExists(Restored) then raise Exception.Create('Restored database missing');
    C.Transaction:=T;T.Database:=C;C.DatabaseName:=Restored;C.UserName:='SYSDBA';C.CharSet:='UTF8';C.Open;
    Q.Database:=C;Q.Transaction:=T;Q.SQL.Text:='SELECT ID FROM TX_TEST';Q.Open;
    if Q.Fields[0].AsInteger<>2 then raise Exception.Create('Restored data mismatch');
    Q.Close;T.Rollback;C.Close;
    WriteLn('PASS: restore and data integrity');
    try
      RunService('service_mgr','SYSDBA','','',Restored,Backup,soRestore,nil);
      raise Exception.Create('Existing restore target was overwritten');
    except on E:Exception do begin
      if Pos('Existing restore target was overwritten',E.Message)>0 then raise;
      WriteLn('PASS: restore refuses existing target');
    end;end;
    RunService('service_mgr','SYSDBA','','',Restored,'',soValidate,nil);
    WriteLn('PASS: read-only validation');
    RunService('service_mgr','SYSDBA','','',Restored,'',soSweep,nil);
    WriteLn('PASS: sweep');
  finally
    Q.Free;if T.Active then T.Rollback;C.Close;C.Free;T.Free;L.Free;
  end;
end.
