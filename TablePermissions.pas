unit TablePermissions;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes,SysUtils,Controls,Forms,Graphics,Grids,ComCtrls,SQLDB,IBConnection;
type
  TPermissionCell=record
    Granted,GrantOption,ColumnOnly,WholeTableGrantOption:Boolean;
    Detail:string;
  end;
  TPermissionRow=record
    Principal:string;
    PrincipalType:Integer;
    Rights:array[1..7] of TPermissionCell;
  end;
  TPermissionMatrix=class(TStringGrid)
  private
    FRows:array of TPermissionRow;
    FImages:TImageList;
    FReady:Boolean;
    function FindPrincipal(const Principal:string;Kind:Integer):Integer;
    procedure LoadPermissions(Connection:TIBConnection;Transaction:TSQLTransaction;const TableName:string);
    procedure FitColumns;
  protected
    procedure DrawCell(ACol,ARow:Integer;ARect:TRect;AState:TGridDrawState);override;
    procedure Resize;override;
    function GetCellHintText(ACol,ARow:Integer):string;override;
  public
    constructor CreateMatrix(AOwner:TComponent;Connection:TIBConnection;
      Transaction:TSQLTransaction;const TableName:string);
  end;
procedure CreatePermissionView(AOwner:TComponent;ParentControl:TWinControl;
  Connection:TIBConnection;Transaction:TSQLTransaction;const TableName:string);
implementation
uses Math,Types,ExtCtrls,StdCtrls,ConsoleImages;

function TPermissionMatrix.FindPrincipal(const Principal:string;Kind:Integer):Integer;
var I:Integer;
begin
  for I:=0 to High(FRows) do
    if (FRows[I].Principal=Principal)and(FRows[I].PrincipalType=Kind) then Exit(I);
  Result:=-1;
end;

constructor TPermissionMatrix.CreateMatrix(AOwner:TComponent;Connection:TIBConnection;
  Transaction:TSQLTransaction;const TableName:string);
const Titles:array[0..7] of string=('Object','Select','Delete','Insert','Update','Reference','Execute','Member Of');
var I:Integer;
begin
  inherited Create(AOwner);
  Name:='PermissionMatrix';
  Align:=alClient;BorderStyle:=bsNone;BorderSpacing.Around:=6;
  ColCount:=8;FixedCols:=0;FixedRows:=1;RowCount:=2;
  DefaultDrawing:=False;DefaultRowHeight:=28;
  Options:=[goColSizing,goRowSelect,goThumbTracking,goCellHints];
  ShowHint:=True;CellHintPriority:=chpAll;
  FImages:=CreateConsoleImages(Self,16);
  for I:=0 to 7 do Cells[I,0]:=Titles[I];
  LoadPermissions(Connection,Transaction,TableName);
  FReady:=True;FitColumns;
end;

procedure TPermissionMatrix.LoadPermissions(Connection:TIBConnection;
  Transaction:TSQLTransaction;const TableName:string);
var Q:TSQLQuery;I,C,J,Kind,GrantValue:Integer;Principal,Privilege,FieldName,Grantor,Detail,RoleName,DetailText:string;
    Memberships:TStringList;
  procedure AddRight(Column:Integer);
  begin
    with FRows[I].Rights[Column] do begin
      Granted:=True;
      if FieldName='' then ColumnOnly:=False;
      if GrantValue<>0 then begin GrantOption:=True;if FieldName='' then WholeTableGrantOption:=True;end;
      if Detail<>'' then Detail:=Detail+LineEnding;
      // The cell hint preserves the scope and grantor of each underlying grant.
      FRows[I].Rights[Column].Detail:=FRows[I].Rights[Column].Detail+
        UTF8Encode('付与者: ')+Grantor+' / '+DetailText;
    end;
  end;
begin
  Q:=TSQLQuery.Create(nil);
  try
    Q.Database:=Connection;Q.Transaction:=Transaction;
    Q.SQL.Text:='SELECT TRIM(RDB$USER) AS GRANTEE,RDB$USER_TYPE AS GRANTEE_TYPE,'+
      'TRIM(RDB$PRIVILEGE) AS PRIVILEGE_CODE,COALESCE(RDB$GRANT_OPTION,0) AS GRANT_OPTION,'+
      'TRIM(RDB$GRANTOR) AS GRANTOR,TRIM(RDB$FIELD_NAME) AS COLUMN_NAME '+
      'FROM RDB$USER_PRIVILEGES WHERE RDB$RELATION_NAME=:ObjectName '+
      'AND RDB$OBJECT_TYPE IN (0,1) ORDER BY RDB$USER,RDB$USER_TYPE,RDB$PRIVILEGE,RDB$FIELD_NAME';
    Q.Params.ParamByName('ObjectName').AsString:=TableName;Q.Open;
    while not Q.EOF do begin
      Principal:=Q.FieldByName('GRANTEE').AsString;Kind:=Q.FieldByName('GRANTEE_TYPE').AsInteger;
      Privilege:=Q.FieldByName('PRIVILEGE_CODE').AsString;
      I:=FindPrincipal(Principal,Kind);
      if I<0 then begin
        I:=Length(FRows);SetLength(FRows,I+1);
        FRows[I].Principal:=Principal;FRows[I].PrincipalType:=Kind;
        for C:=1 to 7 do FRows[I].Rights[C].ColumnOnly:=True;
      end;
      GrantValue:=Q.FieldByName('GRANT_OPTION').AsInteger;
      FieldName:=Q.FieldByName('COLUMN_NAME').AsString;Grantor:=Q.FieldByName('GRANTOR').AsString;
      if FieldName='' then DetailText:='テーブル全体' else DetailText:=UTF8Encode('カラム: ')+FieldName;
      if GrantValue<>0 then DetailText:=DetailText+' / WITH GRANT OPTION';
      if Privilege='A' then for C:=1 to 5 do AddRight(C)
      else begin
        C:=Pos(Privilege,'SDIURX');
        if (C>0)and(Length(Privilege)=1) then AddRight(C);
      end;
      Q.Next;
    end;
    Q.Close;
    // Direct memberships are shown separately; inherited table privileges are not fabricated.
    Q.SQL.Text:='SELECT TRIM(P.RDB$USER) AS GRANTEE,P.RDB$USER_TYPE AS GRANTEE_TYPE,'+
      'TRIM(P.RDB$RELATION_NAME) AS ROLE_NAME,COALESCE(P.RDB$GRANT_OPTION,0) AS GRANT_OPTION '+
      'FROM RDB$USER_PRIVILEGES P WHERE P.RDB$PRIVILEGE=''M'' AND EXISTS '+
      '(SELECT 1 FROM RDB$USER_PRIVILEGES T WHERE T.RDB$RELATION_NAME=:ObjectName '+
      'AND T.RDB$OBJECT_TYPE IN (0,1) AND T.RDB$USER=P.RDB$USER AND T.RDB$USER_TYPE=P.RDB$USER_TYPE) '+
      'ORDER BY P.RDB$USER,P.RDB$USER_TYPE,P.RDB$RELATION_NAME';
    Q.Params.ParamByName('ObjectName').AsString:=TableName;Q.Open;
    while not Q.EOF do begin
      I:=FindPrincipal(Q.FieldByName('GRANTEE').AsString,Q.FieldByName('GRANTEE_TYPE').AsInteger);
      if I>=0 then begin
        RoleName:=Q.FieldByName('ROLE_NAME').AsString;
        with FRows[I].Rights[7] do begin
          Granted:=True;
          if Q.FieldByName('GRANT_OPTION').AsInteger<>0 then GrantOption:=True;
          if Detail<>'' then Detail:=Detail+LineEnding;
          Detail:=Detail+RoleName;
          if Q.FieldByName('GRANT_OPTION').AsInteger<>0 then Detail:=Detail+' / WITH ADMIN OPTION';
        end;
      end;
      Q.Next;
    end;
    RowCount:=Max(2,Length(FRows)+1);
    for I:=0 to High(FRows) do begin
      Cells[0,I+1]:=FRows[I].Principal;
      if FRows[I].PrincipalType=13 then Cells[0,I+1]:=Cells[0,I+1]+' [Role]';
      for C:=1 to 6 do if FRows[I].Rights[C].Granted then begin
        Cells[C,I+1]:='Y';
        if FRows[I].Rights[C].ColumnOnly or
          (FRows[I].Rights[C].GrantOption and not FRows[I].Rights[C].WholeTableGrantOption) then Cells[C,I+1]:='Y*';
      end;
      if FRows[I].Rights[7].Granted then begin
        Detail:=StringReplace(FRows[I].Rights[7].Detail,' / WITH ADMIN OPTION','',[rfReplaceAll]);
        Memberships:=TStringList.Create;
        try
          Memberships.Sorted:=True;Memberships.Duplicates:=dupIgnore;Memberships.CaseSensitive:=True;
          with TStringList.Create do try Text:=Detail;for J:=0 to Count-1 do Memberships.Add(Strings[J]);finally Free;end;
          Detail:='';for J:=0 to Memberships.Count-1 do begin if J>0 then Detail:=Detail+', ';Detail:=Detail+Memberships[J];end;
          Cells[7,I+1]:=Detail;
        finally Memberships.Free;end;
      end;
    end;
    if Length(FRows)=0 then Cells[0,1]:='権限の明示的な付与はありません';
  finally Q.Free;end;
end;

procedure TPermissionMatrix.FitColumns;
var Available,I:Integer;
begin
  if not FReady or (Parent=nil) or (csDestroying in ComponentState) then Exit;
  Canvas.Font.Assign(Font);
  DefaultRowHeight:=Max(Scale96ToFont(28),Canvas.TextHeight('Ag')+Scale96ToFont(12));
  RowHeights[0]:=DefaultRowHeight+Scale96ToFont(4);
  ColWidths[0]:=Scale96ToFont(220);ColWidths[7]:=Scale96ToFont(150);
  Available:=ClientWidth-ColWidths[0]-ColWidths[7]-Scale96ToFont(18);
  for I:=1 to 6 do ColWidths[I]:=Max(Scale96ToFont(76),Available div 6);
end;

procedure TPermissionMatrix.Resize;
begin
  inherited Resize;FitColumns;
end;

function TPermissionMatrix.GetCellHintText(ACol,ARow:Integer):string;
begin
  Result:='';
  if (ARow<1)or(ARow>Length(FRows)) then Exit;
  if ACol=0 then begin
    Result:=FRows[ARow-1].Principal+UTF8Encode(' / 種類: ')+IntToStr(FRows[ARow-1].PrincipalType);Exit;
  end;
  if (ACol<1)or(ACol>7) then Exit;
  Result:=FRows[ARow-1].Rights[ACol].Detail;
end;

procedure TPermissionMatrix.DrawCell(ACol,ARow:Integer;ARect:TRect;AState:TGridDrawState);
var Style:TTextStyle;Icon:Integer;
begin
  Canvas.Font.Assign(Font);Canvas.Font.Color:=RGBToColor(40,49,62);
  if ARow=0 then begin Canvas.Brush.Color:=RGBToColor(232,237,245);Canvas.Font.Style:=[fsBold];end
  else if gdSelected in AState then Canvas.Brush.Color:=RGBToColor(220,234,252)
  else if Odd(ARow) then Canvas.Brush.Color:=clWhite
  else Canvas.Brush.Color:=RGBToColor(247,249,253);
  Canvas.FillRect(ARect);Canvas.Pen.Color:=RGBToColor(229,234,241);
  Canvas.Line(ARect.Left,ARect.Bottom-1,ARect.Right,ARect.Bottom-1);
  Canvas.Line(ARect.Right-1,ARect.Top,ARect.Right-1,ARect.Bottom);
  if (ARow>0)and(ARow<=Length(FRows)) then begin
    if ACol=0 then begin
      case FRows[ARow-1].PrincipalType of
        1:Icon:=icView;2:Icon:=icTrigger;5:Icon:=icProcedure;13:Icon:=icRole;
        else Icon:=icUsers;
      end;
      FImages.Draw(Canvas,ARect.Left+6,ARect.Top+(ARect.Bottom-ARect.Top-16)div 2,Icon);
      Inc(ARect.Left,24);
    end else if FRows[ARow-1].Rights[ACol].GrantOption then
      FImages.Draw(Canvas,ARect.Left+4,ARect.Top+(ARect.Bottom-ARect.Top-16)div 2,icIndex);
  end;
  Style:=Canvas.TextStyle;Style.Layout:=tlCenter;Style.SingleLine:=True;Style.Clipping:=True;Style.EndEllipsis:=True;
  if ACol in [0,7] then begin Style.Alignment:=taLeftJustify;Inc(ARect.Left,8);end
  else Style.Alignment:=taCenter;
  if (ACol=7)and(ARow>0)and(ARow<=Length(FRows))and FRows[ARow-1].Rights[7].GrantOption then Inc(ARect.Left,16);
  Dec(ARect.Right,6);
  Canvas.TextRect(ARect,ARect.Left,ARect.Top,Cells[ACol,ARow],Style);
end;

procedure CreatePermissionView(AOwner:TComponent;ParentControl:TWinControl;
  Connection:TIBConnection;Transaction:TSQLTransaction;const TableName:string);
var Matrix:TPermissionMatrix;Legend:TPanel;Image:TImage;LabelControl:TLabel;
begin
  Matrix:=TPermissionMatrix.CreateMatrix(AOwner,Connection,Transaction,TableName);Matrix.Parent:=ParentControl;
  Legend:=TPanel.Create(AOwner);Legend.Parent:=ParentControl;Legend.Align:=alBottom;Legend.Height:=52;Legend.BevelOuter:=bvNone;
  Image:=TImage.Create(AOwner);Image.Parent:=Legend;Image.SetBounds(12,9,16,16);
  Matrix.FImages.GetBitmap(icIndex,Image.Picture.Bitmap);
  LabelControl:=TLabel.Create(AOwner);LabelControl.Parent:=Legend;LabelControl.SetBounds(36,9,700,18);
  LabelControl.Caption:='鍵印：GRANT OPTION付き（再付与可能）／ Member Ofの鍵印：ADMIN OPTION付き';
  LabelControl:=TLabel.Create(AOwner);LabelControl.Parent:=Legend;LabelControl.SetBounds(12,30,700,18);
  LabelControl.Caption:='Y：付与あり　 Y*：権限または再付与の範囲にカラム指定あり（詳細はセルのヒントで確認できます）';
end;
end.
