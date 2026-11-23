unit FBSession;

{$mode objfpc}{$H+}

interface

uses SysUtils, SQLDB, IBConnection;

// Bind only the returned representation. Values stored on the server retain
// their native types and precision. Do not use LEGACY or DOUBLE conversions.
procedure ConfigureFirebird5(Connection: TIBConnection; Transaction: TSQLTransaction);

implementation

procedure ConfigureFirebird5(Connection: TIBConnection; Transaction: TSQLTransaction);
const Binds: array[0..4] of string = (
  'SET BIND OF INT128 TO VARCHAR(100)',
  'SET BIND OF DECFLOAT(16) TO VARCHAR(100)',
  'SET BIND OF DECFLOAT(34) TO VARCHAR(100)',
  'SET BIND OF TIME WITH TIME ZONE TO VARCHAR(128)',
  'SET BIND OF TIMESTAMP WITH TIME ZONE TO VARCHAR(128)');
var Q: TSQLQuery; S: string;
begin
  Q := TSQLQuery.Create(nil);
  try
    Q.Database := Connection;
    Q.Transaction := Transaction;
    Q.SQL.Text := 'SELECT RDB$GET_CONTEXT(''SYSTEM'', ''ENGINE_VERSION'') AS V FROM RDB$DATABASE';
    Q.Open;
    S := Q.Fields[0].AsString;
    Q.Close;
    if Copy(S, 1, 2) <> '5.' then
      raise Exception.Create('Firebird 5 required; connected server: ' + S);
    for S in Binds do
    begin
      Q.SQL.Text := S;
      Q.ExecSQL;
    end;
    Transaction.Commit;
  finally
    Q.Free;
  end;
end;

end.
