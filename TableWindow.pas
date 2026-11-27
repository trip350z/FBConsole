unit TableWindow;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, Grids, Graphics, Buttons,
  DBGrids, DBCtrls, DB, SQLDB, IBConnection, Dialogs, TableMetadata,
  SynEdit, SynHighlighterSQL, StatementTemplates, ConsoleImages, BlobViewer;
type
  TTableWindow = class(TForm)
  private
    FConnection: TIBConnection;
    FMetaTransaction, FDataTransaction: TSQLTransaction;
    FData: TSQLQuery;
    FSource: TDataSource;
    FPages, FProperties: TPageControl;
    FGrid: TDBGrid;
    FColumns: TListView;
    FNavigator: TDBNavigator;
    FFilter: TEdit;
    FStatus: TStatusBar;
    FTable: string;
    FIsView, FCanEdit, FLoading: Boolean;
    FMetadata: TMemo;
    FStatements:TSynEdit;
    FStatementTabs:TTabControl;
    FStatementTexts:TStatementTexts;
    FApply, FDiscard: TBitBtn;
    FImages:TImageList;
    FRowImages:TImageList;
    FLayoutBusy:Boolean;
    function Tab(Pages: TPageControl; const Title: string): TTabSheet;
    function Grid(ParentControl: TWinControl): TStringGrid;
    procedure AddButton(ParentControl: TWinControl; const Title: string; X, W: Integer; Handler: TNotifyEvent);
    procedure LoadGrid(G: TStringGrid; const SQL: string);
    procedure LoadMetadata;
    procedure LayoutMetadata(Sender: TObject);
    procedure ColumnHint(Sender: TObject; Shift: TShiftState; X,Y: Integer);
    procedure DrawMetadataCell(Sender: TObject; ACol, ARow: Integer;
      ARect: TRect; AState: TGridDrawState);
    procedure DrawColumnRow(Sender: TCustomListView; Item: TListItem;
      State: TCustomDrawState; var DefaultDraw: Boolean);
    procedure StatementChanged(Sender:TObject);
    procedure OpenData;
    procedure RefreshClick(Sender: TObject);
    procedure ApplyClick(Sender: TObject);
    procedure DiscardClick(Sender: TObject);
    procedure StateChanged(Sender: TObject);
    procedure CheckClose(Sender: TObject; var CanClose: Boolean);
    procedure CloseClick(Sender:TObject);
    procedure ExportClick(Sender: TObject);
    procedure SaveMetadata(Sender: TObject);
    procedure RecordForm(Sender: TObject);
    procedure GridDblClick(Sender:TObject);
    procedure CopyRecord(Sender: TObject);
    procedure PagesChanged(Sender: TObject);
    function Pending: Boolean;
  public
    constructor CreateTable(AOwner: TComponent; Connection: TIBConnection;
      const TableName: string; IsView: Boolean);
    destructor Destroy; override;
    function PrepareClose: Boolean;
    procedure SelectData;
    procedure SelectStatement(Index:Integer);
    procedure RunSelfTest;
    procedure RunCompositeSelfTest;
  end;
implementation

uses Math, Types, AppTheme, TablePermissions;

function TTableWindow.Tab(Pages: TPageControl; const Title: string): TTabSheet;
begin
  Result:=TTabSheet.Create(Self);
  Result.PageControl:=Pages;
  Result.Caption:=Title;
  if Assigned(Pages.Images) then Result.ImageIndex:=IconForCaption(Title);
end;
function TTableWindow.Grid(ParentControl: TWinControl): TStringGrid;
begin
  Result:=TStringGrid.Create(Self);
  Result.Parent:=ParentControl;
  Result.Align:=alClient;
  Result.BorderSpacing.Around:=6;
  Result.FixedCols:=0;
  Result.RowCount:=2;
  Result.ColCount:=1;
  Result.DefaultColWidth:=160;
  Result.BorderStyle:=bsNone;
  Result.DefaultRowHeight:=28;
  Result.DefaultDrawing:=False;
  Result.Options:=[goColSizing,goRowSelect,goThumbTracking,goCellHints];
  Result.ShowHint:=True;
  Result.CellHintPriority:=chpTruncOnly;
  Result.OnDrawCell:=@DrawMetadataCell;
  Result.OnResize:=@LayoutMetadata;
end;
procedure TTableWindow.AddButton(ParentControl: TWinControl; const Title: string; X,W: Integer; Handler: TNotifyEvent);
var B:TBitBtn;
begin
  B:=TBitBtn.Create(Self); B.Parent:=ParentControl;
  B.SetBounds(X,4,W,28); B.Caption:=Title; B.OnClick:=Handler;
  FImages.GetBitmap(IconForCaption(Title),B.Glyph);
end;
constructor TTableWindow.CreateTable(AOwner: TComponent; Connection: TIBConnection;
  const TableName: string; IsView: Boolean);
var T,PropertyTab:TTabSheet; Bar:TPanel; Split:TSplitter; K:Integer; RowBitmap:TBitmap;
const Names:array[1..5] of string=('インデックス','ユニーク制約','チェック制約','参照制約','トリガー');
  procedure AddDivider(AParent:TWinControl;X:Integer);
  var V:TBevel;
  begin
    V:=TBevel.Create(Self);V.Parent:=AParent;V.Shape:=bsLeftLine;
    V.SetBounds(X,5,2,26);
  end;
begin
  inherited CreateNew(AOwner);
  FConnection:=Connection; FTable:=TableName; FIsView:=IsView;
  FImages:=CreateConsoleImages(Self);
  Caption:=UTF8Encode('テーブル - ')+TableName;
  if IsView then Caption:=UTF8Encode('ビュー - ')+TableName;
  SetBounds(100,100,1000,680); Position:=poOwnerFormCenter;
  Constraints.MinWidth:=850; Constraints.MinHeight:=500;
  OnCloseQuery:=@CheckClose;
  with TButton.Create(Self) do begin
    Parent:=Self;
    Align:=alBottom;
    Caption:='閉じる';
    OnClick:=@CloseClick;
  end;
  FMetaTransaction:=TSQLTransaction.Create(Self); FMetaTransaction.Database:=Connection;
  FDataTransaction:=TSQLTransaction.Create(Self); FDataTransaction.Database:=Connection;
  FData:=TSQLQuery.Create(Self); FData.Database:=Connection; FData.Transaction:=FDataTransaction;
  FData.UsePrimaryKeyAsKey:=True; FData.UpdateMode:=upWhereAll;
  FData.Options:=FData.Options+[sqoRefreshUsingSelect];
  FSource:=TDataSource.Create(Self); FSource.DataSet:=FData;
  FSource.OnStateChange:=@StateChanged;
  FStatus:=TStatusBar.Create(Self); FStatus.Parent:=Self; FStatus.SimplePanel:=True;
  FStatus.SimpleText:=Connection.DatabaseName;
  FPages:=TPageControl.Create(Self); FPages.Parent:=Self; FPages.Align:=alClient;
  FPages.BorderSpacing.Around:=6;
  PropertyTab:=Tab(FPages,'プロパティ');
  FProperties:=TPageControl.Create(Self); FProperties.Parent:=PropertyTab; FProperties.Align:=alClient;
  FProperties.Style:=tsTabs;
  FProperties.MultiLine:=True;
  FProperties.TabHeight:=Scale96ToFont(34);
  FProperties.TabWidth:=Scale96ToFont(128);
  FProperties.BorderSpacing.Around:=8;
  FProperties.Images:=CreateConsoleImages(Self,16);
  FColumns:=TListView.Create(Self);
  FColumns.Parent:=Tab(FProperties,'カラム');
  FColumns.BorderSpacing.Around:=6;
  FColumns.Align:=alClient;
  FColumns.ViewStyle:=vsReport;
  FColumns.ReadOnly:=True;
  FColumns.RowSelect:=True;
  FColumns.ColumnClick:=False;
  FColumns.HideSelection:=False;
  FColumns.DoubleBuffered:=True;
  FColumns.OnCustomDrawItem:=@DrawColumnRow;
  FColumns.ShowHint:=True;FColumns.OnMouseMove:=@ColumnHint;
  FRowImages:=TImageList.Create(Self);
  FRowImages.Width:=1;FRowImages.Height:=Scale96ToFont(28);
  RowBitmap:=TBitmap.Create;
  try
    RowBitmap.SetSize(1,FRowImages.Height);
    RowBitmap.Canvas.Brush.Color:=clWhite;
    RowBitmap.Canvas.FillRect(0,0,1,FRowImages.Height);
    FRowImages.AddMasked(RowBitmap,clWhite);
  finally RowBitmap.Free;end;
  FColumns.SmallImages:=FRowImages;
  for K:=1 to 5 do LoadGrid(Grid(Tab(FProperties,Names[K])),MetadataSQL(FTable,K));
  T:=Tab(FPages,'データ');
  Bar:=TPanel.Create(Self); Bar.Parent:=T; Bar.Align:=alTop; Bar.Height:=38;
  FNavigator:=TDBNavigator.Create(Self); FNavigator.Parent:=Bar; FNavigator.DataSource:=FSource;
  FNavigator.SetBounds(6,5,240,26); FNavigator.ConfirmDelete:=True;
  AddDivider(Bar,250);
  AddButton(Bar,'フォーム表示',254,100,@RecordForm);
  AddDivider(Bar,356);
  AddButton(Bar,'レコードコピー',360,110,@CopyRecord);
  AddDivider(Bar,474);
  FApply:=TBitBtn.Create(Self); FApply.Parent:=Bar; FApply.SetBounds(478,4,85,28);
  FImages.GetBitmap(icCommit,FApply.Glyph);
  FApply.Caption:='適用／確定'; FApply.OnClick:=@ApplyClick;
  AddDivider(Bar,566);
  FDiscard:=TBitBtn.Create(Self); FDiscard.Parent:=Bar; FDiscard.SetBounds(570,4,85,28);
  FImages.GetBitmap(icRollback,FDiscard.Glyph);
  FDiscard.Caption:='取り消し'; FDiscard.OnClick:=@DiscardClick;
  AddDivider(Bar,658);
  AddButton(Bar,'CSV出力',662,85,@ExportClick);
  Bar:=TPanel.Create(Self); Bar.Parent:=T; Bar.Align:=alTop; Bar.Height:=38; Bar.Top:=45;
  AddButton(Bar,'再表示',6,75,@RefreshClick);
  FFilter:=TEdit.Create(Self); FFilter.Parent:=Bar;
  FFilter.SetBounds(90,6,700,26); FFilter.Anchors:=[akLeft,akRight,akTop];
  FFilter.TextHint:='絞り込み条件（WHEREの後だけ。空欄は先頭1000行）';
  FGrid:=TDBGrid.Create(Self); FGrid.Parent:=T; FGrid.Align:=alClient; FGrid.DataSource:=FSource;
  FGrid.Options:=FGrid.Options+[dgEditing,dgTitles,dgIndicator,dgColumnResize];
  FGrid.OnDblClick:=@GridDblClick;
  T:=Tab(FPages,'メタデータ');
  Bar:=TPanel.Create(Self); Bar.Parent:=T; Bar.Align:=alTop; Bar.Height:=36;
  AddButton(Bar,'SQLを保存…',6,120,@SaveMetadata);
  FMetadata:=TMemo.Create(Self); FMetadata.Parent:=T; FMetadata.Align:=alClient;
  FMetadata.ReadOnly:=True; FMetadata.WordWrap:=False; FMetadata.ScrollBars:=ssBoth; FMetadata.Font.Name:='Consolas';
  T:=Tab(FPages,'パーミッション');
  CreatePermissionView(Self,T,FConnection,FMetaTransaction,FTable);
  LoadGrid(Grid(Tab(FPages,'依存関係')),MetadataSQL(FTable,6));
  LoadGrid(Grid(Tab(FPages,'詳細')),MetadataSQL(FTable,8));
  T:=Tab(FPages,'SQL Statements');
  FStatementTabs:=TTabControl.Create(Self);FStatementTabs.Parent:=T;FStatementTabs.Align:=alClient;
  FStatementTabs.Tabs.Add('Select');FStatementTabs.Tabs.Add('Insert');
  FStatementTabs.Tabs.Add('Update');FStatementTabs.Tabs.Add('Delete');
  FStatementTabs.TabIndex:=0;FStatementTabs.OnChange:=@StatementChanged;
  FStatements:=TSynEdit.Create(Self); FStatements.Parent:=FStatementTabs; FStatements.Align:=alClient;
  FStatements.ReadOnly:=True;
  FStatements.Font.Name:='Consolas';
  FStatements.Gutter.Visible:=False;
  FStatements.Highlighter:=TSynSQLSyn.Create(Self);
  TSynSQLSyn(FStatements.Highlighter).SQLDialect:=sqlFirebird40;
  TSynSQLSyn(FStatements.Highlighter).IdentifierAttri.Foreground:=clBlue;
  TSynSQLSyn(FStatements.Highlighter).StringAttri.Foreground:=clBlue;
  TSynSQLSyn(FStatements.Highlighter).KeyAttri.Foreground:=clBlack;
  TSynSQLSyn(FStatements.Highlighter).KeyAttri.Style:=[fsBold];
  // Metadata reads use their own short transaction; data edits use another one.
  LoadMetadata;
  if FMetaTransaction.Active then FMetaTransaction.Rollback;
  FProperties.ActivePageIndex:=0;
  FPages.ActivePage:=PropertyTab;
  FPages.OnChange:=@PagesChanged;
  ApplyModernTheme(Self);
end;
destructor TTableWindow.Destroy;
begin
  FLoading:=True;
  if Assigned(FSource) then FSource.OnStateChange:=nil;
  if Assigned(FData) then begin FData.Cancel; FData.Close; end;
  if Assigned(FDataTransaction) and FDataTransaction.Active then FDataTransaction.Rollback;
  if Assigned(FMetaTransaction) and FMetaTransaction.Active then FMetaTransaction.Rollback;
  inherited Destroy;
end;
function MetadataHeading(const Name: string): string;
const
  Keys: array[0..26] of string = ('INDEX_NAME','UNIQUE_FLAG','DESCENDING_FLAG',
    'INACTIVE','COLUMN_NAME','COLUMN_POSITION','EXPRESSION_SQL','CONSTRAINT_NAME',
    'CONSTRAINT_TYPE','CHECK_SQL','REFERENCED_TABLE','REFERENCED_COLUMN',
    'UPDATE_RULE','DELETE_RULE','TRIGGER_NAME','TRIGGER_TYPE','EXECUTION_ORDER',
    'SOURCE_SQL','DEPENDENT_NAME','OBJECT_TYPE','GRANTEE','GRANTEE_TYPE',
    'PRIVILEGE_CODE','GRANT_OPTION','GRANTOR','OWNER_NAME','RELATION_TYPE');
  Titles: array[0..26] of string = ('インデックス名','一意','並び順','状態',
    'カラム名','位置','式','制約名','種類','チェック条件','参照先テーブル',
    '参照先カラム','更新ルール','削除ルール','トリガー名','種類','実行順序',
    'SQL定義','依存オブジェクト','種類','付与先','付与先の種類','権限',
    '再付与','付与者','所有者','種類');
var I: Integer;
begin
  for I:=Low(Keys) to High(Keys) do if SameText(Name,Keys[I]) then Exit(Titles[I]);
  if SameText(Name,'DESCRIPTION') then Exit('説明');
  if SameText(Name,'VIEW_SQL') then Exit('ビュー定義');
  if SameText(Name,'SECURITY_CLASS') then Exit('セキュリティクラス');
  Result:=Name;
end;

procedure TTableWindow.LoadGrid(G:TStringGrid; const SQL:string);
var Q:TSQLQuery; R,C:Integer; Value,FieldName:string;
begin
  Q:=TSQLQuery.Create(nil);
  try
    Q.Database:=FConnection; Q.Transaction:=FMetaTransaction; Q.SQL.Text:=SQL; Q.Open;
    G.ColCount:=Q.FieldCount;
    for C:=0 to Q.FieldCount-1 do G.Cells[C,0]:=MetadataHeading(Q.Fields[C].FieldName);
    R:=1;
    while not Q.EOF do begin
      G.RowCount:=R+1;
      for C:=0 to Q.FieldCount-1 do begin
        Value:=Q.Fields[C].AsString;FieldName:=Q.Fields[C].FieldName;
        begin
          if FieldName='UNIQUE_FLAG' then begin if Value='1' then Value:='はい' else Value:='いいえ';end
          else if FieldName='DESCENDING_FLAG' then begin if Value='1' then Value:='降順' else Value:='昇順';end
          else if FieldName='INACTIVE' then begin if Value='1' then Value:='無効' else Value:='有効';end
          else if (FieldName='CONSTRAINT_TYPE') and (Value='PRIMARY KEY') then Value:='主キー'
          else if (FieldName='CONSTRAINT_TYPE') and (Value='UNIQUE') then Value:='一意';
        end;
        G.Cells[C,R]:=Value;
      end;
      // Firebird creates more than one enforcement trigger for a CHECK.
      // Show identical definitions once, while preserving composite-key segments.
      if (R>1)and(Q.FindField('CHECK_SQL')<>nil)and(G.Rows[R].Text=G.Rows[R-1].Text) then G.RowCount:=R
      else Inc(R);
      Q.Next;
    end;
    if R=1 then begin G.RowCount:=2;G.Tag:=1;G.Cells[0,1]:='該当する項目はありません';end;
  finally Q.Free; end;
end;

procedure TTableWindow.DrawMetadataCell(Sender: TObject; ACol, ARow: Integer;
  ARect: TRect; AState: TGridDrawState);
var G:TStringGrid; Style:TTextStyle;
begin
  G:=TStringGrid(Sender);
  G.Canvas.Font.Assign(G.Font);
  G.Canvas.Font.Color:=RGBToColor(40,49,62);
  if ARow=0 then begin
    G.Canvas.Brush.Color:=RGBToColor(232,237,245);
    G.Canvas.Font.Style:=[fsBold];
  end else if gdSelected in AState then G.Canvas.Brush.Color:=RGBToColor(220,234,252)
  else if Odd(ARow) then G.Canvas.Brush.Color:=clWhite
  else G.Canvas.Brush.Color:=RGBToColor(247,249,253);
  G.Canvas.FillRect(ARect);
  G.Canvas.Pen.Color:=RGBToColor(229,234,241);
  G.Canvas.Line(ARect.Left,ARect.Bottom-1,ARect.Right,ARect.Bottom-1);
  Inc(ARect.Left,Scale96ToFont(10));Dec(ARect.Right,Scale96ToFont(8));
  Style:=G.Canvas.TextStyle;
  Style.Alignment:=taLeftJustify;Style.Layout:=tlCenter;
  Style.SingleLine:=True;Style.Clipping:=True;Style.EndEllipsis:=True;
  G.Canvas.TextRect(ARect,ARect.Left,ARect.Top,G.Cells[ACol,ARow],Style);
end;

procedure TTableWindow.DrawColumnRow(Sender: TCustomListView; Item: TListItem;
  State: TCustomDrawState; var DefaultDraw: Boolean);
begin
  DefaultDraw:=True;
  if cdsSelected in State then Exit;
  if Odd(Item.Index) then Sender.Canvas.Brush.Color:=RGBToColor(247,249,253)
  else Sender.Canvas.Brush.Color:=clWhite;
  Sender.Canvas.Font.Color:=RGBToColor(40,49,62);
end;

procedure TTableWindow.LayoutMetadata(Sender: TObject);
const Minimums:array[0..5] of Integer=(150,180,110,110,180,90);
var I,J,K,W,Total,TextHeight:Integer; G:TStringGrid; Value:string;
begin
  if FLoading or FLayoutBusy or not Assigned(FColumns) or (FColumns.Columns.Count<>6) then Exit;
  FLayoutBusy:=True;
  try
  FColumns.Canvas.Font.Assign(FColumns.Font);
  TextHeight:=FColumns.Canvas.TextHeight('Ag');
  FRowImages.Height:=Max(Scale96ToFont(28),TextHeight+Scale96ToFont(12));
  Total:=0;
  for I:=0 to 5 do begin
    W:=Max(Scale96ToFont(Minimums[I]),FColumns.Canvas.TextWidth(FColumns.Columns[I].Caption)+Scale96ToFont(28));
    for J:=0 to FColumns.Items.Count-1 do begin
      if I=0 then Value:=FColumns.Items[J].Caption else Value:=FColumns.Items[J].SubItems[I-1];
      W:=Max(W,FColumns.Canvas.TextWidth(Value)+Scale96ToFont(28));
    end;
    W:=Min(W,Scale96ToFont(380));
    FColumns.Columns[I].Width:=W;Inc(Total,W);
  end;
  if Total<FColumns.ClientWidth-Scale96ToFont(20) then
    FColumns.Columns[4].Width:=FColumns.Columns[4].Width+FColumns.ClientWidth-Scale96ToFont(20)-Total;
  for K:=0 to ComponentCount-1 do if (Components[K] is TStringGrid) and not (Components[K] is TPermissionMatrix) then begin
    G:=TStringGrid(Components[K]);G.Canvas.Font.Assign(G.Font);
    G.DefaultRowHeight:=Max(Scale96ToFont(28),G.Canvas.TextHeight('Ag')+Scale96ToFont(12));
    G.RowHeights[0]:=G.DefaultRowHeight+Scale96ToFont(4);
    Total:=0;
    for I:=0 to G.ColCount-1 do begin
      W:=Max(Scale96ToFont(100),G.Canvas.TextWidth(G.Cells[I,0])+Scale96ToFont(32));
      for J:=1 to G.RowCount-1 do
        W:=Max(W,G.Canvas.TextWidth(G.Cells[I,J])+Scale96ToFont(24));
      if I=0 then W:=Max(W,Scale96ToFont(200));
      W:=Min(W,Scale96ToFont(400));
      G.ColWidths[I]:=W;Inc(Total,W);
    end;
    if Total<G.ClientWidth-Scale96ToFont(20) then
      G.ColWidths[G.ColCount-1]:=G.ColWidths[G.ColCount-1]+G.ClientWidth-Scale96ToFont(20)-Total;
  end;
  finally FLayoutBusy:=False;end;
end;

procedure TTableWindow.ColumnHint(Sender: TObject; Shift: TShiftState; X,Y: Integer);
var Item:TListItem; I:Integer; HintText:string;
begin
  Item:=FColumns.GetItemAt(X,Y);HintText:='';
  if Assigned(Item) then begin
    HintText:=FColumns.Columns[0].Caption+': '+Item.Caption;
    for I:=0 to Item.SubItems.Count-1 do
      if Item.SubItems[I]<>'' then HintText:=HintText+LineEnding+FColumns.Columns[I+1].Caption+': '+Item.SubItems[I];
  end;
  FColumns.Hint:=HintText;
end;

procedure TTableWindow.LoadMetadata;
var Q:TSQLQuery; R,K:Integer; ColumnName,Line:string;
    Columns:TStatementColumns;Keys:TStringList; Item:TListItem;
const BaseWidths:array[0..5] of Integer=(150,180,110,110,180,90);
      Headers:array[0..5] of string=('カラム名','データ型','文字セット','照合順序','デフォルト値','NULL許可');
begin
  Q:=TSQLQuery.Create(nil);Keys:=TStringList.Create;Columns:=nil;
  try
    Q.Database:=FConnection; Q.Transaction:=FMetaTransaction; Q.SQL.Text:=ColumnSQL(FTable); Q.Open;
    for K:=Low(Headers) to High(Headers) do
      with FColumns.Columns.Add do begin
        Caption:=Headers[K];
        Width:=Scale96ToFont(BaseWidths[K]);
      end;
    R:=1;
    FMetadata.Lines.Add('-- 列定義の参照用DDL。制約・索引・権限は各プロパティタブを参照。');
    FMetadata.Lines.Add('CREATE TABLE '+QuoteName(FTable)+' (');
    while not Q.EOF do begin
      ColumnName:=Q.FieldByName('FIELD_NAME').AsString;
      Item:=FColumns.Items.Add;
      Item.Caption:=ColumnName;
      Item.SubItems.Add(FieldTypeName(Q));
      Item.SubItems.Add(Q.FieldByName('CHARSET_NAME').AsString);
      Item.SubItems.Add(Q.FieldByName('COLLATION_NAME').AsString);
      Item.SubItems.Add(Q.FieldByName('DEFAULT_SOURCE').AsString);
      if Q.FieldByName('NOT_NULL_FLAG').AsInteger=1 then Item.SubItems.Add('不可')
      else Item.SubItems.Add('許可');
      Line:='  '+QuoteName(ColumnName)+' '+FieldTypeName(Q);
      if not Q.FieldByName('COMPUTED_SOURCE').IsNull then
        Line:='  '+QuoteName(ColumnName)+' COMPUTED BY '+Q.FieldByName('COMPUTED_SOURCE').AsString
      else begin
        if not Q.FieldByName('IDENTITY_TYPE').IsNull then begin
          if Q.FieldByName('IDENTITY_TYPE').AsInteger=0 then Line:=Line+' GENERATED ALWAYS AS IDENTITY'
          else Line:=Line+' GENERATED BY DEFAULT AS IDENTITY';
        end;
        if Q.FieldByName('CHARSET_NAME').AsString<>'' then Line:=Line+' CHARACTER SET '+Q.FieldByName('CHARSET_NAME').AsString;
        if Q.FieldByName('DEFAULT_SOURCE').AsString<>'' then Line:=Line+' '+Q.FieldByName('DEFAULT_SOURCE').AsString;
        if Q.FieldByName('NOT_NULL_FLAG').AsInteger=1 then Line:=Line+' NOT NULL';
      end;
      SetLength(Columns,R);
      Columns[R-1].Name:=ColumnName;
      Columns[R-1].Writable:=Q.FieldByName('COMPUTED_SOURCE').IsNull and Q.FieldByName('IDENTITY_TYPE').IsNull;
      Q.Next;
      if not Q.EOF then Line:=Line+',';
      FMetadata.Lines.Add(Line); Inc(R);
    end;
    FMetadata.Lines.Add(');');
    Q.Close;
    Q.SQL.Text:='SELECT TRIM(S.RDB$FIELD_NAME) AS KEY_NAME FROM RDB$RELATION_CONSTRAINTS C '+
      'JOIN RDB$INDEX_SEGMENTS S ON S.RDB$INDEX_NAME=C.RDB$INDEX_NAME '+
      'WHERE C.RDB$RELATION_NAME='+QuotedStr(FTable)+' AND C.RDB$CONSTRAINT_TYPE=''PRIMARY KEY'' ORDER BY S.RDB$FIELD_POSITION';
    Q.Open;
    while not Q.EOF do begin Keys.Add(Q.Fields[0].AsString);Q.Next;end;
    FStatementTexts:=BuildStatements(FTable,Columns,Keys,FIsView);
    StatementChanged(nil);
  finally Keys.Free;Q.Free; end;
end;
procedure TTableWindow.StatementChanged(Sender:TObject);
begin
  if FStatementTabs.TabIndex<0 then Exit;
  FStatements.Lines.Text:=FStatementTexts[FStatementTabs.TabIndex];
  FStatements.CaretX:=1;FStatements.CaretY:=1;
end;
function TTableWindow.Pending:Boolean;
begin
  Result:=FData.Active and ((FData.State in dsEditModes) or (FData.ChangeCount>0));
end;
function TTableWindow.PrepareClose:Boolean;
begin
  Result:=True;
  if Pending then Result:=MessageDlg('未保存のデータ','編集を取り消して閉じますか？',mtConfirmation,[mbYes,mbNo],0)=mrYes;
end;
procedure TTableWindow.CheckClose(Sender:TObject;var CanClose:Boolean);
begin
  CanClose:=PrepareClose;
  if CanClose then begin
    FData.Cancel; FData.Close;
    if FDataTransaction.Active then FDataTransaction.Rollback;
  end;
end;
procedure TTableWindow.CloseClick(Sender:TObject);
begin
  Close;
end;
procedure TTableWindow.OpenData;
var Q:TSQLQuery; K,Code:Integer; HasPK:Boolean; F:TField;
begin
  FLoading:=True;
  try
    FData.Cancel; FData.Close;
    if FDataTransaction.Active then FDataTransaction.Rollback;
    Q:=TSQLQuery.Create(nil);
    try
      Q.Database:=FConnection; Q.Transaction:=FMetaTransaction;
      Q.SQL.Text:='SELECT COUNT(*) FROM RDB$RELATION_CONSTRAINTS WHERE RDB$RELATION_NAME='+QuotedStr(FTable)+' AND RDB$CONSTRAINT_TYPE=''PRIMARY KEY''';
      Q.Open; HasPK:=Q.Fields[0].AsInteger>0; Q.Close;
      FCanEdit:=HasPK and not FIsView;
      FData.ReadOnly:=not FCanEdit;
      FData.SQL.Text:='SELECT FIRST 1000 * FROM '+QuoteName(FTable);
      if Trim(FFilter.Text)<>'' then FData.SQL.Add('WHERE '+FFilter.Text);
      FData.Open;
      Q.SQL.Text:=ColumnSQL(FTable); Q.Open;
      while not Q.EOF do begin
        F:=FData.FindField(Q.FieldByName('FIELD_NAME').AsString);
        Code:=Q.FieldByName('TYPE_CODE').AsInteger;
        if Assigned(F) and ((Code in [24,25,26,28,29]) or (Code=261) or
          not Q.FieldByName('COMPUTED_SOURCE').IsNull or not Q.FieldByName('IDENTITY_TYPE').IsNull) then begin
          if (pfInKey in F.ProviderFlags) and (Code in [24,25,26,28,29]) then FCanEdit:=False;
          F.ReadOnly:=True;
          F.Required:=False;
          F.ProviderFlags:=F.ProviderFlags-[pfInUpdate,pfInWhere];
        end;
        Q.Next;
      end;
    finally Q.Free; if FMetaTransaction.Active then FMetaTransaction.Rollback; end;
    FGrid.ReadOnly:=not FCanEdit;
    FSource.AutoEdit:=FCanEdit;
    if FCanEdit then FNavigator.VisibleButtons:=[nbFirst,nbPrior,nbNext,nbLast,nbInsert,nbDelete,nbEdit,nbPost,nbCancel]
    else FNavigator.VisibleButtons:=[nbFirst,nbPrior,nbNext,nbLast];
    for K:=0 to FGrid.Columns.Count-1 do if FGrid.Columns[K].Width>240 then FGrid.Columns[K].Width:=240;
  finally FLoading:=False; StateChanged(nil); end;
end;
procedure TTableWindow.StateChanged(Sender:TObject);
begin
  if FLoading or not Assigned(FApply) then Exit;
  FApply.Enabled:=FCanEdit and Pending;
  FDiscard.Enabled:=Pending;
  if Pending then FStatus.SimpleText:=UTF8Encode('未保存 — 適用／確定でDBへ反映します。')
  else if FCanEdit then FStatus.SimpleText:=UTF8Encode('先頭1000行 / 編集可（新データ型・BLOB・生成列は参照のみ） / ')+FConnection.DatabaseName
  else FStatus.SimpleText:=UTF8Encode('先頭1000行 / 参照のみ（ビュー、主キーなし、または未対応の主キー型） / ')+FConnection.DatabaseName;
end;
procedure TTableWindow.RefreshClick(Sender:TObject);
begin
  if Pending and not PrepareClose then Exit;
  OpenData;
end;
procedure TTableWindow.ApplyClick(Sender:TObject);
begin
  if not FCanEdit then Exit;
  if FData.State in dsEditModes then FData.Post;
  try
    FData.ApplyUpdates(0);
    FDataTransaction.Commit;
  except
    on E:Exception do begin
      FData.Close;
      if FDataTransaction.Active then FDataTransaction.Rollback;
      OpenData;
      raise Exception.Create(UTF8Encode('適用できなかったため、今回の編集を取り消して再表示しました: ')+E.Message);
    end;
  end;
  OpenData;
end;
procedure TTableWindow.DiscardClick(Sender:TObject);
begin
  if Pending and (MessageDlg('取り消し','この画面の未保存の編集を取り消しますか？',mtConfirmation,[mbYes,mbNo],0)<>mrYes) then Exit;
  OpenData;
end;
procedure TTableWindow.PagesChanged(Sender:TObject);
begin
  if (FPages.ActivePageIndex=1) and not FData.Active then OpenData;
  LayoutMetadata(nil);
end;
procedure TTableWindow.SelectData;
begin
  FPages.ActivePageIndex:=1;
  if not FData.Active then OpenData;
end;
procedure TTableWindow.SelectStatement(Index:Integer);
begin
  if (Index<Low(FStatementTexts)) or (Index>High(FStatementTexts)) then Exit;
  FPages.ActivePage:=FPages.Pages[FPages.PageCount-1];
  FStatementTabs.TabIndex:=Index;
  StatementChanged(nil);
end;
procedure TTableWindow.RecordForm(Sender:TObject);
var D:TForm; Scroll:TScrollBox; L:TLabel; E:TDBEdit; K,Y:Integer; B:TButton;
begin
  if not FData.Active or FData.IsEmpty then Exit;
  D:=TForm.CreateNew(Self);
  try
    D.Caption:=UTF8Encode('フォーム表示 - ')+FTable; D.SetBounds(150,150,560,580); D.Position:=poOwnerFormCenter;
    Scroll:=TScrollBox.Create(D); Scroll.Parent:=D; Scroll.Align:=alClient;
    Y:=12;
    for K:=0 to FData.FieldCount-1 do begin
      L:=TLabel.Create(D); L.Parent:=Scroll; L.SetBounds(12,Y,480,20); L.Caption:=FData.Fields[K].FieldName;
      E:=TDBEdit.Create(D); E.Parent:=Scroll; E.SetBounds(12,Y+22,480,26); E.DataSource:=FSource;
      E.DataField:=FData.Fields[K].FieldName; E.ReadOnly:=not FCanEdit or FData.Fields[K].ReadOnly;
      Inc(Y,64);
    end;
    B:=TButton.Create(D); B.Parent:=D; B.Align:=alBottom; B.Height:=32; B.Caption:='閉じる'; B.ModalResult:=mrOK;
    D.ShowModal;
  finally D.Free; StateChanged(nil); end;
end;

procedure TTableWindow.GridDblClick(Sender:TObject);
begin
  if not FData.Active then Exit;
  if (FData.Fields.Count>0) and (FGrid.SelectedField<>nil) and
    (FGrid.SelectedField.DataType in [ftBlob,ftMemo,ftWideMemo]) then
    OpenBlobViewer(Self,FGrid.SelectedField)
  else
    RecordForm(Sender);
end;
procedure TTableWindow.CopyRecord(Sender:TObject);
var Values:TStringList; K:Integer; Nulls:array of Boolean;
begin
  if not FCanEdit or not FData.Active or FData.IsEmpty then Exit;
  if FData.State in dsEditModes then FData.Post;
  Values:=TStringList.Create;
  try
    SetLength(Nulls,FData.FieldCount);
    for K:=0 to FData.FieldCount-1 do begin Values.Add(FData.Fields[K].AsString); Nulls[K]:=FData.Fields[K].IsNull; end;
    FData.Append;
    for K:=0 to FData.FieldCount-1 do
      if not FData.Fields[K].ReadOnly and not (pfInKey in FData.Fields[K].ProviderFlags) then
        if Nulls[K] then FData.Fields[K].Clear else FData.Fields[K].AsString:=Values[K];
    StateChanged(nil);
  finally Values.Free; end;
end;
procedure TTableWindow.ExportClick(Sender:TObject);
var D:TSaveDialog; Lines:TStringList; K:Integer; Line:string; Bookmark:TBookmark;
  function Cell(const S:string):string;
  begin Result:='"'+StringReplace(S,'"','""',[rfReplaceAll])+'"'; end;
begin
  if not FData.Active then Exit;
  D:=TSaveDialog.Create(Self); Lines:=TStringList.Create;
  try
    D.Filter:='CSV UTF-8|*.csv'; D.DefaultExt:='csv'; D.Options:=D.Options+[ofOverwritePrompt];
    if not D.Execute then Exit;
    Bookmark:=FData.GetBookmark; FData.DisableControls;
    try
      Line:=''; for K:=0 to FData.FieldCount-1 do begin if K>0 then Line:=Line+','; Line:=Line+Cell(FData.Fields[K].FieldName); end;
      Lines.Add(Line); FData.First;
      while not FData.EOF do begin
        Line:='';
        for K:=0 to FData.FieldCount-1 do begin
          if K>0 then Line:=Line+',';
          if FData.Fields[K].IsNull then Line:=Line+Cell('<NULL>')
          else if FData.Fields[K].DataType=ftBlob then Line:=Line+Cell('<BLOB>')
          else Line:=Line+Cell(FData.Fields[K].AsString);
        end;
        Lines.Add(Line); FData.Next;
      end;
      Lines.SaveToFile(D.FileName);
    finally
      if FData.BookmarkValid(Bookmark) then FData.GotoBookmark(Bookmark);
      FData.FreeBookmark(Bookmark); FData.EnableControls;
    end;
  finally D.Free; Lines.Free; end;
end;
procedure TTableWindow.SaveMetadata(Sender:TObject);
var D:TSaveDialog;
begin
  D:=TSaveDialog.Create(Self);
  try
    D.Filter:='SQL UTF-8|*.sql'; D.DefaultExt:='sql'; D.Options:=D.Options+[ofOverwritePrompt];
    if D.Execute then FMetadata.Lines.SaveToFile(D.FileName);
  finally D.Free; end;
end;
procedure TTableWindow.RunSelfTest;
var K:Integer;
begin
  for K:=0 to 3 do begin
    FStatementTabs.TabIndex:=K;StatementChanged(nil);
    if Trim(FStatements.Text)<>Trim(FStatementTexts[K]) then raise Exception.Create('SQL statement tab mismatch');
  end;
  FStatementTabs.TabIndex:=0;StatementChanged(nil);
  if (FColumns.Items.Count=0) or (FColumns.Items[0].Caption<>'ID') or
     (FColumns.Items[0].SubItems.Count<>5) then raise Exception.Create('Table column metadata missing');
  SelectData;
  if not FCanEdit then raise Exception.Create('Primary key table should be editable');
  if FData.Fields[0].AsInteger<>2 then raise Exception.Create('Table data mismatch');
  FData.Edit; FData.Fields[0].AsInteger:=3; FData.Post; ApplyClick(nil);
  if FData.Fields[0].AsInteger<>3 then raise Exception.Create('Update failed');
  FData.Edit; FData.Fields[0].AsInteger:=2; FData.Post; ApplyClick(nil);
  FData.Append; FData.Fields[0].AsInteger:=4; FData.Post; ApplyClick(nil);
  FData.Locate('ID',4,[]); FData.Delete; ApplyClick(nil);
  FData.First;
  if (FData.Fields[0].AsInteger<>2) or (FData.RecordCount<>1) then raise Exception.Create('Insert/delete failed');
  FData.Edit; FData.Fields[0].AsInteger:=99; FData.Post;
  OpenData;
  if FData.Fields[0].AsInteger<>2 then raise Exception.Create('Discard failed');
end;

procedure TTableWindow.RunCompositeSelfTest;
var GeneratedValue:Int64;
begin
  SelectData;
  if not FCanEdit then raise Exception.Create('Composite primary key table is not editable');
  FData.Append;
  FData.FieldByName('WORK_DATE').AsDateTime:=EncodeDate(2026,11,3);
  FData.FieldByName('UID').AsString:='test-user';
  FData.FieldByName('IN_TIME').AsDateTime:=EncodeTime(8,30,0,0);
  FData.FieldByName('WORK_HOURS').AsCurrency:=7.25;
  FData.FieldByName('NOTE').AsString:=UTF8Encode('日本語テスト');
  FData.Post;ApplyClick(nil);
  if (FData.RecordCount<>1) or (FData.FieldByName('WORK_HOURS').AsCurrency<>7.25) or
     (FData.FieldByName('NOTE').AsString<>UTF8Encode('日本語テスト')) or
     (not FData.FieldByName('OUT_TIME').IsNull) then raise Exception.Create('Typed insert/NULL/UTF8 failed');
  GeneratedValue:=FData.FieldByName('GENERATED_VALUE').AsLargeInt;
  FData.Edit;FData.FieldByName('WORK_HOURS').AsCurrency:=6.75;FData.Post;ApplyClick(nil);
  if (FData.FieldByName('WORK_HOURS').AsCurrency<>6.75) or
     (FData.FieldByName('GENERATED_VALUE').AsLargeInt<>GeneratedValue) then raise Exception.Create('Composite key update/identity failed');
  FData.Edit;FData.FieldByName('WORK_HOURS').AsCurrency:=-1;FData.Post;
  try
    ApplyClick(nil);
    raise Exception.Create('CHECK constraint did not reject invalid update');
  except on E:Exception do
    if Pos('CHECK constraint did not',E.Message)>0 then raise;
  end;
  if FData.FieldByName('WORK_HOURS').AsCurrency<>6.75 then raise Exception.Create('Failed apply was not rolled back');
  FData.Delete;ApplyClick(nil);
  if not FData.IsEmpty then raise Exception.Create('Composite key delete failed');
end;
end.
