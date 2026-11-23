unit DatabasePropertiesDialog;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses Classes, ConnectionSettings, IBConnection;

procedure ShowDatabasePropertiesDialog(AOwner:TComponent;Connection:TIBConnection;
  const Settings:TConnectionSettings);

implementation

uses SysUtils, Forms, Controls, StdCtrls, ComCtrls, ExtCtrls, Grids, DB, SQLDB,
  Dialogs, AppTheme;

procedure ShowDatabasePropertiesDialog(AOwner:TComponent;Connection:TIBConnection;
  const Settings:TConnectionSettings);
var D:TForm;Pages:TPageControl;AliasTab,GeneralTab,DetailsTab:TTabSheet;
    L:TLabel;E:TEdit;Files:TListView;Options:TStringGrid;Info:TMemo;
    Buttons:TPanel;B:TButton;Q:TSQLQuery;T:TSQLTransaction;
    DBPath,OwnerName,ServerName,EngineVersion:string;
    PageSize,Dialect,ReadOnly,ForcedWrites,SweepInterval,PageBuffers,ODS,ODSM,
      PageCount,MaxMemory,UsedMemory,StartPage,FilePages:Int64;

  function ReadStringField(const FieldName:string):string;
  begin
    if Q.FieldByName(FieldName).IsNull then Result:=''
    else Result:=Trim(Q.FieldByName(FieldName).AsString);
  end;
  function ReadIntField(const FieldName:string):Int64;
  begin
    if Q.FieldByName(FieldName).IsNull then Result:=0
    else Result:=Q.FieldByName(FieldName).AsLargeInt;
  end;
  procedure AddLabel(AParent:TWinControl;const Text:string;X,Y,W:Integer);
  begin
    L:=TLabel.Create(D);L.Parent:=AParent;L.Caption:=Text;L.SetBounds(X,Y,W,20);
  end;
  function AddEdit(AParent:TWinControl;const Value:string;X,Y,W:Integer):TEdit;
  begin
    Result:=TEdit.Create(D);Result.Parent:=AParent;Result.SetBounds(X,Y,W,24);
    Result.Text:=Value;Result.ReadOnly:=True;Result.TabStop:=False;
  end;
  procedure AddOption(Row:Integer;const Name,Value:string);
  begin Options.Cells[0,Row]:=Name;Options.Cells[1,Row]:=Value;end;
  function BoolText(Value:Int64;const OnText,OffText:string):string;
  begin if Value<>0 then Result:=OnText else Result:=OffText;end;
  function FormatNumber(Value:Int64):string;
  begin Result:=FormatFloat('#,##0',Value);end;
  procedure AddFile(const Name:string;AStart,Pages:Int64);
  var Item:TListItem;
  begin
    Item:=Files.Items.Add;Item.Caption:=Name;
    Item.SubItems.Add(IntToStr(AStart));
    Item.SubItems.Add(FormatNumber(Pages));
  end;

begin
  if (Connection=nil) or not Connection.Connected then
    raise Exception.Create('データベースへ接続してください。');
  Q:=TSQLQuery.Create(nil);T:=TSQLTransaction.Create(nil);
  try
    T.Database:=Connection;Q.Database:=Connection;Q.Transaction:=T;Q.ReadOnly:=True;
    Q.SQL.Text:='SELECT MON$DATABASE_NAME, MON$OWNER, MON$PAGE_SIZE, MON$SQL_DIALECT, '+
      'MON$READ_ONLY, MON$FORCED_WRITES, MON$SWEEP_INTERVAL, MON$PAGE_BUFFERS, '+
      'MON$PAGES, MON$ODS_MAJOR, MON$ODS_MINOR, MON$STAT_ID FROM MON$DATABASE';
    Q.Open;
    DBPath:=ReadStringField('MON$DATABASE_NAME');
    OwnerName:=ReadStringField('MON$OWNER');
    PageSize:=ReadIntField('MON$PAGE_SIZE');
    Dialect:=ReadIntField('MON$SQL_DIALECT');
    ReadOnly:=ReadIntField('MON$READ_ONLY');
    ForcedWrites:=ReadIntField('MON$FORCED_WRITES');
    SweepInterval:=ReadIntField('MON$SWEEP_INTERVAL');
    PageBuffers:=ReadIntField('MON$PAGE_BUFFERS');
    PageCount:=ReadIntField('MON$PAGES');
    ODS:=ReadIntField('MON$ODS_MAJOR');
    ODSM:=ReadIntField('MON$ODS_MINOR');
    Q.Close;
    Q.SQL.Text:='SELECT COALESCE(M.MON$MAX_MEMORY_USED,0) AS MAX_USED, '+
      'COALESCE(M.MON$MEMORY_USED,0) AS USED FROM MON$DATABASE D '+
      'LEFT JOIN MON$MEMORY_USAGE M ON M.MON$STAT_ID=D.MON$STAT_ID AND M.MON$STAT_GROUP=0';
    Q.Open;
    MaxMemory:=ReadIntField('MAX_USED');UsedMemory:=ReadIntField('USED');Q.Close;

    ServerName:=Trim(Settings.ServerAlias);
    if ServerName='' then ServerName:=ServerLabel(Settings);
    try EngineVersion:=Trim(Connection.GetConnectionInfo(citServerVersionString));
    except EngineVersion:='';end;
    if EngineVersion='' then EngineVersion:='取得できません';

    if T.Active then T.Rollback;
    D:=TForm.CreateNew(AOwner);
    try
      D.Caption:='データベースのプロパティ';D.BorderStyle:=bsDialog;
      D.Position:=poOwnerFormCenter;D.ClientWidth:=420;D.ClientHeight:=440;
      AddLabel(D,'サーバー:  '+ServerName,8,7,390);
      Pages:=TPageControl.Create(D);Pages.Parent:=D;Pages.SetBounds(8,32,404,350);
      AliasTab:=TTabSheet.Create(D);AliasTab.PageControl:=Pages;AliasTab.Caption:='エイリアス';
      GeneralTab:=TTabSheet.Create(D);GeneralTab.PageControl:=Pages;GeneralTab.Caption:='一般';
      DetailsTab:=TTabSheet.Create(D);DetailsTab.PageControl:=Pages;DetailsTab.Caption:='詳細';

      AddLabel(AliasTab,'エイリアス名(L):',12,12,120);
      AddEdit(AliasTab,Settings.Name,12,34,374);
      AddLabel(AliasTab,'ファイル(E):',12,68,120);
      AddEdit(AliasTab,DBPath,12,90,374);

      AddLabel(GeneralTab,'要約情報',10,5,120);
      AddLabel(GeneralTab,'所有者:  '+OwnerName,16,25,350);
      Files:=TListView.Create(D);Files.Parent:=GeneralTab;Files.SetBounds(12,48,374,108);
      Files.ViewStyle:=vsReport;Files.ReadOnly:=True;Files.RowSelect:=True;Files.HideSelection:=False;
      Files.Columns.Add.Caption:='データベースファイル';Files.Columns[0].Width:=230;
      Files.Columns.Add.Caption:='開始ページ';Files.Columns[1].Width:=72;
      Files.Columns.Add.Caption:='ページ数';Files.Columns[2].Width:=68;
      if DBPath='' then DBPath:=Settings.Database;
      AddFile(DBPath,0,PageCount);
      Q.SQL.Text:='SELECT RDB$FILE_NAME, RDB$FILE_START, RDB$FILE_LENGTH FROM RDB$FILES '+
        'WHERE COALESCE(RDB$SHADOW_NUMBER,0)=0 ORDER BY RDB$FILE_SEQUENCE';
      Q.Open;
      while not Q.EOF do begin
        StartPage:=ReadIntField('RDB$FILE_START');
        FilePages:=ReadIntField('RDB$FILE_LENGTH');
        AddFile(ReadStringField('RDB$FILE_NAME'),StartPage,FilePages);
        Q.Next;
      end;
      Q.Close;
      AddLabel(GeneralTab,'割り当て済みページ:  '+FormatNumber(PageCount),14,160,230);
      AddLabel(GeneralTab,'ページサイズ:  '+FormatNumber(PageSize),248,160,135);
      AddLabel(GeneralTab,'オプション(P):',10,183,150);
      Options:=TStringGrid.Create(D);Options.Parent:=GeneralTab;Options.SetBounds(12,203,374,104);
      Options.ColCount:=2;Options.RowCount:=5;Options.FixedCols:=0;Options.FixedRows:=0;
      Options.DefaultRowHeight:=20;Options.ColWidths[0]:=220;Options.ColWidths[1]:=140;
      Options.Options:=Options.Options-[goEditing,goRowSelect,goRangeSelect];
      AddOption(0,'強制書き込み',BoolText(ForcedWrites,'有効','無効'));
      AddOption(1,'スイープ間隔',FormatNumber(SweepInterval));
      AddOption(2,'データベースダイアレクト',IntToStr(Dialect));
      AddOption(3,'読み取り専用',BoolText(ReadOnly,'はい','いいえ'));
      AddOption(4,'ページバッファ',FormatNumber(PageBuffers));

      Info:=TMemo.Create(D);Info.Parent:=DetailsTab;Info.SetBounds(10,8,378,300);
      Info.ReadOnly:=True;Info.ScrollBars:=ssVertical;Info.WordWrap:=False;
      Info.Lines.Add('DB実装バージョン:  '+EngineVersion);
      Info.Lines.Add('DBバージョン:  '+Connection.GetConnectionInfo(citServerVersion));
      Info.Lines.Add('SQLダイアレクト:  '+IntToStr(Dialect));
      Info.Lines.Add('ODSバージョン:  '+IntToStr(ODS)+'.'+IntToStr(ODSM));
      Info.Lines.Add('');
      Info.Lines.Add('最大メモリ使用量:  '+FormatNumber(MaxMemory)+' bytes');
      Info.Lines.Add('メモリ使用量:  '+FormatNumber(UsedMemory)+' bytes');

      Buttons:=TPanel.Create(D);Buttons.Parent:=D;Buttons.Align:=alBottom;
      Buttons.Height:=48;Buttons.BevelOuter:=bvNone;
      B:=TButton.Create(D);B.Parent:=Buttons;B.Caption:='OK';B.ModalResult:=mrOK;
      B.SetBounds(169,10,75,27);B.Default:=True;
      B:=TButton.Create(D);B.Parent:=Buttons;B.Caption:='キャンセル';B.ModalResult:=mrCancel;
      B.SetBounds(250,10,84,27);B.Cancel:=True;
      B:=TButton.Create(D);B.Parent:=Buttons;B.Caption:='適用';B.Enabled:=False;
      B.SetBounds(340,10,70,27);
      ApplyModernTheme(D);
      D.ShowModal;
    finally D.Free;end;
  finally
    Q.Free;
    if T.Active then T.Rollback;
    T.Free;
  end;
end;

end.
