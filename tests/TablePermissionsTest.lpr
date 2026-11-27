program TablePermissionsTest;
{$mode objfpc}{$H+}{$codepage utf8}
uses Interfaces,Forms,SysUtils,SQLDB,SQLDBLib,IBConnection,TablePermissions;
type
  TPermissionAccess=class(TPermissionMatrix)
    function CellHint(AColumn,ARow:Integer):string;
  end;
function TPermissionAccess.CellHint(AColumn,ARow:Integer):string;
begin Result:=GetCellHintText(AColumn,ARow);end;
var Loader:TSQLDBLibraryLoader;Connection:TIBConnection;Transaction:TSQLTransaction;
    Query:TSQLQuery;Window:TForm;Matrix:TPermissionMatrix;R:Integer;
procedure Exec(const SQL:string);
begin Query.Close;Query.SQL.Text:=SQL;Query.ExecSQL;end;
procedure Check(Value:Boolean;const Description:string);
begin if not Value then raise Exception.Create('FAIL: '+Description);WriteLn('PASS: ',Description);end;
function RowOf(const Principal:string):Integer;
var I:Integer;
begin
 for I:=1 to Matrix.RowCount-1 do if Matrix.Cells[0,I]=Principal then Exit(I);
 raise Exception.Create('Missing principal: '+Principal);
end;
begin
 if ParamCount<>2 then begin WriteLn('TablePermissionsTest <fbclient> <new scratch database>');Halt(2);end;
 if FileExists(ParamStr(2)) then raise Exception.Create('Refusing to reuse an existing database');
 Application.Initialize;Loader:=TSQLDBLibraryLoader.Create(nil);Connection:=TIBConnection.Create(nil);
 Transaction:=TSQLTransaction.Create(nil);Query:=TSQLQuery.Create(nil);Window:=TForm.CreateNew(nil);
 try
  Loader.ConnectionType:='Firebird';Loader.LibraryName:=ParamStr(1);Loader.Enabled:=True;
  Connection.Transaction:=Transaction;Transaction.Database:=Connection;
  Connection.DatabaseName:=ParamStr(2);Connection.UserName:='SYSDBA';Connection.Password:='masterkey';
  Connection.CharSet:='UTF8';Connection.LoginPrompt:=False;Connection.CreateDB;Connection.Open;
  Query.Database:=Connection;Query.Transaction:=Transaction;Query.ParamCheck:=False;
  Exec('CREATE TABLE PERMISSION_TEST (ID INTEGER NOT NULL PRIMARY KEY,NOTE VARCHAR(40) CHARACTER SET UTF8)');
  Exec('CREATE ROLE REPORT_READER');Exec('CREATE ROLE SHARED_NAME');Transaction.Commit;
  Exec('GRANT SELECT,DELETE ON PERMISSION_TEST TO PUBLIC');
  Exec('GRANT UPDATE(NOTE) ON PERMISSION_TEST TO USER WRITER WITH GRANT OPTION');
  Exec('GRANT SELECT ON PERMISSION_TEST TO ROLE REPORT_READER');
  Exec('GRANT REPORT_READER TO USER WRITER WITH ADMIN OPTION');
  Exec('GRANT INSERT ON PERMISSION_TEST TO USER SHARED_NAME');
  Exec('GRANT DELETE ON PERMISSION_TEST TO ROLE SHARED_NAME');
  Exec('GRANT UPDATE ON PERMISSION_TEST TO USER MIXED_SCOPE');
  Exec('GRANT UPDATE(NOTE) ON PERMISSION_TEST TO USER MIXED_SCOPE WITH GRANT OPTION');
  Exec('GRANT SELECT ON PERMISSION_TEST TO USER "利用者" WITH GRANT OPTION');Transaction.Commit;
  Matrix:=TPermissionMatrix.CreateMatrix(nil,Connection,Transaction,'PERMISSION_TEST');
  try
   Matrix.Parent:=Window;
   Check((Matrix.Cells[0,0]='Object')and(Matrix.Cells[7,0]='Member Of'),'matrix headings');
   R:=RowOf('PUBLIC');Check((Matrix.Cells[1,R]='Y')and(Matrix.Cells[2,R]='Y')and(Matrix.Cells[4,R]=''),'PUBLIC grants and absent privilege');
   R:=RowOf('WRITER');Check(Matrix.Cells[4,R]='Y*','column-only grant stays scoped');
   Check((Pos('NOTE',TPermissionAccess(Matrix).CellHint(4,R))>0)and(Pos('WITH GRANT OPTION',TPermissionAccess(Matrix).CellHint(4,R))>0),'column and grant option retained in hint');
   Check((Matrix.Cells[7,R]='REPORT_READER')and(Pos('WITH ADMIN OPTION',TPermissionAccess(Matrix).CellHint(7,R))>0),'direct role and admin option');
   R:=RowOf('REPORT_READER [Role]');Check(Matrix.Cells[1,R]='Y','role privileges have their own row');
   R:=RowOf('SHARED_NAME');Check((Matrix.Cells[3,R]='Y')and(Matrix.Cells[2,R]=''),'user and role with the same name remain distinct');
   R:=RowOf('SHARED_NAME [Role]');Check((Matrix.Cells[2,R]='Y')and(Matrix.Cells[3,R]=''),'role identity retained');
   R:=RowOf('MIXED_SCOPE');Check((Matrix.Cells[4,R]='Y*')and(Pos('WITH GRANT OPTION',TPermissionAccess(Matrix).CellHint(4,R))>0),'mixed grant option stays scoped to its column');
   R:=RowOf('利用者');Check((Matrix.Cells[1,R]='Y')and(Pos('SYSDBA',TPermissionAccess(Matrix).CellHint(1,R))>0),'UTF8 principal and grantor');
  finally Matrix.Free;end;
  Matrix:=TPermissionMatrix.CreateMatrix(nil,Connection,Transaction,'NO_SUCH_TEST_OBJECT');
  try Check((Matrix.RowCount=2)and(Matrix.Cells[1,1]=''),'empty permission matrix');finally Matrix.Free;end;
  if Transaction.Active then Transaction.Rollback;
  Connection.Close;
 finally Window.Free;Query.Free;Transaction.Free;Connection.Free;Loader.Free;end;
end.
