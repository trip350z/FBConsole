unit DatabaseMetadata;

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses Classes, SQLDB;

function ExtractDatabaseMetadata(ADatabase: TSQLConnection;
  ATransaction: TSQLTransaction): TStringList;

implementation

uses SysUtils, TableMetadata;

function QI(const S: string): string;
begin
  Result := QuoteName(S);
end;

function Val(Q: TSQLQuery; const Field: string): string;
begin
  if Q.FieldByName(Field).IsNull then Result := ''
  else Result := TrimRight(Q.FieldByName(Field).AsString);
end;

procedure OpenQuery(Q: TSQLQuery; const SQL: string);
begin
  Q.Close;
  Q.SQL.Text := SQL;
  Q.Open;
end;

procedure AddSourceSection(L: TStrings; Q: TSQLQuery; const Title, SQL: string);
var N, Src, LineText: string; Lines: TStringList; K: Integer;
begin
  OpenQuery(Q, SQL);
  if Q.EOF then Exit;
  L.Add('-- ' + Title);
  while not Q.EOF do begin
    N := Val(Q, 'OBJECT_NAME');
    Src := Val(Q, 'SOURCE_SQL');
    if Src <> '' then begin
      L.Add('-- ' + Title + ': ' + QI(N));
      // Source text is shown for inspection; object headers/parameters are
      // not reconstructed here, so keep these blocks from being run as DDL.
      Lines := TStringList.Create;
      try
        Lines.Text := Src;
        for K := 0 to Lines.Count - 1 do begin
          LineText := Lines[K];
          L.Add('--   ' + LineText);
        end;
      finally
        Lines.Free;
      end;
      L.Add('');
    end else
      L.Add('-- ' + N + ': ソースを取得できません（外部関数または定義なし）');
    Q.Next;
  end;
  L.Add('');
end;

function ExtractDatabaseMetadata(ADatabase: TSQLConnection;
  ATransaction: TSQLTransaction): TStringList;
var
  Q, Q2, Q3: TSQLQuery;
  Name, DomainName, Def, Src, Kind, Columns, RefColumns, RefName, ConstraintName,
    UpdateRule, DeleteRule: string;
  N: Integer;
  procedure AddComma;
  begin
    if N > 0 then Result[Result.Count-1] := Result[Result.Count-1] + ',';
  end;
begin
  Result := TStringList.Create;
  Result.LineBreak := LineEnding;
  Q := TSQLQuery.Create(nil);
  Q2 := TSQLQuery.Create(nil);
  Q3 := TSQLQuery.Create(nil);
  try
    Q.Database := ADatabase; Q.Transaction := ATransaction;
    Q.ReadOnly := True; Q.ParamCheck := False;
    Q2.Database := ADatabase; Q2.Transaction := ATransaction;
    Q2.ReadOnly := True; Q2.ParamCheck := False;
    Q3.Database := ADatabase; Q3.Transaction := ATransaction;
    Q3.ReadOnly := True; Q3.ParamCheck := False;
    Result.Add('-- FBConsole: Firebirdデータベース メタデータ');
    Result.Add('-- 接続先: ' + ADatabase.DatabaseName);
    Result.Add('-- 生成日時: ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    Result.Add('-- メタデータの表示用スクリプトです。適用前に内容と依存順を確認してください。');
    Result.Add('');

    OpenQuery(Q, 'SELECT TRIM(F.RDB$FIELD_NAME) AS OBJECT_NAME, F.RDB$FIELD_TYPE AS TYPE_CODE, '+
      'F.RDB$FIELD_SUB_TYPE AS SUB_TYPE, F.RDB$FIELD_PRECISION AS FIELD_PRECISION, '+
      'F.RDB$FIELD_SCALE AS FIELD_SCALE, F.RDB$CHARACTER_LENGTH AS CHARACTER_COUNT, '+
      'TRIM(CS.RDB$CHARACTER_SET_NAME) AS CHARSET_NAME, TRIM(CO.RDB$COLLATION_NAME) AS COLLATION_NAME, '+
      'F.RDB$DEFAULT_SOURCE AS DEFAULT_SOURCE, F.RDB$VALIDATION_SOURCE AS CHECK_SOURCE, '+
      'F.RDB$NULL_FLAG AS NOT_NULL_FLAG FROM RDB$FIELDS F '+
      'LEFT JOIN RDB$CHARACTER_SETS CS ON CS.RDB$CHARACTER_SET_ID=F.RDB$CHARACTER_SET_ID '+
      'LEFT JOIN RDB$COLLATIONS CO ON CO.RDB$CHARACTER_SET_ID=F.RDB$CHARACTER_SET_ID '+
      'AND CO.RDB$COLLATION_ID=F.RDB$COLLATION_ID '+
      'WHERE COALESCE(F.RDB$SYSTEM_FLAG,0)=0 AND F.RDB$FIELD_NAME NOT STARTING WITH ''RDB$'' '+
      'ORDER BY F.RDB$FIELD_NAME');
    if not Q.EOF then Result.Add('-- ドメイン');
    while not Q.EOF do begin
      Name := Val(Q, 'OBJECT_NAME');
      Def := 'CREATE DOMAIN ' + QI(Name) + ' AS ' + FieldTypeName(Q);
      if Val(Q, 'CHARSET_NAME') <> '' then Def := Def + ' CHARACTER SET ' + QI(Val(Q,'CHARSET_NAME'));
      if Val(Q, 'COLLATION_NAME') <> '' then Def := Def + ' COLLATE ' + QI(Val(Q,'COLLATION_NAME'));
      if Val(Q, 'NOT_NULL_FLAG') = '1' then Def := Def + ' NOT NULL';
      if Val(Q, 'DEFAULT_SOURCE') <> '' then Def := Def + ' ' + Val(Q,'DEFAULT_SOURCE');
      if Val(Q, 'CHECK_SOURCE') <> '' then Def := Def + ' ' + Val(Q,'CHECK_SOURCE');
      Result.Add(Def + ';');
      Q.Next;
    end;
    if Result.Count > 1 then Result.Add('');

    OpenQuery(Q, 'SELECT TRIM(RDB$RELATION_NAME) AS OBJECT_NAME FROM RDB$RELATIONS '+
      'WHERE RDB$VIEW_BLR IS NULL AND COALESCE(RDB$SYSTEM_FLAG,0)=0 ORDER BY RDB$RELATION_NAME');
    if not Q.EOF then Result.Add('-- テーブル');
    while not Q.EOF do begin
      Name := Val(Q, 'OBJECT_NAME');
      Result.Add('CREATE TABLE ' + QI(Name) + ' (');
      OpenQuery(Q2, ColumnSQL(Name));
      N := 0;
      while not Q2.EOF do begin
        if N > 0 then Result[Result.Count-1] := Result[Result.Count-1] + ',';
        Src := QI(Val(Q2, 'FIELD_NAME')) + ' ';
        Def := Val(Q2, 'COMPUTED_SOURCE');
        if Def <> '' then Src := QI(Val(Q2, 'FIELD_NAME')) + ' COMPUTED BY ' + Def
        else begin
          DomainName := Val(Q2, 'FIELD_SOURCE');
          if (DomainName <> '') and (Copy(DomainName,1,3) <> 'RDB') then
            Src := Src + QI(DomainName)
          else begin
            // FieldTypeName handles Firebird 5 scalar and extended numeric types.
            Src := Src + FieldTypeName(Q2);
            if Val(Q2, 'CHARSET_NAME') <> '' then
              Src := Src + ' CHARACTER SET ' + QI(Val(Q2, 'CHARSET_NAME'));
            if Val(Q2, 'COLLATION_NAME') <> '' then
              Src := Src + ' COLLATE ' + QI(Val(Q2, 'COLLATION_NAME'));
          end;
          if Val(Q2, 'NOT_NULL_FLAG') = '1' then Src := Src + ' NOT NULL';
          Def := Val(Q2, 'DEFAULT_SOURCE');
          if Def <> '' then Src := Src + ' ' + Def;
          if not Q2.FieldByName('IDENTITY_TYPE').IsNull then begin
            if Q2.FieldByName('IDENTITY_TYPE').AsInteger = 0 then Src := Src + ' GENERATED ALWAYS AS IDENTITY'
            else Src := Src + ' GENERATED BY DEFAULT AS IDENTITY';
          end;
        end;
        Result.Add('  ' + Src);
        Inc(N); Q2.Next;
      end;
      OpenQuery(Q3, 'SELECT TRIM(RDB$CONSTRAINT_NAME) AS CONSTRAINT_NAME, '+
        'TRIM(RDB$CONSTRAINT_TYPE) AS CONSTRAINT_TYPE, TRIM(RDB$INDEX_NAME) AS INDEX_NAME '+
        'FROM RDB$RELATION_CONSTRAINTS WHERE RDB$RELATION_NAME='+QuotedStr(Name)+
        ' AND RDB$CONSTRAINT_TYPE IN (''PRIMARY KEY'',''UNIQUE'') ORDER BY RDB$CONSTRAINT_TYPE');
      while not Q3.EOF do begin
        OpenQuery(Q2, 'SELECT TRIM(RDB$FIELD_NAME) AS FIELD_NAME FROM RDB$INDEX_SEGMENTS '+
          'WHERE RDB$INDEX_NAME='+QuotedStr(Val(Q3,'INDEX_NAME'))+' ORDER BY RDB$FIELD_POSITION');
        Columns := '';
        while not Q2.EOF do begin
          if Columns<>'' then Columns:=Columns+', ';
          Columns:=Columns+QI(Val(Q2,'FIELD_NAME'));
          Q2.Next;
        end;
        if Columns<>'' then begin
          if N>0 then Result[Result.Count-1]:=Result[Result.Count-1]+',';
          Result.Add('  CONSTRAINT '+QI(Val(Q3,'CONSTRAINT_NAME'))+' '+
            Val(Q3,'CONSTRAINT_TYPE')+' ('+Columns+')');
          Inc(N);
        end;
        Q3.Next;
      end;
      OpenQuery(Q3, 'SELECT TRIM(C.RDB$CONSTRAINT_NAME) AS CONSTRAINT_NAME, '+
        'T.RDB$TRIGGER_SOURCE AS CHECK_SOURCE FROM RDB$RELATION_CONSTRAINTS C '+
        'JOIN RDB$CHECK_CONSTRAINTS K ON K.RDB$CONSTRAINT_NAME=C.RDB$CONSTRAINT_NAME '+
        'JOIN RDB$TRIGGERS T ON T.RDB$TRIGGER_NAME=K.RDB$TRIGGER_NAME '+
        'WHERE C.RDB$RELATION_NAME='+QuotedStr(Name)+
        ' AND C.RDB$CONSTRAINT_TYPE=''CHECK'' ORDER BY C.RDB$CONSTRAINT_NAME');
      while not Q3.EOF do begin
        Def:=Val(Q3,'CHECK_SOURCE');
        if Def<>'' then begin
          AddComma;
          Result.Add('  CONSTRAINT '+QI(Val(Q3,'CONSTRAINT_NAME'))+' '+Def);
          Inc(N);
        end;
        Q3.Next;
      end;

      ConstraintName:=''; Columns:=''; RefColumns:='';
      RefName:=''; UpdateRule:=''; DeleteRule:='';
      OpenQuery(Q3, 'SELECT TRIM(C.RDB$CONSTRAINT_NAME) AS CONSTRAINT_NAME, '+
        'TRIM(S.RDB$FIELD_NAME) AS FIELD_NAME, TRIM(P.RDB$RELATION_NAME) AS REF_TABLE, '+
        'TRIM(PS.RDB$FIELD_NAME) AS REF_FIELD, TRIM(R.RDB$UPDATE_RULE) AS UPDATE_RULE, '+
        'TRIM(R.RDB$DELETE_RULE) AS DELETE_RULE FROM RDB$RELATION_CONSTRAINTS C '+
        'JOIN RDB$REF_CONSTRAINTS R ON R.RDB$CONSTRAINT_NAME=C.RDB$CONSTRAINT_NAME '+
        'JOIN RDB$RELATION_CONSTRAINTS P ON P.RDB$CONSTRAINT_NAME=R.RDB$CONST_NAME_UQ '+
        'JOIN RDB$INDEX_SEGMENTS S ON S.RDB$INDEX_NAME=C.RDB$INDEX_NAME '+
        'JOIN RDB$INDEX_SEGMENTS PS ON PS.RDB$INDEX_NAME=P.RDB$INDEX_NAME '+
        'AND PS.RDB$FIELD_POSITION=S.RDB$FIELD_POSITION WHERE C.RDB$RELATION_NAME='+
        QuotedStr(Name)+' ORDER BY C.RDB$CONSTRAINT_NAME,S.RDB$FIELD_POSITION');
      while not Q3.EOF do begin
        if (ConstraintName<>'') and (ConstraintName<>Val(Q3,'CONSTRAINT_NAME')) then begin
          Def:='  CONSTRAINT '+QI(ConstraintName)+' FOREIGN KEY ('+Columns+') REFERENCES '+
            QI(RefName)+' ('+RefColumns+')';
          if (UpdateRule<>'') and (UpdateRule<>'NO ACTION') then Def:=Def+' ON UPDATE '+UpdateRule;
          if (DeleteRule<>'') and (DeleteRule<>'NO ACTION') then Def:=Def+' ON DELETE '+DeleteRule;
          AddComma; Result.Add(Def); Inc(N); Columns:=''; RefColumns:='';
          ConstraintName:='';
        end;
        if ConstraintName='' then RefName:=Val(Q3,'REF_TABLE');
        ConstraintName:=Val(Q3,'CONSTRAINT_NAME');
        if Columns<>'' then begin Columns:=Columns+', '; RefColumns:=RefColumns+', '; end;
        Columns:=Columns+QI(Val(Q3,'FIELD_NAME'));
        RefColumns:=RefColumns+QI(Val(Q3,'REF_FIELD'));
        UpdateRule:=Val(Q3,'UPDATE_RULE'); DeleteRule:=Val(Q3,'DELETE_RULE');
        Q3.Next;
      end;
      if ConstraintName<>'' then begin
        Def:='  CONSTRAINT '+QI(ConstraintName)+' FOREIGN KEY ('+Columns+') REFERENCES '+
          QI(RefName)+' ('+RefColumns+')';
        if (UpdateRule<>'') and (UpdateRule<>'NO ACTION') then Def:=Def+' ON UPDATE '+UpdateRule;
        if (DeleteRule<>'') and (DeleteRule<>'NO ACTION') then Def:=Def+' ON DELETE '+DeleteRule;
        AddComma; Result.Add(Def); Inc(N);
      end;
      Result.Add(');'); Result.Add('');
      Q.Next;
    end;

    OpenQuery(Q, 'SELECT TRIM(RDB$RELATION_NAME) AS OBJECT_NAME, RDB$VIEW_SOURCE AS SOURCE_SQL '+
      'FROM RDB$RELATIONS WHERE RDB$VIEW_BLR IS NOT NULL AND COALESCE(RDB$SYSTEM_FLAG,0)=0 '+
      'ORDER BY RDB$RELATION_NAME');
    if not Q.EOF then Result.Add('-- ビュー');
    while not Q.EOF do begin
      Src := Val(Q, 'SOURCE_SQL');
      if Src <> '' then begin
        Result.Add('CREATE VIEW ' + QI(Val(Q, 'OBJECT_NAME')) + ' AS');
        Result.Add(Src + ';'); Result.Add('');
      end;
      Q.Next;
    end;

    OpenQuery(Q, 'SELECT TRIM(I.RDB$INDEX_NAME) AS OBJECT_NAME, '+
      'TRIM(I.RDB$RELATION_NAME) AS RELATION_NAME, I.RDB$UNIQUE_FLAG AS UNIQUE_FLAG, '+
      'I.RDB$INDEX_TYPE AS INDEX_TYPE, I.RDB$EXPRESSION_SOURCE AS EXPRESSION_SOURCE '+
      'FROM RDB$INDICES I WHERE I.RDB$CONSTRAINT_NAME IS NULL '+
      'AND COALESCE(I.RDB$SYSTEM_FLAG,0)=0 ORDER BY I.RDB$INDEX_NAME');
    if not Q.EOF then Result.Add('-- インデックス');
    while not Q.EOF do begin
      Name:=Val(Q,'OBJECT_NAME');
      Columns:='';
      if Val(Q,'EXPRESSION_SOURCE')<>'' then
        Columns:='COMPUTED BY ('+Val(Q,'EXPRESSION_SOURCE')+')'
      else begin
        OpenQuery(Q2,'SELECT TRIM(RDB$FIELD_NAME) AS FIELD_NAME FROM RDB$INDEX_SEGMENTS '+
          'WHERE RDB$INDEX_NAME='+QuotedStr(Name)+' ORDER BY RDB$FIELD_POSITION');
        while not Q2.EOF do begin
          if Columns<>'' then Columns:=Columns+', ';
          Columns:=Columns+QI(Val(Q2,'FIELD_NAME'));
          Q2.Next;
        end;
        Q2.Close;
      end;
      if Columns<>'' then begin
        Def:='CREATE ';
        if Val(Q,'UNIQUE_FLAG')='1' then Def:=Def+'UNIQUE ';
        if Val(Q,'INDEX_TYPE')='1' then Def:=Def+'DESCENDING ';
        Def:=Def+'INDEX '+QI(Name)+' ON '+QI(Val(Q,'RELATION_NAME'))+' ';
        if Pos('COMPUTED BY ',UpperCase(Columns))=1 then Def:=Def+Columns
        else Def:=Def+'('+Columns+')';
        Def:=Def+';';
        Result.Add(Def);
      end;
      Q.Next;
    end;
    if Result.Count>1 then Result.Add('');

    OpenQuery(Q, 'SELECT TRIM(RDB$GENERATOR_NAME) AS OBJECT_NAME FROM RDB$GENERATORS '+
      'WHERE COALESCE(RDB$SYSTEM_FLAG,0)=0 ORDER BY RDB$GENERATOR_NAME');
    if not Q.EOF then Result.Add('-- シーケンス（現在値は含みません）');
    while not Q.EOF do begin Result.Add('CREATE SEQUENCE '+QI(Val(Q,'OBJECT_NAME'))+';'); Q.Next; end;
    if Result.Count > 1 then Result.Add('');

    OpenQuery(Q, 'SELECT TRIM(RDB$EXCEPTION_NAME) AS OBJECT_NAME, RDB$MESSAGE AS MESSAGE '+
      'FROM RDB$EXCEPTIONS WHERE COALESCE(RDB$SYSTEM_FLAG,0)=0 ORDER BY RDB$EXCEPTION_NAME');
    if not Q.EOF then Result.Add('-- 例外');
    while not Q.EOF do begin
      Result.Add('CREATE EXCEPTION '+QI(Val(Q,'OBJECT_NAME'))+' '+QuotedStr(Val(Q,'MESSAGE'))+';'); Q.Next;
    end;
    if Result.Count > 1 then Result.Add('');

    AddSourceSection(Result,Q,'プロシージャ',
      'SELECT TRIM(RDB$PROCEDURE_NAME) AS OBJECT_NAME, RDB$PROCEDURE_SOURCE AS SOURCE_SQL '+
      'FROM RDB$PROCEDURES WHERE COALESCE(RDB$SYSTEM_FLAG,0)=0 ORDER BY RDB$PROCEDURE_NAME');
    AddSourceSection(Result,Q,'トリガー',
      'SELECT TRIM(RDB$TRIGGER_NAME) AS OBJECT_NAME, RDB$TRIGGER_SOURCE AS SOURCE_SQL '+
      'FROM RDB$TRIGGERS WHERE COALESCE(RDB$SYSTEM_FLAG,0)=0 ORDER BY RDB$TRIGGER_NAME');
    AddSourceSection(Result,Q,'パッケージ（ソース）',
      'SELECT TRIM(RDB$PACKAGE_NAME) AS OBJECT_NAME, RDB$PACKAGE_HEADER_SOURCE AS SOURCE_SQL '+
      'FROM RDB$PACKAGES WHERE COALESCE(RDB$SYSTEM_FLAG,0)=0 ORDER BY RDB$PACKAGE_NAME');
    AddSourceSection(Result,Q,'パッケージ本体（ソース）',
      'SELECT TRIM(RDB$PACKAGE_NAME) AS OBJECT_NAME, RDB$PACKAGE_BODY_SOURCE AS SOURCE_SQL '+
      'FROM RDB$PACKAGES WHERE COALESCE(RDB$SYSTEM_FLAG,0)=0 ORDER BY RDB$PACKAGE_NAME');
    AddSourceSection(Result,Q,'関数（外部関数はコメント表示）',
      'SELECT TRIM(RDB$FUNCTION_NAME) AS OBJECT_NAME, RDB$FUNCTION_SOURCE AS SOURCE_SQL '+
      'FROM RDB$FUNCTIONS WHERE COALESCE(RDB$SYSTEM_FLAG,0)=0 ORDER BY RDB$FUNCTION_NAME');

    OpenQuery(Q, 'SELECT TRIM(RDB$USER) AS GRANTEE, TRIM(RDB$RELATION_NAME) AS OBJECT_NAME, '+
      'RDB$PRIVILEGE AS PRIVILEGE_CODE, RDB$GRANT_OPTION AS GRANT_OPTION '+
      'FROM RDB$USER_PRIVILEGES WHERE RDB$RELATION_NAME IS NOT NULL '+
      'ORDER BY RDB$RELATION_NAME,RDB$USER,RDB$PRIVILEGE');
    if not Q.EOF then Result.Add('-- オブジェクト権限（ユーザー／ロール名を確認してください）');
    while not Q.EOF do begin
      case Val(Q,'PRIVILEGE_CODE') of
        'S': Kind:='SELECT'; 'I': Kind:='INSERT'; 'U': Kind:='UPDATE';
        'D': Kind:='DELETE'; 'R': Kind:='REFERENCES'; 'X': Kind:='EXECUTE';
        else Kind:='';
      end;
      if Kind<>'' then begin
        Def:='GRANT '+Kind+' ON '+QI(Val(Q,'OBJECT_NAME'))+' TO '+QI(Val(Q,'GRANTEE'));
        if Q.FieldByName('GRANT_OPTION').AsInteger<>0 then Def:=Def+' WITH GRANT OPTION';
        Result.Add(Def+';');
      end;
      Q.Next;
    end;
    Result.Add('');
    Result.Add('-- 注意: この表示は作成補助用です。Firebird 5の全メタデータ（照合順序、');
    Result.Add('-- UDF引数、ルーチン引数定義、パッケージ内ルーチンの宣言、トリガー属性など）を完全再現する');
    Result.Add('-- バックアップ形式ではありません。実行前に内容を確認してください。');
  finally
    Q3.Free; Q2.Free; Q.Free;
  end;
end;

end.
