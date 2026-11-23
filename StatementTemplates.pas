unit StatementTemplates;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes,SysUtils,TableMetadata;
type
  TStatementColumn=record
    Name:string;
    Writable:Boolean;
  end;
  TStatementColumns=array of TStatementColumn;
  TStatementTexts=array[0..3] of string;
function BuildStatements(const TableName:string;const Columns:TStatementColumns;
  Keys:TStrings;IsView:Boolean):TStatementTexts;
implementation
function BuildStatements(const TableName:string;const Columns:TStatementColumns;
  Keys:TStrings;IsView:Boolean):TStatementTexts;
var I,N:Integer;TableSQL,Fields,Values,Assignments,Conditions,Ordering:string;
begin
  TableSQL:=QuoteName(TableName);
  Result[0]:='select';
  for I:=0 to High(Columns) do begin
    if I=0 then Result[0]:=Result[0]+' '+TableSQL+'.'+QuoteName(Columns[I].Name)
    else Result[0]:=Result[0]+LineEnding+'      ,'+TableSQL+'.'+QuoteName(Columns[I].Name);
  end;
  Result[0]:=Result[0]+LineEnding+'from '+TableSQL;
  Ordering:='';Conditions:='';
  for I:=0 to Keys.Count-1 do begin
    if I>0 then begin Ordering:=Ordering+','+LineEnding;Conditions:=Conditions+LineEnding+'  and ';end;
    Ordering:=Ordering+TableSQL+'.'+QuoteName(Keys[I]);
    Conditions:=Conditions+QuoteName(Keys[I])+' = :OLD_K'+IntToStr(I+1);
  end;
  if Ordering<>'' then Result[0]:=Result[0]+LineEnding+'order by'+LineEnding+Ordering;
  Result[0]:=Result[0]+';';
  if IsView then begin
    for I:=1 to 3 do Result[I]:='-- ビューの更新用SQLは自動生成しません。対話型SQLで指定してください。';
    Exit;
  end;
  Fields:='';Values:='';Assignments:='';N:=0;
  for I:=0 to High(Columns) do if Columns[I].Writable then begin
    if N>0 then begin Fields:=Fields+','+LineEnding+'  ';Values:=Values+','+LineEnding+'  ';Assignments:=Assignments+','+LineEnding+'    ';end;
    Fields:=Fields+QuoteName(Columns[I].Name);
    Values:=Values+':P'+IntToStr(I+1);
    Assignments:=Assignments+QuoteName(Columns[I].Name)+' = :P'+IntToStr(I+1);
    Inc(N);
  end;
  if N=0 then Result[1]:='insert into '+TableSQL+' default values;'
  else Result[1]:='insert into '+TableSQL+LineEnding+'  ('+Fields+')'+LineEnding+'values'+LineEnding+'  ('+Values+');';
  if Keys.Count=0 then begin
    Result[2]:='-- 主キーがないため、更新用SQLは自動生成しません。';
    Result[3]:='-- 主キーがないため、削除用SQLは自動生成しません。';
    Exit;
  end;
  if N=0 then Result[2]:='-- 更新可能な列がありません。'
  else Result[2]:='update '+TableSQL+LineEnding+'set '+Assignments+LineEnding+'where '+Conditions+';';
  Result[3]:='delete from '+TableSQL+LineEnding+'where '+Conditions+';';
end;
end.
