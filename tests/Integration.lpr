program Integration;

{$mode objfpc}{$H+}
{$codepage utf8}

uses SysUtils, DB, SQLDB, SQLDBLib, IBConnection, FBSession;

var C: TIBConnection; T: TSQLTransaction; L: TSQLDBLibraryLoader;
    Q: TSQLQuery; DatabasePath: string;

procedure Exec(const SQL: string);
begin
  Q.Close;
  Q.SQL.Text := SQL;
  Q.ExecSQL;
end;

procedure Check(const Condition: Boolean; const Description: string);
begin
  if not Condition then raise Exception.Create('FAIL: ' + Description);
  WriteLn('PASS: ', Description);
end;

begin
  if ParamCount <> 2 then
  begin
    WriteLn('Integration <absolute fbclient library> <new scratch database path>');
    Halt(2);
  end;
  DatabasePath := ExpandFileName(ParamStr(2));
  if FileExists(DatabasePath) then
    raise Exception.Create('Refusing to reuse an existing database: ' + DatabasePath);
  L := TSQLDBLibraryLoader.Create(nil);
  C := TIBConnection.Create(nil);
  T := TSQLTransaction.Create(nil);
  Q := TSQLQuery.Create(nil);
  try
    L.ConnectionType := 'Firebird';
    L.LibraryName := ExpandFileName(ParamStr(1));
    L.Enabled := True;
    C.Transaction := T;
    T.Database := C;
    C.DatabaseName := DatabasePath;
    C.UserName := 'SYSDBA';
    C.CharSet := 'UTF8';
    C.Dialect := 3;
    C.LoginPrompt := False;
    C.CreateDB;
    C.Open;
    ConfigureFirebird5(C, T);
    Q.Database := C;
    Q.Transaction := T;
    Q.ParamCheck := False;
    Q.SQL.Text := 'SELECT ' +
      'CAST(12345678901234567890123456789012345678 AS INT128) AS I, ' +
      'CAST(12345678901234567890.123456789012345678 AS NUMERIC(38,18)) AS N, ' +
      'CAST(''1.234567890123456789012345678901234E+100'' AS DECFLOAT(34)) AS D, ' +
      'CAST(''12:34:56.7890 +09:00'' AS TIME WITH TIME ZONE) AS TZ, ' +
      'CAST(''2026-11-02 12:34:56.7890 +09:00'' AS TIMESTAMP WITH TIME ZONE) AS TS, ' +
      'TRUE AS B, CAST(NULL AS INTEGER) AS Z, ' +
      'CAST(_UTF8 ''日本語テスト'' AS VARCHAR(30) CHARACTER SET UTF8) AS J FROM RDB$DATABASE';
    Q.Open;
    Check(Q.FieldByName('I').AsString = '12345678901234567890123456789012345678', 'INT128 exact digits');
    Check(Q.FieldByName('N').AsString = '12345678901234567890.123456789012345678', 'NUMERIC(38,18) exact digits');
    WriteLn('DECFLOAT: ', Q.FieldByName('D').AsString);
    Check(Pos('1.234567890123456789012345678901234', Q.FieldByName('D').AsString) > 0, 'DECFLOAT precision');
    Check(Pos('09:00', Q.FieldByName('TZ').AsString) > 0, 'TIME timezone preserved');
    Check(Pos('2026-11-02', Q.FieldByName('TS').AsString) > 0, 'TIMESTAMP date preserved');
    Check(Pos('09:00', Q.FieldByName('TS').AsString) > 0, 'TIMESTAMP timezone preserved');
    Check(Q.FieldByName('B').AsBoolean, 'BOOLEAN');
    Check(Q.FieldByName('Z').IsNull, 'NULL');
    Check(Q.FieldByName('J').AsString = UTF8Encode('日本語テスト'), 'UTF8 Japanese round trip');
    Q.Close;
    T.Rollback;
    Exec('CREATE TABLE TX_TEST (ID INTEGER NOT NULL PRIMARY KEY)');
    T.Commit;
    Exec('INSERT INTO TX_TEST VALUES (1)');
    T.Rollback;
    Q.SQL.Text := 'SELECT COUNT(*) FROM TX_TEST';
    Q.Open;
    Check(Q.Fields[0].AsInteger = 0, 'rollback discards insert');
    Q.Close;
    T.Rollback;
    Exec('INSERT INTO TX_TEST VALUES (2)');
    T.Commit;
    Q.SQL.Text := 'SELECT COUNT(*) FROM TX_TEST';
    Q.Open;
    Check(Q.Fields[0].AsInteger = 1, 'commit persists insert');
    Q.Close;
    T.Rollback;
    WriteLn('All integration checks passed. Scratch database retained: ', DatabasePath);
  finally
    Q.Free;
    if T.Active then T.Rollback;
    C.Close;
    C.Free;
    T.Free;
    L.Free;
  end;
end.
