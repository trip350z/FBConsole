program StatementTemplatesTest;
{$mode objfpc}{$H+}
uses Classes,SysUtils,StatementTemplates;
var Columns:TStatementColumns;Keys:TStringList;SQL:TStatementTexts;
procedure Check(Condition:Boolean;const Description:string);
begin
  if not Condition then raise Exception.Create('FAIL: '+Description);
  WriteLn('PASS: ',Description);
end;
begin
  Keys:=TStringList.Create;
  try
    SetLength(Columns,4);
    Columns[0].Name:='WORK_DATE';Columns[0].Writable:=True;
    Columns[1].Name:='UID';Columns[1].Writable:=True;
    Columns[2].Name:='AUTO_ID';Columns[2].Writable:=False;
    Columns[3].Name:='TOTAL';Columns[3].Writable:=False;
    Keys.Add('WORK_DATE');Keys.Add('UID');
    SQL:=BuildStatements('TIMECARD',Columns,Keys,False);
    Check(Pos('"TIMECARD"."WORK_DATE"',SQL[0])>0,'qualified SELECT columns');
    Check(Pos('order by'+LineEnding+'"TIMECARD"."WORK_DATE",'+LineEnding+'"TIMECARD"."UID";',SQL[0])>0,'composite primary key ordering');
    Check((Pos('AUTO_ID',SQL[1])=0) and (Pos('TOTAL',SQL[1])=0),'generated columns excluded from INSERT');
    Check((Pos(':P1',SQL[1])>0) and (Pos(':P2',SQL[1])>0),'parameterized INSERT');
    Check((Pos('where "WORK_DATE" = :OLD_K1',SQL[2])>0) and (Pos('and "UID" = :OLD_K2',SQL[2])>0),'UPDATE restricts both key columns');
    Check((Pos('where "WORK_DATE" = :OLD_K1',SQL[3])>0) and (Pos('and "UID" = :OLD_K2',SQL[3])>0),'DELETE restricts both key columns');
    Keys.Clear;
    SQL:=BuildStatements('TIMECARD',Columns,Keys,False);
    Check((Copy(SQL[2],1,2)='--') and (Copy(SQL[3],1,2)='--'),'no unsafe UPDATE/DELETE for tables without primary keys');
    SQL:=BuildStatements('A"B',Columns,Keys,True);
    Check(Pos('"A""B"',SQL[0])>0,'quoted identifiers escaped');
    Check((Copy(SQL[1],1,2)='--') and (Copy(SQL[2],1,2)='--') and (Copy(SQL[3],1,2)='--'),'views have no generated DML');
  finally Keys.Free;end;
end.
