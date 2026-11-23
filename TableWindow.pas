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
    function Tab(Pages: TPageControl; const Title: string): TTabSheet;
    function Grid(ParentControl: TWinControl): TStringGrid;
    procedure AddButton(ParentControl: TWinControl; const Title: string; X, W: Integer; Handler: TNotifyEvent);
    procedure LoadGrid(G: TStringGrid; const SQL: string);
    procedure LoadMetadata;
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

uses Math, AppTheme;

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
  Result.FixedCols:=0;
  Result.RowCount:=2;
  Result.ColCount:=1;
  Result.DefaultColWidth:=160;
  Result.Options:=Result.Options+[goColSizing,goRowSelect];
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
var T,PropertyTab:TTabSheet; Bar:TPanel; Split:TSplitter; K:Integer;
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
  PropertyTab:=Tab(FPages,'プロパティ');
  FProperties:=TPageControl.Create(Self); FProperties.Parent:=PropertyTab; FProperties.Align:=alClient;
  FProperties.Style:=tsFlatButtons;
  FProperties.Images:=CreateConsoleImages(Self,16);
  FColumns:=TListView.Create(Self);
  FColumns.Parent:=Tab(FProperties,'カラム');
  FColumns.Align:=alClient;
  FColumns.ViewStyle:=vsReport;
  FColumns.ReadOnly:=True;
  FColumns.RowSelect:=True;
  FColumns.ColumnClick:=False;
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
  LoadGrid(Grid(Tab(FPages,'パーミッション')),MetadataSQL(FTable,7));
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
procedure TTableWindow.LoadGrid(G:TStringGrid; const SQL:string);
var Q:TSQLQuery; R,C:Integer;
begin
  Q:=TSQLQuery.Create(nil);
  try
    Q.Database:=FConnection; Q.Transaction:=FMetaTransaction; Q.SQL.Text:=SQL; Q.Open;
    G.ColCount:=Q.FieldCount;
    for C:=0 to Q.FieldCount-1 do G.Cells[C,0]:=Q.Fields[C].FieldName;
    R:=1;
    while not Q.EOF do begin
      G.RowCount:=R+1;
      for C:=0 to Q.FieldCount-1 do G.Cells[C,R]:=Q.Fields[C].AsString;
      Inc(R); Q.Next;
    end;
    if R=1 then G.RowCount:=2;
  finally Q.Free; end;
end;
procedure TTableWindow.LoadMetadata;
var Q:TSQLQuery; R,K:Integer; ColumnName,Line:string;
    Columns:TStatementColumns;Keys:TStringList; Item:TListItem;
const BaseWidths:array[0..5] of Integer=(90,90,75,45,80,52);
      Headers:array[0..5] of string=('名称','タイプ','キャラクタセット','照合','デフォルト値','Null可');
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
      if Q.FieldByName('NOT_NULL_FLAG').AsInteger=1 then Item.SubItems.Add('No')
      else Item.SubItems.Add('Yes');
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
    for K:=0 to FColumns.Columns.Count-1 do begin
      FColumns.Columns[K].AutoSize:=True;
      R:=FColumns.Columns[K].Width;
      FColumns.Columns[K].AutoSize:=False;
      FColumns.Columns[K].Width:=EnsureRange(R,Scale96ToFont(BaseWidths[K]),Scale96ToFont(280));
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
