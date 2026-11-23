unit InspectorWindow;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes,SysUtils,Forms,Controls,Grids,ComCtrls,DB,SQLDB,IBConnection;
procedure ShowQuerySnapshot(AOwner:TComponent;Connection:TIBConnection;const Title,SQL:string);
implementation
uses AppTheme;
type TSnapshotForm=class(TForm)
  procedure Closed(Sender:TObject;var CloseAction:TCloseAction);
end;
procedure TSnapshotForm.Closed(Sender:TObject;var CloseAction:TCloseAction);
begin CloseAction:=caFree;end;
procedure ShowQuerySnapshot(AOwner:TComponent;Connection:TIBConnection;const Title,SQL:string);
var D:TSnapshotForm;G:TStringGrid;Status:TStatusBar;Q:TSQLQuery;T:TSQLTransaction;R,C:Integer;
begin
  D:=TSnapshotForm.CreateNew(AOwner);Q:=TSQLQuery.Create(nil);T:=TSQLTransaction.Create(nil);
  try
   try
    D.OnClose:=@D.Closed;
    D.Caption:=Title;D.SetBounds(120,120,950,580);D.Position:=poOwnerFormCenter;
    Status:=TStatusBar.Create(D);Status.Parent:=D;Status.SimplePanel:=True;Status.SimpleText:=Connection.DatabaseName;
    G:=TStringGrid.Create(D);G.Parent:=D;G.Align:=alClient;G.FixedCols:=0;G.RowCount:=2;G.DefaultColWidth:=180;
    G.Options:=G.Options+[goColSizing,goRowSelect];
    T.Database:=Connection;Q.Database:=Connection;Q.Transaction:=T;Q.SQL.Text:=SQL;Q.Open;
    G.ColCount:=Q.FieldCount;
    for C:=0 to Q.FieldCount-1 do G.Cells[C,0]:=Q.Fields[C].FieldName;
    R:=1;
    while not Q.EOF do begin
      G.RowCount:=R+1;
      for C:=0 to Q.FieldCount-1 do if Q.Fields[C].IsNull then G.Cells[C,R]:='<NULL>' else G.Cells[C,R]:=Q.Fields[C].AsString;
      Q.Next;Inc(R);
    end;
    Q.Close;T.Rollback;
    ApplyModernTheme(D);
    D.Show;
   except D.Free;raise;end;
  finally Q.Free;if T.Active then T.Rollback;T.Free;end;
end;
end.
