unit MainForm;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, StdCtrls, ExtCtrls, ComCtrls, Buttons,
  Grids, Dialogs, Menus, IniFiles, Clipbrd, LMessages, DB, SQLDB, SQLDBLib, IBConnection, FBSession,
  ConnectionSettings, ConnectionDialog, LoginDialog, TableWindow, InspectorWindow,
  FirebirdServices, ServiceWindow, BackupRestoreDialog, DatabaseCreateDialog,
  DatabaseAdmin, ConsoleImages, DatabaseMetadata, MetadataWindow,
  ServerPropertiesDialog, ServerSession, ServerRegisterDialog, UserInfoDialog,
  DatabasePropertiesDialog, AppTheme, AboutDialog, FirebirdScriptParser;

type
  {$IFDEF LCLQt6}
  TSQLForm = class(TForm)
  private
    FCloseQueued:Boolean;
    procedure NativeClose(var Msg:TLMessage); message LM_CLOSEQUERY;
    procedure FinishClose(Data:PtrInt);
  public
    procedure RequestHide;
    destructor Destroy; override;
  end;
  {$ENDIF}
  TTemporaryServer=class
    Settings:TConnectionSettings;
  end;
  TDBCommand=(dcRegister,dcUnregister,dcConnect,dcConnectAs,dcDisconnect,dcCreate,dcDrop,
    dcMaintenance,dcBackupRestore,dcMetadata,dcUsers,dcProperties);
  TConsoleForm = class(TForm)
  private
    FSessionMenu:TMainMenu;
    FDBMenus:array[TDBCommand] of TMenuItem;
    FConnection: TIBConnection;
    FTransaction: TSQLTransaction;
    FLoader: TSQLDBLibraryLoader;
    FSettings: TConnectionSettings;
    FServerSession:TServerSession;
    FProfiles: TStringList;
    FObjects: TTreeView;
    FList: TListView;
    FHeading: TLabel;
    FSQLWindow: TForm;
    procedure CloseSQLClick(Sender:TObject);
    procedure SQLWindowClosing(Sender:TObject; var ACloseAction:TCloseAction);
  private
    FSQL, FLog, FSQLLog: TMemo;
    FQueryHistory:TStringList;
    FQueryHistoryIndex:Integer;
    FQueryDraft:string;
    FQueryNavigating:Boolean;
    FPreviousQueryTool,FNextQueryTool:TToolButton;
    FGrid: TStringGrid;
    FReturnsRows, FUseParams: TCheckBox;
    FRemainingRows: TSQLQuery;
    FSQLCatalog, FSQLFields: TListBox;
    FUseTableAlias: TCheckBox;
    FBuilderTables: TStringList;
    FBuilderGrid: TStringGrid;
    FSQLTabs, FResultTabs: TPageControl;
    FBuilderSheet, FSQLSheet, FDataSheet, FPlanSheet, FStatsSheet,
      FErrorsSheet: TTabSheet;
    FSQLPlan, FSQLStats: TMemo;
    FSQLStatus: TStatusBar;
    FStatus: TStatusBar;
    FConfig: string;
    FSystemDataMenu:TMenuItem;

    FTables: TList;
    FImages:TImageList;
    FToolbarImages:TImageList;
    FFetchAllTool:TToolButton;
    FFetchAllMenu:TMenuItem;
    FWindowButton:TToolButton;
    FWindowMenu:TPopupMenu;
    FServerLoginTool, FServerLogoutTool, FCreateTool, FConnectTool, FDisconnectTool:TToolButton;
    FListActions: Boolean;
    FContext: TPopupMenu;
    FPending: Boolean;
    FResultRows: Integer;
    function NewQuery: TSQLQuery;
    procedure Log(const S: string);
    procedure UpdateStatus;
    procedure RequireConnection;
    procedure RefreshObjects(Sender: TObject);
    procedure BrowseObject(Sender: TObject);
    procedure ConnectClick(Sender: TObject);
    procedure ConnectAdditional(const Candidate:TConnectionSettings;const Password:string);
    procedure NewSessionWindow(Sender:TObject);
    procedure CloseSessionTab(Sender:TObject);
    procedure ConnectDatabaseClick(Sender:TObject);
    procedure ConnectDatabaseAsClick(Sender:TObject);
    procedure DisconnectClick(Sender: TObject);
    procedure ExecuteClick(Sender: TObject);
    procedure PreviousQuery(Sender:TObject);
    procedure NextQuery(Sender:TObject);
    procedure AddQueryToHistory(const SQL:string);
    procedure UpdateQueryHistoryButtons;
    procedure SQLChanged(Sender:TObject);
    procedure HistoryPopup(Sender:TObject);
    procedure ChooseHistory(Sender:TObject);
    procedure PrepareSQL(Sender:TObject);
    procedure PrintSQL(Sender:TObject);
    procedure AppendResultRow(Q:TSQLQuery; Row:Integer);
    procedure FindSQLText(Sender:TObject);
    procedure FetchAllClick(Sender:TObject);
    procedure WindowMenuPopup(Sender:TObject);
    procedure WindowMenuClick(Sender:TObject);
    procedure SwitchSQLWindow(Sender:TObject);
    procedure CommitClick(Sender: TObject);
    procedure RollbackClick(Sender: TObject);
    procedure ExportClick(Sender: TObject);
    procedure SaveProfile(Sender: TObject);
    procedure NewConnection(Sender: TObject);
    procedure RegisterDatabaseClick(Sender:TObject);
    procedure RegisterServerClick(Sender:TObject);
    procedure UnregisterConnection(Sender:TObject);
    procedure ToggleSystemData(Sender:TObject);
    procedure RefreshView(Sender:TObject);
    procedure ClientInformation(Sender:TObject);
    procedure UpdateDBMenus(Sender:TObject);
    procedure UpdateToolbarState;
    procedure RefreshTreeImages;
    procedure RebuildTree;
    procedure ReadProfile(const AName: string; out Settings: TConnectionSettings);
    procedure TreeChanged(Sender: TObject; Node: TTreeNode);
    procedure ListOpen(Sender: TObject);
    procedure OpenSQL(Sender: TObject);
    procedure PopulateSQLCatalog;
    procedure SQLCatalogClick(Sender: TObject);
    procedure AddSQLTable(Sender: TObject);
    procedure AddSQLField(Sender: TObject);
    procedure UpdateBuilderSQL(Sender: TObject);
    procedure BuilderGridChanged(Sender: TObject; ACol, ARow: Integer;
      const Value: string);
    procedure OpenTable;
    procedure TableClosed(Sender:TObject; var CloseAction:TCloseAction);
    procedure OpenTableData(Sender:TObject);
    procedure OpenTableStatement(Sender:TObject);
    procedure CreateSelectSQL(Sender:TObject);
    procedure CopyObjectName(Sender:TObject);
    procedure DatabaseProperties(Sender: TObject);
    procedure CreateDatabaseClick(Sender:TObject);
    procedure DeleteDatabaseClick(Sender:TObject);
    function SelectedConnectionSettings(out Settings:TConnectionSettings):Boolean;
    procedure ConnectedUsers(Sender: TObject);
    procedure DatabaseStatistics(Sender: TObject);
    procedure DatabaseMetadata(Sender: TObject);
    procedure BackupClick(Sender:TObject);
    procedure RestoreClick(Sender:TObject);
    procedure SweepClick(Sender:TObject);
    procedure ValidateClick(Sender:TObject);
    procedure ServerLogClick(Sender:TObject);
    procedure UsersClick(Sender:TObject);
    procedure UserActionClick(Sender:TObject);
    procedure UserListPopup(Sender:TObject);
    procedure ServerLoginClick(Sender:TObject);
    procedure LoginToServer(const Settings:TConnectionSettings);
    procedure ServerLogoutClick(Sender:TObject);
    procedure ServerPropertiesClick(Sender:TObject);
    function ApplyServerProperties(const Original,Settings:TConnectionSettings):Boolean;
    procedure Maintenance(Operation:TServiceOperation);
    function ActiveSelection:Boolean;
    procedure ActionOpen(Sender: TObject);
    procedure PopupOpening(Sender: TObject);
    procedure TreeMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
    procedure ConnectTo(const Settings: TConnectionSettings; const Password: string);
    procedure EditConnection(const InitialSettings: TConnectionSettings);
    procedure LoadSQL(Sender: TObject);
    procedure SaveSQL(Sender: TObject);
    procedure ShowDefinition(Sender: TObject);
    procedure AboutClick(Sender: TObject);
    procedure CloseCheck(Sender: TObject; var CanClose: Boolean);
    function EndSession: Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure RunSmokeTest(const ClientLibrary, DatabasePath, ReportPath: string);
    procedure OpenRegisteredSession(const ProfileName:string);
  end;

type
  TConsoleHost = class(TForm)
  private
    Pages:TPageControl;
    Explorer:TTreeView;
    ActiveBar:TToolBar;
    RefreshQueued, FExplorerBusy:Boolean;
    procedure RefreshExplorer(Data:PtrInt);
    procedure QueueRefresh;
    procedure ExplorerChanged(Sender:TObject);
    procedure ExplorerOpen(Sender:TObject);
    procedure ExplorerMouse(Sender:TObject; Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
    procedure PageChanged(Sender:TObject);
    procedure CheckSessions(Sender:TObject; var CanClose:Boolean);
    procedure RemoveTab(Data:PtrInt);
  public
    constructor Create(AOwner:TComponent); override;
    destructor Destroy; override;
    function AddSession:TConsoleForm;
    function SessionForConnection:TConsoleForm;
    procedure CheckLibrary(const LibraryPath:string);
    {$IFDEF MULTIDB_TEST}procedure CheckTwoDatabases;{$ENDIF}
  end;

var
  ConsoleHost:TConsoleHost;
  ConsoleForm: TConsoleForm;

implementation

uses {$if defined(MULTIDB_TEST) and defined(LCLQt6)}qt6, qtwidgets,{$endif}
  FileInfo, LCLType, LazUTF8, Printers, PrintersDlgs, OSPrinters, ibase60dyn;

type
  TPlanQuery = class(TSQLQuery);
  TPlanCursor = class(TIBCursor);

{$IFDEF LCLQt6}
procedure TSQLForm.NativeClose(var Msg:TLMessage);
begin
  Msg.Result:=0;
  RequestHide;
end;

procedure TSQLForm.RequestHide;
begin
  if FCloseQueued then Exit;
  FCloseQueued:=True;
  Application.QueueAsyncCall(@FinishClose,0);
end;

procedure TSQLForm.FinishClose(Data:PtrInt);
begin
  FCloseQueued:=False;
  if Visible then Hide;
end;

destructor TSQLForm.Destroy;
begin
  Application.RemoveAsyncCalls(Self);
  inherited Destroy;
end;
{$ENDIF}

function QuoteIdentifier(const S: string): string;
begin
  Result := '"' + StringReplace(S, '"', '""', [rfReplaceAll]) + '"';
end;

function CSVCell(const S: string): string;
begin
  Result := '"' + StringReplace(S, '"', '""', [rfReplaceAll]) + '"';
end;

function TreeServerLabel(const S:TConnectionSettings):string;
begin
  if Trim(S.ServerAlias)<>'' then Result:=S.ServerAlias else Result:=ServerLabel(S);
end;

constructor TConsoleForm.Create(AOwner: TComponent);
var WorkPanel, SQLToolbar, Header, SQLBody, SQLLeft, SQLRight, CatalogPanel,
    FieldsPanel: TPanel; Toolbar,SQLTools:TToolBar; SQLWindowButton:TToolButton;
    Split, SQLSplit, QuerySplit: TSplitter;
    L: TLabel; B: TButton; SQLMenu:TMainMenu;Item:TMenuItem;
    I: TIniFile; MainMenu: TMainMenu; M: TMenuItem; Popup: TPopupMenu;
  function NextToolLeft(AToolbar:TToolBar):Integer;
  var J:Integer;
  begin
    Result:=0;
    for J:=0 to AToolbar.ButtonCount-1 do
      if AToolbar.Buttons[J].Left+AToolbar.Buttons[J].Width>Result then
        Result:=AToolbar.Buttons[J].Left+AToolbar.Buttons[J].Width;
  end;
  function Tool(const Title:string;Image:Integer;Handler:TNotifyEvent):TToolButton;
  var X:Integer;
  begin
    X:=NextToolLeft(Toolbar);
    Result:=TToolButton.Create(Self);Result.Parent:=Toolbar;Result.Left:=X;Result.Caption:=Title;
    Result.Hint:=Title;Result.ImageIndex:=Image;Result.OnClick:=Handler;
  end;
  procedure ToolDivider(AToolbar:TToolBar);
  var Button:TToolButton;X:Integer;
  begin
    X:=NextToolLeft(AToolbar);
    Button:=TToolButton.Create(Self);Button.Parent:=AToolbar;Button.Left:=X;
    Button.Style:=tbsSeparator;Button.Width:=8;
  end;
  function SQLTool(const Title:string;Image:Integer;Handler:TNotifyEvent):TToolButton;
  var X:Integer;
  begin
    X:=NextToolLeft(SQLTools);
    Result:=TToolButton.Create(Self);
    Result.Parent:=SQLTools;Result.Left:=X;Result.Caption:=Title;
    Result.Hint:=Title;Result.ImageIndex:=Image;Result.OnClick:=Handler;
  end;
  procedure MenuAction(const ACaption: string; AClick: TNotifyEvent);
  var Item: TMenuItem;
  begin
    Item := TMenuItem.Create(Self);
    Item.Caption := ACaption;
    Item.OnClick := AClick;
    Item.ImageIndex:=IconForCaption(ACaption);
    M.Add(Item);
  end;
  procedure DBAction(C:TDBCommand;const Title:string;Handler:TNotifyEvent;Icon:Integer);
  begin
    MenuAction(Title,Handler);FDBMenus[C]:=M.Items[M.Count-1];FDBMenus[C].ImageIndex:=Icon;
  end;
  procedure DBSeparator;
  begin MenuAction('-',nil);end;
  procedure DBChild(C:TDBCommand;const Title:string;Handler:TNotifyEvent;Icon:Integer);
  var Child:TMenuItem;
  begin
    Child:=TMenuItem.Create(Self);Child.Caption:=Title;Child.ImageIndex:=Icon;
    Child.OnClick:=Handler;FDBMenus[C].Add(Child);
  end;
  procedure MenuGroup(const ACaption: string);
  begin
    M := TMenuItem.Create(Self);
    M.Caption := ACaption;
    MainMenu.Items.Add(M);
  end;
  procedure PopupAction(const ACaption: string; AClick: TNotifyEvent);
  var Item: TMenuItem;
  begin
    Item := TMenuItem.Create(Self);
    Item.Caption := ACaption;
    Item.OnClick := AClick;
    Item.ImageIndex:=IconForCaption(ACaption);
    Popup.Items.Add(Item);
  end;
begin
  inherited CreateNew(AOwner);
  Caption := 'FBConsole — Firebird 5 / 0.3.79';
  SetBounds(60, 40, 1220, 820);
  Constraints.MinWidth := 900;
  Constraints.MinHeight := 580;
  Position := poScreenCenter;
  OnCloseQuery := @CloseCheck;
  FConfig := ExpandFileName(ExtractFilePath(ParamStr(0)) + 'config/connections.ini');
  if not ForceDirectories(ExtractFileDir(FConfig)) then
    raise Exception.Create(UTF8Encode('設定フォルダーを作成できません: ')+ExtractFileDir(FConfig));
  FProfiles := TStringList.Create;FProfiles.OwnsObjects:=True;
  FQueryHistory:=TStringList.Create;
  FQueryHistoryIndex:=-1;
  FTables := TList.Create;
  FBuilderTables := TStringList.Create;
  FSettings := DefaultSettings;
  FServerSession:=TServerSession.Create;
  FResultRows := -1;
  FConnection := TIBConnection.Create(Self);
  FConnection.LoginPrompt := False;
  FTransaction := TSQLTransaction.Create(Self);
  FTransaction.Database := FConnection;
  FConnection.Transaction := FTransaction;
  FLoader := TSQLDBLibraryLoader.Create(Self);
  FLoader.ConnectionType := 'Firebird';
  FImages:=CreateConsoleImages(Self);
  FToolbarImages:=CreateConsoleImages(Self,24);

  MainMenu := TMainMenu.Create(Self);
  FSessionMenu:=MainMenu;
  Menu := MainMenu;
  MainMenu.Images:=FImages;
  MenuGroup('コンソール(&C)');
  MenuAction('新しい接続／登録…', @NewConnection);
  MenuAction('接続設定を保存', @SaveProfile);
  MenuGroup('表示(&V)');
  MenuAction('インタラクティブSQL(&Q)…',@OpenSQL);
  MenuAction('クライアント情報(&L)…',@ClientInformation);
  M.Items[M.Count-1].ImageIndex:=icProperties;
  MenuAction('-',nil);
  MenuAction('システムデータ(&Y)',@ToggleSystemData);
  FSystemDataMenu:=M.Items[M.Count-1];FSystemDataMenu.ImageIndex:=-1;
  I:=TIniFile.Create(ExtractFileDir(FConfig)+PathDelim+'view.ini');
  try FSystemDataMenu.Checked:=I.ReadBool('View','SystemData',False);finally I.Free;end;
  MenuAction('-',nil);
  MenuAction('最新の状態に更新(&R)',@RefreshView);
  M.Items[M.Count-1].ShortCut:=ShortCut(VK_F5,[]);
  MenuGroup('サーバー(&S)');
  MenuAction('サーバーを登録(&R)…', @RegisterServerClick);
  MenuAction('サーバーを登録解除(&U)…', @UnregisterConnection);
  Item:=TMenuItem.Create(Self);Item.Caption:='-';M.Add(Item);
  MenuAction('サーバーへログイン(&L)…', @ServerLoginClick);
  MenuAction('サーバーからログアウト(&O)', @ServerLogoutClick);
  MenuAction('接続を切断(&D)…', @DisconnectClick);
  Item:=TMenuItem.Create(Self);Item.Caption:='-';M.Add(Item);
  MenuAction('ユーザー情報(&S)…', @UsersClick);
  MenuAction('ログファイルを表示(&V)…', @ServerLogClick);
  MenuAction('サーバーのプロパティ(&P)…', @ServerPropertiesClick);
  MenuGroup('データベース(&D)');M.OnClick:=@UpdateDBMenus;
  DBAction(dcRegister,'データベースを登録(&R)…',@NewConnection,icDatabaseRegister);
  DBAction(dcUnregister,'データベースを登録解除(&U)…',@UnregisterConnection,icDatabaseOffline);
  DBSeparator;
  DBAction(dcConnect,'データベースへ接続(&C)',@ConnectClick,icDatabaseConnect);
  DBAction(dcConnectAs,'ユーザーを指定して接続(&A)…',@ConnectClick,icUsers);
  DBAction(dcDisconnect,'データベースから切断(&D)',@DisconnectClick,icDisconnect);
  DBSeparator;
  DBAction(dcCreate,'データベースの作成(&V)…',@CreateDatabaseClick,icDatabaseCreate);
  DBAction(dcDrop,'データベースの削除(&W)…',@DeleteDatabaseClick,icDatabaseOffline);
  DBSeparator;
  DBAction(dcMaintenance,'メンテナンス(&M)',nil,-1);
  DBChild(dcMaintenance,'統計情報…',@DatabaseStatistics,icStatistics);
  DBChild(dcMaintenance,'スイープ…',@SweepClick,icSweep);
  DBChild(dcMaintenance,'検証…',@ValidateClick,icValidate);
  DBAction(dcBackupRestore,'バックアップ／リストア(&X)',nil,-1);
  DBChild(dcBackupRestore,'バックアップ…',@BackupClick,icBackup);
  DBChild(dcBackupRestore,'リストア…',@RestoreClick,icRestore);
  DBAction(dcMetadata,'メタデータの表示(&Y)…',@DatabaseMetadata,icLog);
  DBAction(dcUsers,'接続中のユーザ(&Z)…',@ConnectedUsers,icUsers);
  DBAction(dcProperties,'データベースのプロパティ(&P)…',@DatabaseProperties,icProperties);
  MenuGroup('ツール(&T)');
  MenuAction('サーバーログ…', @ServerLogClick);
  MenuAction('ユーザー一覧…', @UsersClick);
  MenuGroup('SQL');
  MenuAction('対話型SQLを開く…', @OpenSQL);
  MenuAction('SQLファイルを開く…', @LoadSQL);
  MenuAction('SQLファイルを保存…', @SaveSQL);
  MenuAction('コミット', @CommitClick);
  MenuAction('ロールバック', @RollbackClick);
  MenuGroup('ウィンドウ(&W)');
  MenuAction('対話型SQL', @OpenSQL);
  MenuGroup('ヘルプ(&H)');
  MenuAction('FBConsoleについて', @AboutClick);

  Toolbar := TToolBar.Create(Self);
  Toolbar.Parent := Self;
  Toolbar.Align := alTop;
  Toolbar.Height := 40;
  Toolbar.Flat:=True;Toolbar.ButtonWidth:=34;Toolbar.ButtonHeight:=36;Toolbar.ShowHint:=True;
  Toolbar.ShowCaptions:=False;
  Toolbar.Images:=FToolbarImages;
  Tool('サーバー登録',icRegister,@RegisterServerClick);
  FServerLoginTool:=Tool('サーバーにログイン',icConnect,@ServerLoginClick);
  FServerLogoutTool:=Tool('サーバーからログアウト',icDisconnect,@ServerLogoutClick);
  ToolDivider(Toolbar);
  FCreateTool:=Tool('データベースの作成',icDatabaseCreate,@CreateDatabaseClick);
  Tool('データベースを登録',icDatabaseRegister,@NewConnection);
  FConnectTool:=Tool('データベースにログイン',icDatabaseConnect,@ConnectClick);
  FDisconnectTool:=Tool('データベースから切断',icDatabaseOffline,@DisconnectClick);
  ToolDivider(Toolbar);
  Tool('対話型SQL',icSQL,@OpenSQL);
  Tool('最新の状態に更新 (F5)',icRefresh,@RefreshView);
  FWindowButton:=Tool('ウィンドウの切り替え',icForm,nil);
  FWindowButton.Style:=tbsButtonDrop;
  FStatus := TStatusBar.Create(Self);
  FStatus.Parent := Self;
  FStatus.SimplePanel := False;
  FStatus.Panels.Add.Width:=240;FStatus.Panels.Add.Width:=360;
  FStatus.Panels.Add.Width:=160;FStatus.Panels.Add.Width:=300;
  FLog := TMemo.Create(Self);
  FLog.Parent := Self;
  FLog.Align := alBottom;
  FLog.Height := 85;
  FLog.ReadOnly := True;
  FLog.WordWrap := False;
  FLog.ScrollBars := ssAutoBoth;
  FLog.Visible := False;
  FObjects := TTreeView.Create(Self);
  FObjects.Parent := Self;
  FObjects.Align := alLeft;
  FObjects.Width := 440;
  FObjects.Indent:=20;
  FObjects.ReadOnly := True;
  FObjects.Images:=FImages;
  FObjects.HideSelection := False;
  FObjects.OnDblClick := @BrowseObject;
  FObjects.OnMouseDown := @TreeMouseDown;
  Split := TSplitter.Create(Self);
  Split.Align := alLeft;
  Split.Left := FObjects.Left + FObjects.Width;
  Split.Width := 5;
  Split.Parent := Self;
  Split.ResizeControl := FObjects;
  Split.Beveled := False;
  Split.AutoSnap := False;
  Split.MinSize := 220;
  WorkPanel := TPanel.Create(Self);
  WorkPanel.Parent := Self;
  WorkPanel.Align := alClient;
  WorkPanel.BevelOuter := bvNone;
  Header := TPanel.Create(Self);
  Header.Parent := WorkPanel;
  Header.Align := alTop;
  Header.Height := 44;
  Header.BevelOuter := bvNone;
  FHeading := TLabel.Create(Self);
  FHeading.Parent := Header;
  FHeading.SetBounds(16, 10, 700, 26);
  FHeading.Font.Size:=12;FHeading.Font.Style:=[fsBold];
  FHeading.Caption := '登録されたサーバーとデータベース';
  FList := TListView.Create(Self);
  FList.Parent := WorkPanel;
  FList.Align := alClient;
  FList.ViewStyle := vsReport;
  FList.ReadOnly := True;
  FList.SmallImages:=FImages;
  FList.RowSelect := True;
  FList.HideSelection := False;
  FList.Columns.Add.Caption := 'ユーザー名';
  FList.Columns[0].Width := 230;
  FList.Columns.Add.Caption := '名';FList.Columns[1].Width:=150;
  FList.Columns.Add.Caption := 'ミドルネーム';FList.Columns[2].Width:=170;
  FList.Columns.Add.Caption := '姓';FList.Columns[3].Width:=170;
  FList.OnDblClick := @ListOpen;
  Popup := TPopupMenu.Create(Self);
  Popup.Images:=FImages;
  PopupAction('開く', @BrowseObject);
  PopupAction('構造・定義', @ShowDefinition);
  PopupAction('対話型SQL', @OpenSQL);
  FObjects.PopupMenu := Popup;
  FContext := Popup;
  FContext.OnPopup := @PopupOpening;
  Popup := TPopupMenu.Create(Self);
  Popup.Images:=FImages;
  Popup.OnPopup:=@UserListPopup;
  FList.PopupMenu := Popup;

  {$IFDEF LCLQt6}
  FSQLWindow := TSQLForm.CreateNew(Self);
  {$ELSE}
  FSQLWindow := TForm.CreateNew(Self);
  {$ENDIF}
  FSQLWindow.Caption := '対話型SQL — FBConsole';
  FSQLWindow.SetBounds(100, 50, 1120, 780);
  FSQLWindow.Constraints.MinWidth := 920;
  FSQLWindow.Constraints.MinHeight := 600;
  FSQLWindow.Position := poOwnerFormCenter;
  if Assigned(ConsoleHost) then begin
    {$IFDEF LCLQt6}
    FSQLWindow.PopupMode:=pmNone;
    {$ELSE}
    FSQLWindow.PopupMode:=pmExplicit;
    FSQLWindow.PopupParent:=ConsoleHost;
    {$ENDIF}
  end;
  FSQLWindow.OnClose:=@SQLWindowClosing;
  B:=TButton.Create(FSQLWindow);
  B.Name:='CloseSQLButton';
  B.Parent:=FSQLWindow;
  B.Align:=alBottom;
  B.Caption:='閉じる';
  B.OnClick:=@CloseSQLClick;
  SQLMenu:=TMainMenu.Create(Self);SQLMenu.Images:=FImages;FSQLWindow.Menu:=SQLMenu;
  M:=TMenuItem.Create(Self);M.Caption:='ファイル(&F)';SQLMenu.Items.Add(M);
  Item:=TMenuItem.Create(Self);Item.Caption:='SQLファイルを開く…';Item.ImageIndex:=icOpen;Item.OnClick:=@LoadSQL;M.Add(Item);
  Item:=TMenuItem.Create(Self);Item.Caption:='SQLファイルを保存…';Item.ImageIndex:=icSave;Item.OnClick:=@SaveSQL;M.Add(Item);
  MenuAction('SQLを印刷…',@PrintSQL);M.Items[M.Count-1].ImageIndex:=icPrint;
  MenuAction('閉じる',@CloseSQLClick);
  M.Items[M.Count-1].ShortCut:=ShortCut(Ord('W'),[ssCtrl]);
  M:=TMenuItem.Create(Self);M.Caption:='クエリ(&Q)';SQLMenu.Items.Add(M);
  Item:=TMenuItem.Create(Self);Item.Caption:='実行';Item.ShortCut:=ShortCut(Ord('E'),[ssCtrl]);Item.ImageIndex:=icTrigger;Item.OnClick:=@ExecuteClick;M.Add(Item);
  Item:=TMenuItem.Create(Self);Item.Caption:='前のクエリ';Item.ShortCut:=ShortCut(Ord('P'),[ssCtrl]);Item.ImageIndex:=icPreviousQuery;Item.OnClick:=@PreviousQuery;M.Add(Item);
  Item:=TMenuItem.Create(Self);Item.Caption:='次のクエリ';Item.ShortCut:=ShortCut(Ord('N'),[ssCtrl]);Item.ImageIndex:=icNextQuery;Item.OnClick:=@NextQuery;M.Add(Item);
  MenuAction('前処理（実行計画）',@PrepareSQL);M.Items[M.Count-1].ImageIndex:=icPlan;
  FFetchAllMenu:=TMenuItem.Create(Self);FFetchAllMenu.Caption:='すべてをフェッチ';
  FFetchAllMenu.ImageIndex:=icFetchAll;FFetchAllMenu.OnClick:=@FetchAllClick;M.Add(FFetchAllMenu);
  Item:=TMenuItem.Create(Self);Item.Caption:='SQL内を検索…';Item.ImageIndex:=icSearch;Item.OnClick:=@FindSQLText;M.Add(Item);
  Item:=TMenuItem.Create(Self);Item.Caption:='CSV出力';Item.ImageIndex:=icExport;Item.OnClick:=@ExportClick;M.Add(Item);
  M:=TMenuItem.Create(Self);M.Caption:='トランザクション(&T)';SQLMenu.Items.Add(M);
  Item:=TMenuItem.Create(Self);Item.Caption:='コミット';Item.ImageIndex:=icCommit;Item.OnClick:=@CommitClick;M.Add(Item);
  Item:=TMenuItem.Create(Self);Item.Caption:='ロールバック';Item.ImageIndex:=icRollback;Item.OnClick:=@RollbackClick;M.Add(Item);
  M:=TMenuItem.Create(Self);M.Caption:='ヘルプ(&H)';SQLMenu.Items.Add(M);
  Item:=TMenuItem.Create(Self);Item.Caption:='FBConsoleについて';Item.OnClick:=@AboutClick;M.Add(Item);
  FWindowMenu:=TPopupMenu.Create(Self);FWindowMenu.Images:=FImages;
  FWindowMenu.OnPopup:=@WindowMenuPopup;
  FWindowButton.DropDownMenu:=FWindowMenu;

  FSQLStatus:=TStatusBar.Create(Self);FSQLStatus.Parent:=FSQLWindow;
  FSQLStatus.Align:=alBottom;FSQLStatus.SimplePanel:=True;
  FSQLStatus.SimpleText:='未接続';
  SQLToolbar := TPanel.Create(Self);
  SQLToolbar.Parent := FSQLWindow;
  SQLToolbar.Align := alTop;
  SQLToolbar.Height := 46;
  SQLTools:=TToolBar.Create(Self);SQLTools.Parent:=SQLToolbar;SQLTools.Align:=alLeft;
  {$if declared(tboHorizontal)}
  SQLTools.Orientation:=tboHorizontal;
  {$endif}
  SQLTools.Wrapable:=False;
  SQLTools.Flat:=True;SQLTools.ShowCaptions:=False;SQLTools.ShowHint:=True;
  SQLTools.ButtonWidth:=34;SQLTools.ButtonHeight:=36;SQLTools.Height:=44;
  SQLTools.Images:=FToolbarImages;
  FPreviousQueryTool:=SQLTool('前のクエリ',icPreviousQuery,@PreviousQuery);
  FNextQueryTool:=SQLTool('次のクエリ',icNextQuery,@NextQuery);ToolDivider(SQLTools);
  FPreviousQueryTool.Style:=tbsDropDown;
  FNextQueryTool.Style:=tbsDropDown;
  FPreviousQueryTool.DropDownMenu:=TPopupMenu.Create(Self);
  FNextQueryTool.DropDownMenu:=TPopupMenu.Create(Self);
  FPreviousQueryTool.DropDownMenu.OnPopup:=@HistoryPopup;
  FNextQueryTool.DropDownMenu.OnPopup:=@HistoryPopup;
  SQLTool('SQL実行 (Ctrl+E)',icTrigger,@ExecuteClick);
  SQLTool('前処理（実行計画を表示）',icPlan,@PrepareSQL);
  FFetchAllTool:=SQLTool('全件取得',icFetchAll,@FetchAllClick);
  FFetchAllTool.Style:=tbsCheck;FFetchAllTool.Grouped:=False;
  ToolDivider(SQLTools);
  SQLTool('コミット',icCommit,@CommitClick);SQLTool('ロールバック',icRollback,@RollbackClick);
  ToolDivider(SQLTools);SQLTool('開く…',icOpen,@LoadSQL);SQLTool('保存…',icSave,@SaveSQL);
  SQLTool('検索',icSearch,@FindSQLText);
  ToolDivider(SQLTools);SQLTool('CSV出力',icExport,@ExportClick);
  SQLWindowButton:=SQLTool('ウィンドウ切替',icForm,@OpenSQL);
  SQLWindowButton.Style:=tbsDropDown;SQLWindowButton.DropDownMenu:=FWindowMenu;
  SQLWindowButton.OnClick:=@SwitchSQLWindow;
  SQLTool('SQLを印刷…',icPrint,@PrintSQL);
  SQLTools.AutoSize:=True;
  FUseParams:=TCheckBox.Create(Self);
  FUseParams.Parent:=SQLToolbar;
  FUseParams.Caption:='パラメータを使用する';
  FUseParams.Checked:=True;
  FUseParams.Left:=SQLTools.Width+1;
  FUseParams.Align:=alLeft;
  FReturnsRows := TCheckBox.Create(Self);
  FReturnsRows.Parent := SQLToolbar;
  FReturnsRows.Left:=FUseParams.Left+FUseParams.Width+1;
  FReturnsRows.Align:=alLeft;
  FReturnsRows.Caption := '結果を返すSQL（SELECT / RETURNING）';
  FReturnsRows.Checked := True;
  UpdateQueryHistoryButtons;

  SQLBody:=TPanel.Create(Self);SQLBody.Parent:=FSQLWindow;SQLBody.Align:=alClient;
  SQLBody.BevelOuter:=bvNone;
  SQLLeft:=TPanel.Create(Self);SQLLeft.Parent:=SQLBody;SQLLeft.Align:=alLeft;
  SQLLeft.Width:=190;SQLLeft.BevelOuter:=bvNone;
  SQLSplit:=TSplitter.Create(Self);SQLSplit.Parent:=SQLBody;SQLSplit.Align:=alLeft;
  SQLSplit.MinSize:=150;
  SQLRight:=TPanel.Create(Self);SQLRight.Parent:=SQLBody;SQLRight.Align:=alClient;
  SQLRight.BevelOuter:=bvNone;

  CatalogPanel:=TPanel.Create(Self);CatalogPanel.Parent:=SQLLeft;
  CatalogPanel.Align:=alTop;CatalogPanel.Height:=285;CatalogPanel.BevelOuter:=bvNone;
  FSQLCatalog:=TListBox.Create(Self);FSQLCatalog.Parent:=CatalogPanel;
  FSQLCatalog.Align:=alClient;FSQLCatalog.OnClick:=@SQLCatalogClick;
  FSQLCatalog.OnDblClick:=@AddSQLTable;
  B:=TButton.Create(Self);B.Parent:=CatalogPanel;B.Align:=alBottom;B.Height:=28;
  B.Caption:='テーブルを追加';B.OnClick:=@AddSQLTable;
  FieldsPanel:=TPanel.Create(Self);FieldsPanel.Parent:=SQLLeft;
  FieldsPanel.Align:=alClient;FieldsPanel.BevelOuter:=bvNone;
  FSQLFields:=TListBox.Create(Self);FSQLFields.Parent:=FieldsPanel;
  FSQLFields.Align:=alClient;FSQLFields.OnDblClick:=@AddSQLField;
  B:=TButton.Create(Self);B.Parent:=FieldsPanel;B.Align:=alBottom;B.Height:=28;
  B.Caption:='フィールドを追加';B.OnClick:=@AddSQLField;
  L:=TLabel.Create(Self);L.Parent:=FieldsPanel;L.Align:=alTop;L.Height:=20;
  L.Caption:='  フィールド';
  FUseTableAlias:=TCheckBox.Create(Self);FUseTableAlias.Parent:=FieldsPanel;
  FUseTableAlias.Align:=alTop;FUseTableAlias.Height:=25;
  FUseTableAlias.Caption:='テーブル別名を使用';
  FUseTableAlias.OnClick:=@UpdateBuilderSQL;

  FSQLTabs:=TPageControl.Create(Self);FSQLTabs.Parent:=SQLRight;
  FSQLTabs.Align:=alTop;FSQLTabs.Height:=260;
  FBuilderSheet:=TTabSheet.Create(Self);FBuilderSheet.PageControl:=FSQLTabs;
  FBuilderSheet.Caption:='クエリビルダー';
  FSQLSheet:=TTabSheet.Create(Self);FSQLSheet.PageControl:=FSQLTabs;
  FSQLSheet.Caption:='SQL';
  FBuilderGrid:=TStringGrid.Create(Self);FBuilderGrid.Parent:=FBuilderSheet;
  FBuilderGrid.Align:=alClient;FBuilderGrid.FixedRows:=1;FBuilderGrid.FixedCols:=0;
  FBuilderGrid.ColCount:=7;FBuilderGrid.RowCount:=2;
  FBuilderGrid.Options:=FBuilderGrid.Options+[goColSizing,goEditing,goRowSelect];
  FBuilderGrid.Cells[0,0]:='カラム';FBuilderGrid.Cells[1,0]:='別名';
  FBuilderGrid.Cells[2,0]:='テーブル';FBuilderGrid.Cells[3,0]:='表示';
  FBuilderGrid.Cells[4,0]:='ソート';FBuilderGrid.Cells[5,0]:='関数';
  FBuilderGrid.Cells[6,0]:='グループ';
  FBuilderGrid.ColWidths[0]:=190;FBuilderGrid.ColWidths[1]:=130;
  FBuilderGrid.ColWidths[2]:=150;FBuilderGrid.ColWidths[3]:=55;
  FBuilderGrid.ColWidths[4]:=85;FBuilderGrid.ColWidths[5]:=110;
  FBuilderGrid.ColWidths[6]:=85;
  FBuilderGrid.OnSetEditText:=@BuilderGridChanged;

  FSQL := TMemo.Create(Self);
  FSQL.Parent := FSQLSheet;
  FSQL.Align := alClient;
  FSQL.ScrollBars := ssBoth;
  FSQL.WordWrap := False;
  FSQL.Font.Name := 'Consolas';
  FSQL.OnChange:=@SQLChanged;
  FSQLTabs.ActivePage:=FSQLSheet;
  FSQLWindow.ActiveControl:=FSQL;
  QuerySplit:=TSplitter.Create(Self);QuerySplit.Parent:=SQLRight;
  QuerySplit.Align:=alTop;QuerySplit.MinSize:=140;
  FResultTabs:=TPageControl.Create(Self);FResultTabs.Parent:=SQLRight;
  FResultTabs.Align:=alClient;
  FDataSheet:=TTabSheet.Create(Self);FDataSheet.PageControl:=FResultTabs;
  FDataSheet.Caption:='データ';
  FPlanSheet:=TTabSheet.Create(Self);FPlanSheet.PageControl:=FResultTabs;
  FPlanSheet.Caption:='計画';
  FStatsSheet:=TTabSheet.Create(Self);FStatsSheet.PageControl:=FResultTabs;
  FStatsSheet.Caption:='統計';
  FErrorsSheet:=TTabSheet.Create(Self);FErrorsSheet.PageControl:=FResultTabs;
  FErrorsSheet.Caption:='SQLエラー／ログ';
  FGrid := TStringGrid.Create(Self);
  FGrid.Parent := FDataSheet;
  FGrid.Align := alClient;
  FGrid.FixedCols := 0;
  FGrid.FixedRows := 1;
  FGrid.ColCount := 1;
  FGrid.RowCount := 2;
  FGrid.DefaultColWidth := 180;
  FGrid.Options := FGrid.Options + [goColSizing, goRowSelect];
  FGrid.Cells[0, 0] := '実行結果（最大1000行）';
  FSQLPlan:=TMemo.Create(Self);FSQLPlan.Parent:=FPlanSheet;
  FSQLPlan.Align:=alClient;FSQLPlan.ReadOnly:=True;FSQLPlan.WordWrap:=False;
  FSQLPlan.Lines.Text:='「前処理」で現在のSQLの実行計画を表示します。';
  FSQLStats:=TMemo.Create(Self);FSQLStats.Parent:=FStatsSheet;
  FSQLStats.Align:=alClient;FSQLStats.ReadOnly:=True;FSQLStats.WordWrap:=False;
  FSQLLog:=TMemo.Create(Self);FSQLLog.Parent:=FErrorsSheet;
  FSQLLog.Align:=alClient;FSQLLog.ReadOnly:=True;
  FSQLLog.WordWrap:=False;FSQLLog.ScrollBars:=ssAutoBoth;

  ApplyModernTheme(Self);
  ApplyModernTheme(FSQLWindow);
  FHeading.Font.Size:=12;FHeading.Font.Style:=[fsBold];

  I := TIniFile.Create(FConfig);
  try
    I.ReadSections(FProfiles);
  finally
    I.Free;
  end;
  if FProfiles.Count > 0 then ReadProfile(FProfiles[0], FSettings);
  FObjects.OnChange := @TreeChanged;
  RebuildTree;
  Log('接続先を選んで「接続」。SQLは「対話型SQL」で別ウィンドウに開きます。');
  UpdateStatus;
end;

destructor TConsoleForm.Destroy;
begin
  FreeAndNil(FRemainingRows);
  if Assigned(FServerSession) then FreeAndNil(FServerSession);
  if Assigned(FObjects) then FObjects.OnChange := nil;
  if Assigned(FTables) then
  begin
    while FTables.Count>0 do begin TObject(FTables[0]).Free; FTables.Delete(0); end;
    FTables.Free;
  end;
  FProfiles.Free;
  FQueryHistory.Free;
  FBuilderTables.Free;
  inherited Destroy;
end;

procedure TConsoleForm.Log(const S: string);
var Line: string;
begin
  Line := FormatDateTime('hh:nn:ss', Now) + '  ' + S;
  FLog.Lines.Add(Line);
  FSQLLog.Lines.Add(Line);
end;

procedure TConsoleForm.UpdateStatus;
begin
  Caption:='FBConsole — Firebird 5 / 0.3.79';
  if FConnection.Connected then Caption:=FSettings.Name+' — '+Caption;
  if Parent is TTabSheet then begin
    if FConnection.Connected then TTabSheet(Parent).Caption:=FSettings.Name
    else TTabSheet(Parent).Caption:='未接続';
    ConsoleHost.PageChanged(nil);
  end;
  if not FConnection.Connected then FStatus.SimpleText := '未接続'
  else if FPending then FStatus.SimpleText := '接続中 / 未確定のSQLあり — コミットまたはロールバックしてください'
  else FStatus.SimpleText := UTF8Encode('接続中 / ') + FConnection.DatabaseName;
  if FConnection.Connected then
    FSQLWindow.Caption := UTF8Encode('対話型SQL — ') + FSettings.Name + ' / ' + ServerLabel(FSettings)
  else FSQLWindow.Caption := UTF8Encode('対話型SQL — 未接続');
  if not FConnection.Connected then FSQLStatus.SimpleText:='未接続'
  else FSQLStatus.SimpleText:=FConnection.DatabaseName;
  FStatus.Panels[0].Text:=UTF8Encode('サーバー: ')+ServerLabel(FSettings);
  FStatus.Panels[1].Text:=UTF8Encode('データベース: ')+FSettings.Name;
  FStatus.Panels[2].Text:=UTF8Encode('ユーザー: ')+FSettings.UserName;
  if (FProfiles.Count=0) and not FConnection.Connected then begin
    FStatus.Panels[0].Text:='サーバー: ';FStatus.Panels[1].Text:='データベース: ';FStatus.Panels[2].Text:='ユーザー: ';
  end;
  if FPending then FStatus.Panels[3].Text:='未確定のSQLあり'
  else if FConnection.Connected then FStatus.Panels[3].Text:='接続中' else FStatus.Panels[3].Text:='未接続';
  UpdateToolbarState;
end;

procedure TConsoleForm.UpdateDBMenus(Sender:TObject);
var N:TTreeNode;S:TConnectionSettings;HasServer,HasDB,Online,Services:Boolean;
begin
  N:=FObjects.Selected;
  while (N<>nil) and (PtrUInt(N.Data)<>200) and (PtrUInt(N.Data)<>300) do N:=N.Parent;
  HasServer:=(N<>nil) and SelectedConnectionSettings(S);
  HasDB:=False;Online:=False;
  if HasServer then begin
    HasDB:=(PtrUInt(N.Data) in [200,300]) and (S.Database<>'');
    Online:=HasDB and (PtrUInt(N.Data)=200) and FConnection.Connected and SameText(FSettings.Name,S.Name);
  end;
  Services:=HasServer and (S.Mode<>cmConnectionString);
  FDBMenus[dcUnregister].Enabled:=False;
  if HasDB then
    FDBMenus[dcUnregister].Enabled:=(PtrUInt(N.Data)=200) and (N=FObjects.Selected) and (FProfiles.IndexOf(S.Name)>=0);
  FDBMenus[dcConnect].Enabled:=HasDB and not Online;
  FDBMenus[dcConnectAs].Enabled:=HasDB;
  FDBMenus[dcDisconnect].Enabled:=Online;
  FDBMenus[dcCreate].Enabled:=Services;
  FDBMenus[dcDrop].Enabled:=HasDB and Services;
  FDBMenus[dcMaintenance].Enabled:=Online;
  FDBMenus[dcMaintenance].Items[1].Enabled:=Services;
  FDBMenus[dcMaintenance].Items[2].Enabled:=Services;
  FDBMenus[dcBackupRestore].Enabled:=Online and Services;
  FDBMenus[dcMetadata].Enabled:=Online;FDBMenus[dcUsers].Enabled:=Online;FDBMenus[dcProperties].Enabled:=Online;
end;

procedure TConsoleForm.UpdateToolbarState;
begin
  UpdateDBMenus(nil);
  FConnectTool.Enabled:=FDBMenus[dcConnect].Enabled;
  FDisconnectTool.Enabled:=FDBMenus[dcDisconnect].Enabled;
  FCreateTool.Enabled:=FDBMenus[dcCreate].Enabled;
  FServerLoginTool.Enabled:=FCreateTool.Enabled and not FServerSession.IsLoggedIn;
  FServerLogoutTool.Enabled:=FServerSession.IsLoggedIn;
end;

procedure TConsoleForm.RequireConnection;
begin
  if not FConnection.Connected then
    raise Exception.Create('先にデータベースへ接続してください。');
end;

function TConsoleForm.NewQuery: TSQLQuery;
begin
  Result := TSQLQuery.Create(nil);
  Result.Database := FConnection;
  Result.Transaction := FTransaction;
  Result.ReadOnly := True;
  Result.ParamCheck := False;
end;

constructor TConsoleHost.Create(AOwner:TComponent);
var Divider:TSplitter;
begin
  inherited CreateNew(AOwner);
  Caption:='FBConsole — Firebird 5 / 0.3.79';
  SetBounds(60,40,1220,820);
  Position:=poScreenCenter;
  Constraints.MinWidth:=900;
  Constraints.MinHeight:=580;
  Explorer:=TTreeView.Create(Self);
  Explorer.Parent:=Self;
  Explorer.Align:=alLeft;
  Explorer.Width:=440;
  Explorer.ReadOnly:=True;
  Explorer.HideSelection:=False;
  Explorer.OnSelectionChanged:=@ExplorerChanged;
  Explorer.OnMouseDown:=@ExplorerMouse;
  Explorer.OnDblClick:=@ExplorerOpen;
  Divider:=TSplitter.Create(Self);
  Divider.Parent:=Self;
  Divider.Align:=alLeft;
  Divider.Left:=Explorer.Width;
  Divider.ResizeControl:=Explorer;
  Pages:=TPageControl.Create(Self);
  Pages.ShowTabs:=False;
  Pages.Parent:=Self;
  Pages.Align:=alClient;
  Pages.OnChange:=@PageChanged;
  OnCloseQuery:=@CheckSessions;
end;

function MatchingNode(Tree:TTreeView; Source:TTreeNode; CreateMissing:Boolean):TTreeNode;
var ParentNode:TTreeNode;
begin
  Result:=nil;
  if Source=nil then Exit;
  ParentNode:=nil;
  if Source.Parent<>nil then begin
    ParentNode:=MatchingNode(Tree,Source.Parent,CreateMissing);
    if ParentNode=nil then Exit;
    Result:=ParentNode.GetFirstChild;
  end else Result:=Tree.Items.GetFirstNode;
  while Result<>nil do begin
    if (Result.Data=Source.Data) and (Result.Text=Source.Text) then Exit;
    Result:=Result.GetNextSibling;
  end;
  if CreateMissing then begin
    Result:=Tree.Items.AddChild(ParentNode,Source.Text);
    Result.Data:=Source.Data;
  end;
end;

procedure TConsoleHost.QueueRefresh;
begin
  if RefreshQueued or (csDestroying in ComponentState) then Exit;
  RefreshQueued:=True;
  Application.QueueAsyncCall(@RefreshExplorer,0);
end;

procedure TConsoleHost.RefreshExplorer(Data:PtrInt);
var I:Integer; Session,ActiveSession:TConsoleForm; Source,Dest:TTreeNode;
begin
  RefreshQueued:=False;
  if Pages.ActivePage=nil then Exit;
  ActiveSession:=TConsoleForm(Pages.ActivePage.Controls[0]);
  FExplorerBusy:=True;
  Explorer.Items.BeginUpdate;
  try
    Explorer.Items.Clear;
    for I:=0 to Pages.PageCount-1 do begin
      Session:=TConsoleForm(Pages.Pages[I].Controls[0]);
      Source:=Session.FObjects.Items.GetFirstNode;
      while Source<>nil do begin
        Dest:=MatchingNode(Explorer,Source,True);
        if (Dest.ImageIndex<0) or (Source.ImageIndex in [icServer,icDatabase]) then begin
          Dest.ImageIndex:=Source.ImageIndex;
          Dest.SelectedIndex:=Source.SelectedIndex;
        end;
        Source:=Source.GetNext;
      end;
    end;
    for I:=0 to Pages.PageCount-1 do begin
      Session:=TConsoleForm(Pages.Pages[I].Controls[0]);
      Source:=Session.FObjects.Items.GetFirstNode;
      while Source<>nil do begin
        if Source.Expanded then MatchingNode(Explorer,Source,False).Expand(False);
        Source:=Source.GetNext;
      end;
    end;
    Explorer.Selected:=MatchingNode(Explorer,ActiveSession.FObjects.Selected,False);
  finally
    Explorer.Items.EndUpdate;
    FExplorerBusy:=False;
  end;
end;

procedure TConsoleHost.ExplorerChanged(Sender:TObject);
var I,Score,BestScore:Integer; Page,Best:TTabSheet; Session:TConsoleForm;
    Local,Chosen,DBNode,Node:TTreeNode;
begin
  Node:=Explorer.Selected;
  if FExplorerBusy or (Node=nil) then Exit;
  Best:=nil; Chosen:=nil; BestScore:=-1;
  DBNode:=Node;
  while (DBNode<>nil) and (PtrUInt(DBNode.Data)<>200) do DBNode:=DBNode.Parent;
  for I:=0 to Pages.PageCount-1 do begin
    Page:=Pages.Pages[I];
    Session:=TConsoleForm(Page.Controls[0]);
    Local:=MatchingNode(Session.FObjects,Node,False);
    if Local=nil then Continue;
    Score:=Ord(Page=Pages.ActivePage);
    if (DBNode<>nil) and Session.FConnection.Connected and
      SameText(Session.FSettings.Name,DBNode.Text) then Inc(Score,8);
    if (DBNode=nil) and Session.FServerSession.IsLoggedIn and
      (Session.FServerSession.Matches(Session.FSettings)) and
      (Node.Text=TreeServerLabel(Session.FSettings)) then Inc(Score,4);
    if Score>BestScore then begin Best:=Page;Chosen:=Local;BestScore:=Score;end;
  end;
  if Best=nil then Exit;
  FExplorerBusy:=True;
  try
    Pages.ActivePage:=Best;
    Session:=TConsoleForm(Best.Controls[0]);
    Session.FObjects.Selected:=Chosen;
    Session.TreeChanged(nil,Chosen);
    PageChanged(nil);
  finally FExplorerBusy:=False;end;
end;

procedure TConsoleHost.ExplorerOpen(Sender:TObject);
begin
  if Pages.ActivePage<>nil then TConsoleForm(Pages.ActivePage.Controls[0]).BrowseObject(nil);
end;

procedure TConsoleHost.ExplorerMouse(Sender:TObject;Button:TMouseButton;Shift:TShiftState;X,Y:Integer);
var Node:TTreeNode;
begin
  if Button=mbRight then begin
    Node:=Explorer.GetNodeAt(X,Y);
    if Node<>nil then Explorer.Selected:=Node;
  end;
end;

destructor TConsoleHost.Destroy;
begin
  Application.RemoveAsyncCalls(Self);
  if Assigned(Explorer) then begin Explorer.OnSelectionChanged:=nil;Explorer.Images:=nil;Explorer.PopupMenu:=nil;end;
  if Assigned(Pages) then Pages.OnChange:=nil;
  Menu:=nil;
  inherited Destroy;
end;

procedure TConsoleHost.CheckLibrary(const LibraryPath:string);
var I:Integer; Session:TConsoleForm;
begin
  for I:=0 to Pages.PageCount-1 do begin
    Session:=TConsoleForm(Pages.Pages[I].Controls[0]);
    if Session.FLoader.Enabled and
       (not SameFileName(ExpandFileName(Session.FLoader.LibraryName),ExpandFileName(LibraryPath))) and
       (Session.FConnection.Connected or Session.FServerSession.IsLoggedIn) then
      raise Exception.Create('同時接続では同じFirebirdクライアントライブラリを指定してください。');
  end;
end;

function TConsoleHost.AddSession:TConsoleForm;
var Page:TTabSheet; I:Integer;
begin
  Page:=TTabSheet.Create(Pages);
  try
    Page.Caption:='未接続';
    Result:=TConsoleForm.Create(Page);
    Result.Menu:=nil;
    Result.BorderStyle:=bsNone;
    Result.Parent:=Page;
    Result.FObjects.Visible:=False;
    for I:=0 to Result.ControlCount-1 do
      if Result.Controls[I] is TSplitter then Result.Controls[I].Visible:=False;
    Result.Align:=alClient;
    Page.PageControl:=Pages;
    Pages.ActivePage:=Page;
    Result.Show;
    PageChanged(nil);
    QueueRefresh;
  except
    Page.Free;
    raise;
  end;
end;

function TConsoleHost.SessionForConnection:TConsoleForm;
var I:Integer;
begin
  for I:=0 to Pages.PageCount-1 do begin
    Result:=TConsoleForm(Pages.Pages[I].Controls[0]);
    if not Result.FConnection.Connected and not Result.FServerSession.IsLoggedIn then begin
      Pages.ActivePageIndex:=I;
      PageChanged(nil);
      Exit;
    end;
  end;
  Result:=AddSession;
end;

procedure TConsoleHost.PageChanged(Sender:TObject);
var Session:TConsoleForm;
begin
  if (Pages.ActivePage=nil) or (Pages.ActivePage.ControlCount=0) then Exit;
  Session:=TConsoleForm(Pages.ActivePage.Controls[0]);
  if ActiveBar<>Session.FConnectTool.Parent then begin
    if Assigned(ActiveBar) then ActiveBar.Parent:=TConsoleForm(ActiveBar.Owner);
    ActiveBar:=TToolBar(Session.FConnectTool.Parent);
    ActiveBar.Parent:=Self;
    ActiveBar.Align:=alTop;
  end;
  Explorer.Images:=Session.FImages;
  Explorer.PopupMenu:=Session.FObjects.PopupMenu;
  Menu:=Session.FSessionMenu;
  Caption:=Session.Caption;
end;

procedure TConsoleHost.CheckSessions(Sender:TObject;var CanClose:Boolean);
var I:Integer; Session:TConsoleForm;
begin
  for I:=0 to Pages.PageCount-1 do begin
    Session:=TConsoleForm(Pages.Pages[I].Controls[0]);
    if Session.FPending or (Session.FTables.Count>0) then begin
      Pages.ActivePageIndex:=I;
      PageChanged(nil);
      if not Session.EndSession then begin CanClose:=False; Exit;end;
    end;
  end;
  CanClose:=True;
end;

procedure TConsoleHost.RemoveTab(Data:PtrInt);
var Page:TTabSheet; I:Integer;
begin
  for I:=0 to Pages.PageCount-1 do begin
    Page:=Pages.Pages[I];
    if PtrInt(Page)<>Data then Continue;
    if not TConsoleForm(Page.Controls[0]).EndSession then Exit;
    if Pages.PageCount=1 then AddSession;
    Menu:=nil;
    Page.Free;
    PageChanged(nil);
    Exit;
  end;
end;

procedure TConsoleForm.NewSessionWindow(Sender:TObject);
begin
  ConsoleHost.AddSession;
end;

procedure TConsoleForm.CloseSessionTab(Sender:TObject);
begin
  if Parent is TTabSheet then
    Application.QueueAsyncCall(@ConsoleHost.RemoveTab,PtrInt(Parent));
end;

procedure TConsoleForm.OpenRegisteredSession(const ProfileName:string);
var S:TConnectionSettings; UserName,Role,Password:string;
begin
  if FProfiles.IndexOf(ProfileName)<0 then begin
    MessageDlg('接続設定が見つかりません: '+ProfileName,mtError,[mbOK],0);
    Exit;
  end;
  ReadProfile(ProfileName,S);
  if S.Database='' then begin EditConnection(S);Exit;end;
  UserName:=S.UserName;Role:=S.Role;Password:='';
  try
    if not AskLogin(Self,ServerLabel(S),UserName,Role,Password,True) then Exit;
    S.UserName:=UserName;S.Role:=Role;
    ConnectTo(S,Password);
  finally Password:='';end;
end;

procedure TConsoleForm.ConnectClick(Sender: TObject);
var Candidate: TConnectionSettings; N: TTreeNode; Password,UserName,Role:string; I:Integer; Login:TServerSession;
begin
  Candidate := FSettings;
  N := FObjects.Selected;
  while (N <> nil) and (PtrUInt(N.Data) <> 200) and (PtrUInt(N.Data) <> 300) do N := N.Parent;
  if (N<>nil) and (PtrUInt(N.Data)=300) then begin
    if not SelectedConnectionSettings(Candidate) then Candidate:=FSettings;
    if Candidate.Database='' then begin EditConnection(Candidate);Exit;end;
    N:=nil;
  end;
  if (N <> nil) and (N.Text <> FSettings.Name) and (FProfiles.IndexOf(N.Text) >= 0) then
    ReadProfile(N.Text, Candidate);
  if ((Sender=FDBMenus[dcConnect]) or (Sender=FConnectTool)) and (N<>nil) and (FProfiles.IndexOf(N.Text)>=0) then ReadProfile(N.Text,Candidate);
  if FConnection.Connected and SameText(Candidate.Name,FSettings.Name) and
     (Sender<>FDBMenus[dcConnectAs]) then begin OpenSQL(nil);Exit;end;
  if Candidate.Database='' then begin
    if FConnection.Connected then ConsoleHost.SessionForConnection.EditConnection(Candidate)
    else EditConnection(Candidate);
    Exit;
  end;
  Password:='';UserName:=Candidate.UserName;Role:=Candidate.Role;
  try
    Login:=FServerSession;
    if Assigned(ConsoleHost) then
      for I:=0 to ConsoleHost.Pages.PageCount-1 do begin
        Login:=TConsoleForm(ConsoleHost.Pages.Pages[I].Controls[0]).FServerSession;
        if Login.Matches(Candidate) then Break;
      end;
    if (Sender<>FDBMenus[dcConnectAs]) and Login.GetLoginCredentials(Candidate,UserName,Password,Role) then begin
      Candidate.UserName:=UserName;Candidate.Role:=Role;
    end else begin
      if not AskLogin(Self,ServerLabel(Candidate),UserName,Role,Password,Sender<>FDBMenus[dcConnect]) then Exit;
      Candidate.UserName:=UserName;Candidate.Role:=Role;
    end;
    ConnectAdditional(Candidate,Password);
  finally Password:='';UserName:='';Role:='';end;
end;

procedure TConsoleForm.ConnectAdditional(const Candidate:TConnectionSettings;const Password:string);
begin
  if FConnection.Connected then ConsoleHost.SessionForConnection.ConnectTo(Candidate,Password)
  else ConnectTo(Candidate,Password);
end;

procedure TConsoleForm.ConnectDatabaseClick(Sender:TObject);
begin ConnectClick(FDBMenus[dcConnect]);end;

procedure TConsoleForm.ConnectDatabaseAsClick(Sender:TObject);
begin ConnectClick(FDBMenus[dcConnectAs]);end;

procedure TConsoleForm.EditConnection(const InitialSettings: TConnectionSettings);
var D: TConnectionDialog; Candidate: TConnectionSettings; Password: string;
    Save: Boolean;
begin
  Candidate := InitialSettings;
  D := TConnectionDialog.Create(Self);
  try
    if not D.Execute(Candidate, Password, Save) then Exit;
    if FConnection.Connected and (not EndSession) then Exit;
    if Save then
    begin
      WriteSettings(FConfig, Candidate);
      if FProfiles.IndexOf(Candidate.Name) < 0 then FProfiles.Add(Candidate.Name);
    end;
    ConnectTo(Candidate, Password);
  finally
    Password := '';
    D.Free;
  end;
end;

procedure TConsoleForm.ConnectTo(const Settings: TConnectionSettings; const Password: string);
var K:Integer;
begin
  if FServerSession.IsLoggedIn and not SameText(ExpandFileName(FLoader.LibraryName),ExpandFileName(Settings.ClientLibrary)) then
    raise Exception.Create('サーバーへログイン中です。クライアントライブラリを変更する前にログアウトしてください。');
  FSettings := Settings;
  try
    if not FileExists(FSettings.ClientLibrary) then
      raise Exception.Create('Firebird 5のクライアントライブラリをフルパスで指定してください。');
    FLoader.Enabled := False;
    if Assigned(ConsoleHost) then ConsoleHost.CheckLibrary(FSettings.ClientLibrary);
    FLoader.LibraryName := FSettings.ClientLibrary;
    FLoader.Enabled := True;
    FConnection.HostName := '';
    FConnection.DatabaseName := ConnectionString(FSettings);
    FConnection.UserName := FSettings.UserName;
    FConnection.Password := Password;
    FConnection.Role := FSettings.Role;
    FConnection.CharSet := 'UTF8';
    FConnection.Dialect := 3;
    FConnection.Open;
    FConnection.Password := '';
    ConfigureFirebird5(FConnection, FTransaction);
    FBuilderTables.Clear;
    FBuilderGrid.RowCount:=2;
    for K:=0 to FBuilderGrid.ColCount-1 do
      FBuilderGrid.Cells[K,1]:='';
    Log('Firebird 5へ接続しました。新データ型は文字列として取得します。');
    RefreshObjects(nil);
    PopulateSQLCatalog;
  except
    on E: Exception do
    begin
      if FTransaction.Active then FTransaction.Rollback;
      FConnection.Close;
      FConnection.Password := '';
      Log(UTF8Encode('接続失敗: ') + E.Message);
      RebuildTree;
    end;
  end;
  UpdateStatus;
end;

function TConsoleForm.EndSession: Boolean;
var K:Integer;
begin
  Result := False;
  for K:=0 to FTables.Count-1 do
    if not TTableWindow(FTables[K]).PrepareClose then Exit;
  if FPending and (MessageDlg('未確定のSQL',
    '未確定の変更をロールバックして切断しますか？', mtConfirmation,
    [mbYes, mbNo], 0) <> mrYes) then Exit;
  FreeAndNil(FRemainingRows);
  while FTables.Count>0 do begin TObject(FTables[0]).Free;FTables.Delete(0);end;
  if FTransaction.Active then FTransaction.Rollback;
  FConnection.Close;
  FConnection.Password := '';
  FPending := False;
  FBuilderTables.Clear;
  FBuilderGrid.RowCount:=2;
  PopulateSQLCatalog;
  RebuildTree;
  FResultRows := -1;
  FSQLWindow.Hide;
  UpdateStatus;
  Result := True;
end;

procedure TConsoleForm.DisconnectClick(Sender: TObject);
begin
  if EndSession then Log('切断しました。');
end;

procedure TConsoleForm.CloseCheck(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := EndSession;
end;

procedure TConsoleForm.RegisterServerClick(Sender:TObject);
var Settings,Existing:TConnectionSettings;I:Integer;Picker:TOpenDialog;
    Form:TServerRegisterDialog;SaveAlias,LoggedIn:Boolean;Password:string;Temporary:TTemporaryServer;
begin
  Settings:=DefaultSettings;Settings.ClientLibrary:=FSettings.ClientLibrary;
  Password:='';LoggedIn:=False;Form:=TServerRegisterDialog.Create(Self);
  try
    try
      if not Form.Execute(Settings,SaveAlias,Password) then Exit;
      if FProfiles.IndexOf(Settings.Name)>=0 then raise Exception.Create('この登録名は既に使用されています。');
      for I:=0 to FProfiles.Count-1 do begin
        ReadProfile(FProfiles[I],Existing);
        if (Existing.Mode=Settings.Mode) and SameText(Existing.Host,Settings.Host) and
          (Existing.Port=Settings.Port) then raise Exception.Create('同じサーバーが既に登録されています。');
        if SameText(Existing.ServerAlias,Settings.ServerAlias) then raise Exception.Create('このエイリアスは既に使用されています。');
        if (not FileExists(Settings.ClientLibrary)) and FileExists(Existing.ClientLibrary) then Settings.ClientLibrary:=Existing.ClientLibrary;
      end;
      if not FileExists(Settings.ClientLibrary) then begin
        Picker:=TOpenDialog.Create(Self);
        try
          Picker.Title:='Firebirdクライアントライブラリ';Picker.Filter:='Firebird client|fbclient.dll;libfbclient.so*|All files|*';
          if not Picker.Execute then Exit;
          Settings.ClientLibrary:=Picker.FileName;
        finally Picker.Free;end;
      end;
      if Password<>'' then begin
        if FServerSession.IsLoggedIn then raise Exception.Create('先に現在のサーバーからログアウトしてください。');
        if not FConnection.Connected then begin
          if Assigned(ConsoleHost) then ConsoleHost.CheckLibrary(Settings.ClientLibrary);
      FLoader.Enabled:=False;FLoader.LibraryName:=Settings.ClientLibrary;FLoader.Enabled:=True;
        end;
        FServerSession.Login(Settings,Settings.UserName,Password,'');LoggedIn:=True;
      end;
      try
        if SaveAlias then begin
          WriteSettings(FConfig,Settings);FProfiles.Add(Settings.Name);
        end else begin
          Temporary:=TTemporaryServer.Create;Temporary.Settings:=Settings;
          FProfiles.AddObject(Settings.Name,Temporary);
        end;
      except
        if LoggedIn then FServerSession.Logout;
        raise;
      end;
      RebuildTree;
      if LoggedIn then Log('サーバーに登録・接続しました: '+Settings.Name)
      else Log('サーバーを登録しました: '+Settings.Name);
    except on E:Exception do MessageDlg('サーバーの登録と接続',E.Message,mtError,[mbOK],0);end;
  finally Password:='';Form.Free;end;
end;

procedure TConsoleForm.NewConnection(Sender: TObject);
var Candidate: TConnectionSettings; D:TConnectionDialog; Password:string;
    Save:Boolean; I:TIniFile;
begin
  Candidate := DefaultSettings;
  Candidate.ClientLibrary := FSettings.ClientLibrary;
  if (Sender=FDBMenus[dcRegister]) and (FObjects.Selected<>nil) and
     (PtrUInt(FObjects.Selected.Data)<>400) and SelectedConnectionSettings(Candidate) then begin
    Candidate.Name:='';Candidate.Database:='';
  end;
  D:=TConnectionDialog.Create(Self);D.RegistrationMode;Password:='';
  try
    if not D.Execute(Candidate,Password,Save) then Exit;
    if not Save then begin
      MessageDlg('接続先の登録','登録するには「接続設定を保存」を選択してください。',mtInformation,[mbOK],0);
      Exit;
    end;
    I:=TIniFile.Create(FConfig);
    try
      if I.SectionExists(Candidate.Name) and
        (MessageDlg('接続先の上書き','同じ登録名の設定を置き換えますか？',mtConfirmation,[mbYes,mbNo],0)<>mrYes) then Exit;
    finally I.Free;end;
    WriteSettings(FConfig,Candidate);
    if FProfiles.IndexOf(Candidate.Name)<0 then FProfiles.Add(Candidate.Name);
    RebuildTree;
    Log('接続先を登録しました: '+Candidate.Name);
  finally
    Password:='';D.Free;
  end;
end;

procedure TConsoleForm.RegisterDatabaseClick(Sender:TObject);
begin NewConnection(FDBMenus[dcRegister]);end;

procedure TConsoleForm.UnregisterConnection(Sender:TObject);
var N:TTreeNode; ProfileName:string; I:TIniFile; WasCurrent,WholeServer:Boolean;
    Target,Profile:TConnectionSettings;Targets:TStringList;K:Integer;ConfirmText:string;
begin
  N:=FObjects.Selected;
  WholeServer:=(N<>nil) and (PtrUInt(N.Data)=300);
  if WholeServer then begin
    if not SelectedConnectionSettings(Target) then Exit;
    ProfileName:=Target.Name;
  end else begin
    if (N=nil) or (PtrUInt(N.Data)<>200) then begin
      MessageDlg('登録解除','ツリーで登録済みサーバーまたはデータベースを選択してください。',mtInformation,[mbOK],0);
      Exit;
    end;
    ProfileName:=N.Text;
    ReadProfile(ProfileName,Target);
  end;
  Targets:=TStringList.Create;
  I:=TIniFile.Create(FConfig);
  try
    if WholeServer then begin
      for K:=0 to FProfiles.Count-1 do begin
        ReadProfile(FProfiles[K],Profile);
        if (Profile.Mode=Target.Mode) and SameText(Profile.Host,Target.Host) and
           (Profile.Port=Target.Port) and (I.SectionExists(FProfiles[K]) or (FProfiles.Objects[K] is TTemporaryServer)) then Targets.Add(FProfiles[K]);
      end;
    end else if I.SectionExists(ProfileName) then Targets.Add(ProfileName);
    if Targets.Count=0 then begin
      MessageDlg('登録解除','サンプル接続設定、または登録済みの接続設定がありません。',mtInformation,[mbOK],0);
      Targets.Free;Exit;
    end;
  finally I.Free;end;
  ConfirmText:=Targets.Text;
  if WholeServer then ConfirmText:='このサーバーに登録された次の接続設定を解除します:'+LineEnding+ConfirmText
  else ConfirmText:=ProfileName+' の登録を削除しますか？';
  if MessageDlg('サーバーの登録解除',ConfirmText,mtConfirmation,[mbYes,mbNo],0)<>mrYes then begin Targets.Free;Exit;end;
  WasCurrent:=Targets.IndexOf(FSettings.Name)>=0;
  if WasCurrent and FConnection.Connected and not EndSession then begin Targets.Free;Exit;end;
  if FServerSession.IsLoggedIn and FServerSession.Matches(Target) then FServerSession.Logout;
  I:=TIniFile.Create(FConfig);
  try
    for K:=0 to Targets.Count-1 do begin
      I.EraseSection(Targets[K]);FProfiles.Delete(FProfiles.IndexOf(Targets[K]));
    end;
    I.UpdateFile;
  finally I.Free;Targets.Free;end;
  if WasCurrent then begin
    FSettings:=DefaultSettings;
  end;
  RebuildTree;
  Log('サーバー／接続設定の登録を解除しました: '+ProfileName);
end;

procedure TConsoleForm.RefreshTreeImages;
var
  OnlineServers: TStringList;
  Profile: TConnectionSettings;
  Index: Integer;
begin
  OnlineServers := TStringList.Create;
  try
    OnlineServers.CaseSensitive := True;
    if FConnection.Connected then
      OnlineServers.Add(TreeServerLabel(FSettings));
    if FServerSession.IsLoggedIn then
      for Index := 0 to FProfiles.Count - 1 do
      begin
        ReadProfile(FProfiles[Index], Profile);
        if FServerSession.Matches(Profile) then
          OnlineServers.Add(TreeServerLabel(Profile));
      end;
    AssignTreeImages(FObjects, OnlineServers, FConnection.Connected, FSettings.Name);
    if Assigned(ConsoleHost) then ConsoleHost.QueueRefresh;
  finally
    OnlineServers.Free;
  end;
end;

procedure TConsoleForm.RebuildTree;
var Names: TStringList; Root, Server, N, DBNode, Folder, SelectedServer, FirstServer: TTreeNode;
    S: TConnectionSettings; I: Integer; LabelText: string;ServerOnline:Boolean;
begin
  FObjects.OnChange := nil;
  FList.Items.Clear;
  FObjects.Items.BeginUpdate;
  Names := TStringList.Create;
  try
    FObjects.Items.Clear;
    Root := FObjects.Items.Add(nil, 'InterBase/Firebird サーバ');
    Root.Data := Pointer(PtrUInt(400));
    SelectedServer:=nil;FirstServer:=nil;
    Names.Assign(FProfiles);
    if FConnection.Connected and (Names.IndexOf(FSettings.Name)<0) then Names.Add(FSettings.Name);
    for I := 0 to Names.Count - 1 do
    begin
      if Names[I] = FSettings.Name then S := FSettings
      else ReadProfile(Names[I], S);
      LabelText := TreeServerLabel(S);
      Server := nil;
      N := Root.GetFirstChild;
      while N <> nil do
      begin
        if N.Text = LabelText then begin Server := N; Break; end;
        N := N.GetNextSibling;
      end;
      if Server = nil then
      begin
        Server := FObjects.Items.AddChild(Root, LabelText);
        Server.Data := Pointer(PtrUInt(300));
      end;
      if FirstServer=nil then FirstServer:=Server;
      if SameText(S.Name,FSettings.Name) or
        (FServerSession.IsLoggedIn and FServerSession.Matches(S)) then SelectedServer:=Server;
      ServerOnline:=(FConnection.Connected and (S.Mode=FSettings.Mode) and SameText(S.Host,FSettings.Host) and (S.Port=FSettings.Port)) or
        (FServerSession.IsLoggedIn and FServerSession.Matches(S));
      if ServerOnline then begin
        Folder:=Server.GetFirstChild;
        if (Folder=nil) or (PtrUInt(Folder.Data)<>350) then begin
          Folder:=FObjects.Items.AddChild(Server,'データベース');Folder.Data:=Pointer(PtrUInt(350));
          N:=FObjects.Items.AddChild(Server,'バックアップ');N.Data:=Pointer(PtrUInt(501));
          N:=FObjects.Items.AddChild(Server,'サーバーログ');N.Data:=Pointer(PtrUInt(502));
          N:=FObjects.Items.AddChild(Server,'ユーザー');N.Data:=Pointer(PtrUInt(503));
        end;
        if Trim(S.Database)<>'' then begin
          DBNode:=Folder.GetFirstChild;
          while DBNode<>nil do begin
            if (PtrUInt(DBNode.Data)=200) and SameText(DBNode.Text,S.Name) then Break;
            DBNode:=DBNode.GetNextSibling;
          end;
          if DBNode=nil then begin
            DBNode:=FObjects.Items.AddChild(Folder,S.Name);
            DBNode.Data:=Pointer(PtrUInt(200));
          end;
        end;
        Server.Expand(False);
        Folder.Expand(False);
      end;
    end;
    Root.Expand(False);
    if SelectedServer=nil then SelectedServer:=FirstServer;
    if SelectedServer<>nil then FObjects.Selected:=SelectedServer
    else FObjects.Selected:=Root;
  finally
    Names.Free;
    FObjects.Items.EndUpdate;
    FObjects.OnChange := @TreeChanged;
  end;
  RefreshTreeImages;
  TreeChanged(nil, FObjects.Selected);
end;

procedure TConsoleForm.ReadProfile(const AName: string; out Settings: TConnectionSettings);
var Index:Integer;
begin
  Index:=FProfiles.IndexOf(AName);
  if (Index>=0) and (FProfiles.Objects[Index] is TTemporaryServer) then
    Settings:=TTemporaryServer(FProfiles.Objects[Index]).Settings
  else ReadSettings(FConfig,AName,Settings);
end;

procedure TConsoleForm.TreeChanged(Sender: TObject; Node: TTreeNode);
var Child: TTreeNode; Item: TListItem; Kind: PtrUInt;I:Integer;Q:TSQLQuery;
  procedure SetColumns(const Captions: array of string);
  var J: Integer;
  begin
    FList.Columns.BeginUpdate;
    try
      FList.Columns.Clear;
      for J:=Low(Captions) to High(Captions) do begin
        with FList.Columns.Add do begin
          Caption:=Captions[J];
          case J of
            0: Width:=200;
            1: Width:=180;
            else Width:=160;
          end;
        end;
      end;
    finally FList.Columns.EndUpdate;end;
  end;
  procedure AddAction(const Caption,Description:string;Image,ActionID:Integer);
  begin
    Item:=FList.Items.Add;
    Item.Caption:=Caption;
    Item.ImageIndex:=Image;
    Item.Data:=Pointer(PtrUInt(ActionID));
    Item.SubItems.Add(Description);
  end;
  procedure AddNode(N: TTreeNode);
  begin
    Item := FList.Items.Add;
    Item.Caption := N.Text;
    Item.ImageIndex:=N.ImageIndex;
    Item.Data := N;
  end;
begin
  FList.Items.BeginUpdate;
  try
    FList.Items.Clear;
    FListActions:=False;
    if Node = nil then Exit;
    FHeading.Caption := Node.Text;
    Kind:=PtrUInt(Node.Data);
    if Kind=300 then begin
      SetColumns(['アクション','説明']);
      FListActions:=True;
      AddAction('サーバーへログイン','選択したサーバーへログインします',icConnect,14);
      if FServerSession.IsLoggedIn then
        AddAction('サーバーからログアウト','ログイン中のサーバーからログアウトします',icDisconnect,15);
      AddAction('サーバーのプロパティ','サーバーの接続情報と状態を表示します',icProperties,16);
      AddAction('サーバーログ','サーバーのログを表示します',icLog,17);
      AddAction('データベースへ接続','登録済みデータベースへ接続します',icDatabaseConnect,18);
    end else if Kind=200 then begin
      SetColumns(['アクション','説明']);
      FListActions:=True;
      if FConnection.Connected and ActiveSelection then begin
        AddAction('データベースから切断','現在のデータベースから切断します',icDisconnect,1);
        AddAction('データベースの統計','データベースの統計情報を表示します',icProperties,3);
        AddAction('データベースのスイープ','データベースのスイープを実行します',icRefresh,8);
        AddAction('バックアップ','データベースをバックアップします',icBackup,6);
        AddAction('リストア','バックアップからデータベースを復元します',icRestore,7);
        AddAction('メタデータの表示','データベースのメタデータを表示します',icLog,10);
        AddAction('接続中のユーザー','現在のデータベースに接続しているユーザーを表示します',icUsers,4);
        AddAction('対話型SQL','SQLを入力して実行します',icSQL,5);
        AddAction('データベースのプロパティ','データベースのプロパティを表示します',icProperties,2);
      end else begin
        AddAction('データベースへ接続','選択したデータベースへ接続します',icDatabaseConnect,11);
        AddAction('データベースの登録解除','登録済みデータベースの接続設定を削除します',icDatabaseOffline,12);
        AddAction('データベースの削除','サーバー上のデータベースを削除します',icDatabaseOffline,13);
        AddAction('データベースのプロパティ','データベースの接続設定を表示します',icProperties,2);
      end;
    end else if (Kind=503) and FConnection.Connected and ActiveSelection then begin
      SetColumns(['ユーザー名','名','ミドルネーム','姓']);
      Q:=NewQuery;
      try
        Q.SQL.Text:='SELECT SEC$USER_NAME, SEC$FIRST_NAME, SEC$MIDDLE_NAME, SEC$LAST_NAME FROM SEC$USERS ORDER BY SEC$USER_NAME';
        Q.Open;
        while not Q.EOF do begin
          Item:=FList.Items.Add;Item.Caption:=Trim(Q.Fields[0].AsString);
          Item.ImageIndex:=icUsers;
          for I:=1 to 3 do Item.SubItems.Add(Trim(Q.Fields[I].AsString));
          Q.Next;
        end;
      finally Q.Free;end;
    end else if (Kind=11) and (FObjects.Selected<>nil) then begin
      SetColumns(['ルーチン名','種類']);
      Child:=Node.GetFirstChild;
      while Child<>nil do begin
        Item:=FList.Items.Add;
        Item.Caption:=Child.Text;
        Item.ImageIndex:=icFunction;
        if PtrUInt(Child.Data)=13 then Item.SubItems.Add('関数')
        else Item.SubItems.Add('プロシージャ');
        Item.Data:=Child;
        Child:=Child.GetNextSibling;
      end;
    end else if (Kind=108) and FConnection.Connected and ActiveSelection then begin
      SetColumns(['関数名','モジュール','エンジン','エントリーポイント','説明']);
      FList.Columns[0].Width:=150;
      FList.Columns[1].Width:=180;
      FList.Columns[2].Width:=100;
      FList.Columns[3].Width:=180;
      FList.Columns[4].Width:=300;
      Q:=NewQuery;
      try
        try
          Q.SQL.Text:='SELECT RDB$FUNCTION_NAME, RDB$MODULE_NAME, RDB$ENGINE_NAME, '+
            'RDB$ENTRYPOINT, RDB$DESCRIPTION FROM RDB$FUNCTIONS '+
            'WHERE RDB$PACKAGE_NAME IS NULL AND '+
            '(RDB$MODULE_NAME IS NOT NULL OR RDB$ENGINE_NAME IS NOT NULL)';
          Q.SQL.Add('ORDER BY RDB$FUNCTION_NAME');
          Q.Open;
          while not Q.EOF do begin
            Item:=FList.Items.Add;
            Item.Caption:=TrimRight(Q.Fields[0].AsString);
            Item.ImageIndex:=icFunction;
            for I:=1 to 4 do Item.SubItems.Add(TrimRight(Q.Fields[I].AsString));
            Q.Next;
          end;
        except
          { Preserve navigation even when metadata details cannot be read. }
          FList.Items.Clear;
        end;
        if FList.Items.Count=0 then begin
          SetColumns(['名前']);
          Child:=Node.GetFirstChild;
          while Child<>nil do begin AddNode(Child);Child:=Child.GetNextSibling;end;
        end;
      finally Q.Free;end;
    end else if (Kind>0) and (Kind<100) and (FObjects.Selected.Parent<>nil) then begin
      SetColumns(['アクション','説明']);
      FListActions:=True;
      AddAction('開く','選択したデータベースオブジェクトを開きます',FObjects.Selected.ImageIndex,21);
      AddAction('定義／メタデータを表示','選択したオブジェクトの定義と属性を表示します',icProperties,22);
      AddAction('対話型SQL','SQLを入力して実行します',icSQL,23);
    end else begin
      FListActions:=False;
      SetColumns(['名前']);
      Child := Node.GetFirstChild;
      if Child = nil then begin
        if Kind < 100 then AddNode(Node);
      end else
        while Child <> nil do begin AddNode(Child);Child := Child.GetNextSibling;end;
    end;
  finally
    FList.Items.EndUpdate;
    UpdateToolbarState;
    if Assigned(ConsoleHost) and not ConsoleHost.FExplorerBusy then ConsoleHost.QueueRefresh;
  end;
end;

procedure TConsoleForm.ListOpen(Sender: TObject);
var Node: TTreeNode;
begin
  if FList.Selected = nil then Exit;
  if FListActions then begin ActionOpen(nil);Exit;end;
  Node := TTreeNode(FList.Selected.Data);
  FObjects.Selected := Node;
  BrowseObject(nil);
end;

procedure TConsoleForm.CloseSQLClick(Sender:TObject);
begin
  {$IFDEF LCLQt6}
  TSQLForm(FSQLWindow).RequestHide;
  {$ELSE}
  FSQLWindow.Close;
  {$ENDIF}
end;

procedure TConsoleForm.SQLWindowClosing(Sender:TObject; var ACloseAction:TCloseAction);
begin
  ACloseAction:=caHide;
end;

procedure TConsoleForm.OpenSQL(Sender: TObject);
begin
  FSQLTabs.ActivePage:=FSQLSheet;
  if FSQLWindow.WindowState=wsMinimized then FSQLWindow.WindowState:=wsNormal;
  FSQLWindow.Show;
  FSQLWindow.BringToFront;
  if FSQL.CanFocus then FSQL.SetFocus;
end;

procedure TConsoleForm.PopulateSQLCatalog;
var Q:TSQLQuery;
begin
  FSQLCatalog.Items.BeginUpdate;
  try
    FSQLCatalog.Items.Clear;
    FSQLFields.Items.Clear;
    if not FConnection.Connected then Exit;
    Q:=NewQuery;
    try
      Q.SQL.Text:='SELECT TRIM(RDB$RELATION_NAME) AS RELATION_NAME FROM RDB$RELATIONS';
      if not FSystemDataMenu.Checked then Q.SQL.Add('WHERE COALESCE(RDB$SYSTEM_FLAG,0)=0');
      Q.SQL.Add('ORDER BY RDB$RELATION_NAME');
      Q.Open;
      while not Q.EOF do begin
        FSQLCatalog.Items.Add(TrimRight(Q.Fields[0].AsString));
        Q.Next;
      end;
    finally
      Q.Free;
      if (not FPending) and FTransaction.Active then FTransaction.Rollback;
    end;
    if FSQLCatalog.Count>0 then begin
      FSQLCatalog.ItemIndex:=0;
      SQLCatalogClick(nil);
    end;
  finally
    FSQLCatalog.Items.EndUpdate;
  end;
end;

procedure TConsoleForm.SQLCatalogClick(Sender:TObject);
var Q:TSQLQuery; TableName:string;
begin
  FSQLFields.Items.BeginUpdate;
  try
    try
      FSQLFields.Items.Clear;
      FSQLFields.Items.Add('*');
      if not FConnection.Connected or (FSQLCatalog.ItemIndex<0) then Exit;
      TableName:=FSQLCatalog.Items[FSQLCatalog.ItemIndex];
      Q:=NewQuery;
      try
      Q.SQL.Text:='SELECT TRIM(RDB$FIELD_NAME) AS FIELD_NAME FROM RDB$RELATION_FIELDS '+
        'WHERE RDB$RELATION_NAME='+QuotedStr(TableName)+
        ' ORDER BY RDB$FIELD_POSITION';
      Q.Open;
      while not Q.EOF do begin
        FSQLFields.Items.Add(TrimRight(Q.Fields[0].AsString));
        Q.Next;
      end;
      finally
        Q.Free;
        if (not FPending) and FTransaction.Active then FTransaction.Rollback;
      end;
    except
      on E:Exception do Log('SQLフィールド一覧: '+E.Message);
    end;
  finally
    FSQLFields.Items.EndUpdate;
  end;
end;

procedure TConsoleForm.AddSQLTable(Sender:TObject);
var TableName:string; I:Integer;
begin
  if FSQLCatalog.ItemIndex<0 then Exit;
  TableName:=FSQLCatalog.Items[FSQLCatalog.ItemIndex];
  I:=FBuilderTables.IndexOf(TableName);
  if I<0 then FBuilderTables.Add(TableName);
  SQLCatalogClick(nil);
  UpdateBuilderSQL(nil);
end;

procedure TConsoleForm.AddSQLField(Sender:TObject);
var R:Integer;FieldName,TableName:string;
begin
  if (FSQLCatalog.ItemIndex<0) or (FSQLFields.ItemIndex<0) then Exit;
  TableName:=FSQLCatalog.Items[FSQLCatalog.ItemIndex];
  if FBuilderTables.IndexOf(TableName)<0 then FBuilderTables.Add(TableName);
  FieldName:=FSQLFields.Items[FSQLFields.ItemIndex];
  if (FBuilderGrid.RowCount=2) and (FBuilderGrid.Cells[0,1]='') then R:=1
  else begin R:=FBuilderGrid.RowCount;FBuilderGrid.RowCount:=R+1;end;
  FBuilderGrid.Cells[0,R]:=FieldName;
  FBuilderGrid.Cells[1,R]:='';
  FBuilderGrid.Cells[2,R]:=TableName;
  FBuilderGrid.Cells[3,R]:='Yes';
  FBuilderGrid.Cells[4,R]:='';
  FBuilderGrid.Cells[5,R]:='';
  FBuilderGrid.Cells[6,R]:='';
  UpdateBuilderSQL(nil);
end;

procedure TConsoleForm.BuilderGridChanged(Sender:TObject;ACol,ARow:Integer;
  const Value:string);
begin
  UpdateBuilderSQL(nil);
end;

procedure TConsoleForm.UpdateBuilderSQL(Sender:TObject);
var R,I:Integer;Fields,FromList,SortList,GroupList,FieldName,AliasName,
  TableName,Qualifier,Func,SortDir,S,ColText:string;
  function Included(const V:string):Boolean;
  begin Result:=(Trim(V)<>'') and not SameText(Trim(V),'No') and (Trim(V)<>'0');end;
begin
  if (FSQLTabs.ActivePage<>FBuilderSheet) and (Sender<>nil) then Exit;
  Fields:='';SortList:='';GroupList:='';FromList:='';
  for I:=0 to FBuilderTables.Count-1 do begin
    TableName:=FBuilderTables[I];
    if FromList<>'' then FromList:=FromList+', ';
    if FUseTableAlias.Checked then
      FromList:=FromList+QuoteIdentifier(TableName)+' AS T'+IntToStr(I+1)
    else FromList:=FromList+QuoteIdentifier(TableName);
  end;
  for R:=1 to FBuilderGrid.RowCount-1 do begin
    FieldName:=Trim(FBuilderGrid.Cells[0,R]);
    if (FieldName='') or not Included(FBuilderGrid.Cells[3,R]) then Continue;
    TableName:=Trim(FBuilderGrid.Cells[2,R]);
    I:=FBuilderTables.IndexOf(TableName);
    Qualifier:=QuoteIdentifier(TableName);
    if (I>=0) and FUseTableAlias.Checked then Qualifier:='T'+IntToStr(I+1);
    if FieldName='*' then ColText:='*'
    else if TableName<>'' then ColText:=Qualifier+'.'+QuoteIdentifier(FieldName)
    else ColText:=QuoteIdentifier(FieldName);
    Func:=Trim(FBuilderGrid.Cells[5,R]);
    if Func<>'' then ColText:=Func+'('+ColText+')';
    AliasName:=Trim(FBuilderGrid.Cells[1,R]);
    if AliasName<>'' then ColText:=ColText+' AS '+QuoteIdentifier(AliasName);
    if Fields<>'' then Fields:=Fields+','+LineEnding+'       ';
    Fields:=Fields+ColText;
    SortDir:=UpperCase(Trim(FBuilderGrid.Cells[4,R]));
    if SortDir<>'' then begin
      if SortDir='DESC' then SortDir:=' DESC'
      else if SortDir='ASC' then SortDir:=' ASC'
      else SortDir:='';
      if SortDir<>'' then begin
        if SortList<>'' then SortList:=SortList+', ';
        SortList:=SortList+ColText+SortDir;
      end;
    end;
    if (Func='') and Included(FBuilderGrid.Cells[6,R]) then begin
      if GroupList<>'' then GroupList:=GroupList+', ';
      GroupList:=GroupList+ColText;
    end;
  end;
  if Fields='' then Fields:='*';
  S:='SELECT '+Fields;
  if FromList<>'' then S:=S+LineEnding+'FROM '+FromList;
  if GroupList<>'' then S:=S+LineEnding+'GROUP BY '+GroupList;
  if SortList<>'' then S:=S+LineEnding+'ORDER BY '+SortList;
  if (FBuilderTables.Count>0) or (FBuilderGrid.RowCount>2) then FSQL.Text:=S;
end;

procedure TConsoleForm.OpenTable;
var T:TTableWindow;K:Integer;Title:string;
begin
  RequireConnection;
  Title:=UTF8Encode('テーブル - ')+FObjects.Selected.Text;
  if PtrUInt(FObjects.Selected.Data)=2 then Title:=UTF8Encode('ビュー - ')+FObjects.Selected.Text;
  for K:=0 to FTables.Count-1 do
    if TTableWindow(FTables[K]).Caption=Title then begin
      T:=TTableWindow(FTables[K]);T.Show;T.BringToFront;Exit;
    end;
  T:=TTableWindow.CreateTable(Self,FConnection,FObjects.Selected.Text,PtrUInt(FObjects.Selected.Data)=2);
  FTables.Add(T);
  T.OnClose:=@TableClosed;
  T.Show;
end;

procedure TConsoleForm.TableClosed(Sender:TObject; var CloseAction:TCloseAction);
begin
  FTables.Remove(Sender);
  CloseAction:=caFree;
end;

procedure TConsoleForm.OpenTableData(Sender:TObject);
var K:Integer;T:TTableWindow;Title:string;
begin
  if (FObjects.Selected=nil) or not (PtrUInt(FObjects.Selected.Data) in [1,2]) then Exit;
  OpenTable;
  Title:=UTF8Encode('テーブル - ')+FObjects.Selected.Text;
  if PtrUInt(FObjects.Selected.Data)=2 then Title:=UTF8Encode('ビュー - ')+FObjects.Selected.Text;
  for K:=0 to FTables.Count-1 do begin
    T:=TTableWindow(FTables[K]);
    if T.Caption=Title then begin T.SelectData;T.BringToFront;Exit;end;
  end;
end;

procedure TConsoleForm.OpenTableStatement(Sender:TObject);
var K,StatementIndex:Integer;T:TTableWindow;Title:string;
begin
  if (FObjects.Selected=nil) or not (PtrUInt(FObjects.Selected.Data) in [1,2]) then Exit;
  StatementIndex:=TMenuItem(Sender).Tag;
  OpenTable;
  Title:=UTF8Encode('テーブル - ')+FObjects.Selected.Text;
  if PtrUInt(FObjects.Selected.Data)=2 then Title:=UTF8Encode('ビュー - ')+FObjects.Selected.Text;
  for K:=0 to FTables.Count-1 do begin
    T:=TTableWindow(FTables[K]);
    if T.Caption=Title then begin T.SelectStatement(StatementIndex);T.BringToFront;Exit;end;
  end;
end;

procedure TConsoleForm.CreateSelectSQL(Sender:TObject);
begin
  if (FObjects.Selected=nil) or not (PtrUInt(FObjects.Selected.Data) in [1,2]) then Exit;
  FSQL.Text:='SELECT *'+LineEnding+'FROM '+QuoteIdentifier(FObjects.Selected.Text)+';';
  FSQL.SelStart:=0;
  FSQLTabs.ActivePage:=FSQLSheet;
  OpenSQL(nil);
end;

procedure TConsoleForm.CopyObjectName(Sender:TObject);
begin
  if FObjects.Selected=nil then Exit;
  Clipboard.AsText:=QuoteIdentifier(FObjects.Selected.Text);
end;

function TConsoleForm.SelectedConnectionSettings(out Settings:TConnectionSettings):Boolean;
var N,Folder,DBNode:TTreeNode;Kind:PtrUInt;I:Integer;
  function LoadProfile(const Name:string):Boolean;
  begin
    Result:=Name<>'';
    if not Result then Exit;
    if SameText(Name,FSettings.Name) then Settings:=FSettings
    else ReadProfile(Name,Settings);
  end;
begin
  Result:=False;Settings:=FSettings;N:=FObjects.Selected;
  while N<>nil do begin
    Kind:=PtrUInt(N.Data);
    if Kind=200 then begin Result:=LoadProfile(N.Text);if Result then Exit;end;
    if Kind=300 then begin
      Folder:=N.GetFirstChild;DBNode:=nil;
      if Folder<>nil then DBNode:=Folder.GetFirstChild;
      if DBNode<>nil then Exit(LoadProfile(DBNode.Text));
      for I:=0 to FProfiles.Count-1 do begin
        ReadProfile(FProfiles[I],Settings);
        if TreeServerLabel(Settings)=N.Text then Exit(True);
      end;
      Exit(False);
    end;
    N:=N.Parent;
  end;
  if Settings.Database<>'' then Exit(True);
  if FProfiles.Count>0 then begin ReadProfile(FProfiles[0],Settings);Exit(Settings.Database<>'');end;
end;

procedure TConsoleForm.CreateDatabaseClick(Sender:TObject);
var Settings,NewSettings,Existing:TConnectionSettings;Files,Lengths:TStringList;
    AliasName,UserName,Role,Password,ClientPath:string;
    PageSize,Dialect,I:Integer;Charset:string;RegisterDB:Boolean;Ini:TIniFile;
begin
  Password:='';Files:=TStringList.Create;Lengths:=TStringList.Create;
  try
    if not SelectedConnectionSettings(Settings) then raise Exception.Create('先にサーバー接続設定を登録してください。');
    if Settings.Mode=cmConnectionString then raise Exception.Create('直接指定接続ではデータベースを作成できません。サーバー接続設定を選択してください。');
    PageSize:=4096;Charset:='UTF8';Dialect:=3;RegisterDB:=True;
    if not ExecuteDatabaseCreateDialog(Self,ServerLabel(Settings),'','',
      Files,Lengths,PageSize,Charset,Dialect,RegisterDB,AliasName) then Exit;
    if RegisterDB and (FProfiles.IndexOf(AliasName)>=0) then begin
      ReadProfile(AliasName,Existing);
      if not SameText(Existing.Database,Files[0]) then
        raise Exception.Create('このエイリアス名は別のデータベースに使用されています。別名を指定してください。');
    end;
    if not FileExists(Settings.ClientLibrary) then raise Exception.Create('Firebird 5のクライアントライブラリが見つかりません。');
    if FConnection.Connected and not SameText(ExpandFileName(FLoader.LibraryName),ExpandFileName(Settings.ClientLibrary)) then
      raise Exception.Create('別のFirebirdクライアントで接続中です。先に切断してください。');
    if not FConnection.Connected then begin
      if Assigned(ConsoleHost) then ConsoleHost.CheckLibrary(Settings.ClientLibrary);
      FLoader.Enabled:=False;FLoader.LibraryName:=Settings.ClientLibrary;FLoader.Enabled:=True;
    end;
    UserName:=Settings.UserName;Role:=Settings.Role;
    if not AskLogin(Self,ServerLabel(Settings),UserName,Role,Password) then Exit;
    try
      CreateRemoteDatabase(Settings,UserName,Password,Role,Files,Lengths,PageSize,Charset,Dialect);
      if RegisterDB then begin
        NewSettings:=Settings;NewSettings.Name:=AliasName;NewSettings.Database:=Files[0];
        WriteSettings(FConfig,NewSettings);
        if FProfiles.IndexOf(NewSettings.Name)<0 then FProfiles.Add(NewSettings.Name);
      end;
      Log('データベースを作成しました: '+Files[0]);
      RebuildTree;
      if RegisterDB then MessageDlg('データベースの作成','作成したデータベースを接続一覧に登録しました。',mtInformation,[mbOK],0)
      else MessageDlg('データベースの作成','データベースを作成しました。',mtInformation,[mbOK],0);
    except on E:Exception do MessageDlg('データベースの作成',E.Message,mtError,[mbOK],0);end;
  finally
    Password:='';Files.Free;Lengths.Free;
  end;
end;

procedure TConsoleForm.DeleteDatabaseClick(Sender:TObject);
var Settings,Profile:TConnectionSettings;UserName,Role,Password,HostPath,TargetPath:string;
    Ini:TIniFile;I:Integer;WasActive,LibraryMatches:Boolean;
begin
  Password:='';
  try
    try
      if not SelectedConnectionSettings(Settings) then begin
        MessageDlg('データベースの削除','削除対象のサーバーまたはデータベースを選択してください。',mtWarning,[mbOK],0);Exit;
      end;
      if Settings.Mode=cmConnectionString then begin
        MessageDlg('データベースの削除','直接指定接続ではデータベースを削除できません。',mtWarning,[mbOK],0);Exit;
      end;
      TargetPath:=Settings.Database;
      if TargetPath='' then begin
        MessageDlg('データベースの削除','削除するデータベースのパスがありません。',mtWarning,[mbOK],0);Exit;
      end;
      UserName:=Settings.UserName;Role:=Settings.Role;
      if not AskLogin(Self,ServerLabel(Settings),UserName,Role,Password) then Exit;
      if MessageDlg('データベースの削除',UTF8Encode('次のデータベースとその全ファイルを完全に削除します。')+
        LineEnding+TargetPath+LineEnding+LineEnding+UTF8Encode('この操作は元に戻せません。続行しますか？'),
        mtWarning,[mbYes,mbNo],0)<>mrYes then Exit;

      WasActive:=False;LibraryMatches:=SameText(ExpandFileName(FLoader.LibraryName),ExpandFileName(Settings.ClientLibrary));
      if FConnection.Connected then begin
        try HostPath:=ConnectionString(FSettings);TargetPath:=ConnectionString(Settings);WasActive:=SameText(HostPath,TargetPath);except WasActive:=False;end;
        if WasActive or not LibraryMatches then if not EndSession then Exit;
      end;
      if not FileExists(Settings.ClientLibrary) then raise Exception.Create('Firebird 5のクライアントライブラリが見つかりません。');
      if not FConnection.Connected then begin
        if Assigned(ConsoleHost) then ConsoleHost.CheckLibrary(Settings.ClientLibrary);
      FLoader.Enabled:=False;FLoader.LibraryName:=Settings.ClientLibrary;FLoader.Enabled:=True;
      end;
      DropRemoteDatabase(Settings,UserName,Password,Role);

      Ini:=TIniFile.Create(FConfig);
      try
        for I:=FProfiles.Count-1 downto 0 do begin
          ReadProfile(FProfiles[I],Profile);
          if (Profile.Mode=Settings.Mode) and SameText(Profile.Host,Settings.Host) and
             (Profile.Port=Settings.Port) and SameText(Profile.Database,Settings.Database) then begin
            Ini.EraseSection(FProfiles[I]);FProfiles.Delete(I);
          end;
        end;
        Ini.UpdateFile;
      finally Ini.Free;end;
      if SameText(FSettings.Database,Settings.Database) and SameText(FSettings.Host,Settings.Host) and
        (FSettings.Port=Settings.Port) then begin
        if FProfiles.Count>0 then ReadProfile(FProfiles[0],FSettings) else FSettings:=DefaultSettings;
      end;
      Log('データベースを削除しました: '+Settings.Database);
      RebuildTree;
      MessageDlg('データベースの削除','データベースを削除しました。',mtInformation,[mbOK],0);
    except on E:Exception do MessageDlg('データベースの削除',E.Message,mtError,[mbOK],0);end;
  finally Password:='';end;
end;

procedure TConsoleForm.DatabaseProperties(Sender:TObject);
begin
  RequireConnection;
  if not ActiveSelection then raise Exception.Create('接続中のサーバーまたはデータベースを選択してください。');
  ShowDatabasePropertiesDialog(Self,FConnection,FSettings);
end;

procedure TConsoleForm.ConnectedUsers(Sender:TObject);
begin
  RequireConnection;
  if not ActiveSelection then raise Exception.Create('接続中のサーバーまたはデータベースを選択してください。');
  ShowQuerySnapshot(Self,FConnection,'接続中ユーザー',
    'SELECT MON$ATTACHMENT_ID AS ATTACHMENT_ID, MON$USER AS USER_NAME, MON$ROLE AS ROLE_NAME, '+
    'MON$REMOTE_ADDRESS AS REMOTE_ADDRESS, MON$REMOTE_PROTOCOL AS PROTOCOL, MON$TIMESTAMP AS CONNECTED_AT, '+
    'MON$REMOTE_PROCESS AS REMOTE_PROCESS FROM MON$ATTACHMENTS ORDER BY MON$ATTACHMENT_ID');
end;

procedure TConsoleForm.DatabaseStatistics(Sender:TObject);
begin
  RequireConnection;
  if not ActiveSelection then raise Exception.Create('接続中のサーバーまたはデータベースを選択してください。');
  ShowQuerySnapshot(Self,FConnection,'データベースの統計情報',
    'SELECT D.MON$OLDEST_TRANSACTION AS OLDEST_TRANSACTION, D.MON$OLDEST_ACTIVE AS OLDEST_ACTIVE, '+
    'D.MON$OLDEST_SNAPSHOT AS OLDEST_SNAPSHOT, D.MON$NEXT_TRANSACTION AS NEXT_TRANSACTION, '+
    'I.MON$PAGE_READS AS PAGE_READS, I.MON$PAGE_WRITES AS PAGE_WRITES, I.MON$PAGE_FETCHES AS PAGE_FETCHES, '+
    'I.MON$PAGE_MARKS AS PAGE_MARKS FROM MON$DATABASE D LEFT JOIN MON$IO_STATS I '+
    'ON I.MON$STAT_ID=D.MON$STAT_ID AND I.MON$STAT_GROUP=0');
end;

procedure TConsoleForm.DatabaseMetadata(Sender:TObject);
var Lines: TStringList;
begin
  RequireConnection;
  if not ActiveSelection then
    raise Exception.Create('接続中のデータベースを選択してください。');
  Lines := ExtractDatabaseMetadata(FConnection, FTransaction);
  try
    ShowMetadataWindow(Self, 'メタデータ — ' + FSettings.Name, Lines);
  finally
    Lines.Free;
    if (not FPending) and FTransaction.Active then FTransaction.Rollback;
  end;
end;

procedure TConsoleForm.ActionOpen(Sender:TObject);
begin
  if FList.Selected=nil then Exit;
  case PtrUInt(FList.Selected.Data) of
    1:DisconnectClick(nil);2:DatabaseProperties(nil);3:DatabaseStatistics(nil);
    4:ConnectedUsers(nil);5:OpenSQL(nil);
    6:BackupClick(nil);7:RestoreClick(nil);8:SweepClick(nil);9:ValidateClick(nil);
    10:DatabaseMetadata(nil);
    11:ConnectClick(nil);12:UnregisterConnection(nil);13:DeleteDatabaseClick(nil);
    14:ServerLoginClick(nil);15:ServerLogoutClick(nil);16:ServerPropertiesClick(nil);
    17:ServerLogClick(nil);18:ConnectClick(nil);
    21:BrowseObject(nil);22:ShowDefinition(nil);23:OpenSQL(nil);
  end;
end;

procedure TConsoleForm.TreeMouseDown(Sender:TObject;Button:TMouseButton;Shift:TShiftState;X,Y:Integer);
var N:TTreeNode;
begin
  if Button=mbRight then begin N:=FObjects.GetNodeAt(X,Y);if N<>nil then FObjects.Selected:=N;end;
end;

procedure TConsoleForm.PopupOpening(Sender:TObject);
var Item,SubMenu:TMenuItem;Kind:PtrUInt;ContextActive:Boolean;
  procedure Add(const Title:string;Handler:TNotifyEvent;Enabled:Boolean);
  begin Item:=TMenuItem.Create(FContext);Item.Caption:=Title;Item.ImageIndex:=IconForCaption(Title);Item.OnClick:=Handler;Item.Enabled:=Enabled;FContext.Items.Add(Item);end;
  procedure AddSub(ParentItem:TMenuItem;const Title:string;Handler:TNotifyEvent;Enabled:Boolean;TagValue:Integer=-1);
  begin
    Item:=TMenuItem.Create(FContext);Item.Caption:=Title;Item.ImageIndex:=IconForCaption(Title);
    Item.OnClick:=Handler;Item.Enabled:=Enabled;Item.Tag:=TagValue;ParentItem.Add(Item);
  end;
  procedure Separator;
  begin Item:=TMenuItem.Create(FContext);Item.Caption:='-';FContext.Items.Add(Item);end;
begin
  FContext.Items.Clear;
  if FObjects.Selected=nil then Exit;
  Kind:=PtrUInt(FObjects.Selected.Data);
  ContextActive:=ActiveSelection;
  if Kind=300 then begin
    Add('サーバーへログイン…',@ServerLoginClick,True);
    Add('サーバーからログアウト',@ServerLogoutClick,FServerSession.IsLoggedIn);
    Add('サーバーのプロパティ…',@ServerPropertiesClick,True);
    Add('サーバーの登録解除…',@UnregisterConnection,True);
    Add('ログファイルを表示…',@ServerLogClick,True);
    Add('ユーザー情報…',@UsersClick,True);
    Exit;
  end;
  if Kind=350 then begin
    Add('サーバーへログイン…',@ServerLoginClick,True);
    Separator;
    Add('データベースを登録…',@RegisterDatabaseClick,True);
    Add('データベースの作成…',@CreateDatabaseClick,True);
    Separator;
    Add('一覧を更新',@RefreshObjects,ContextActive);
  end else if Kind>=200 then begin
    Add('サーバーへログイン…',@ServerLoginClick,True);
    Separator;
    Add('データベースを登録…',@RegisterDatabaseClick,True);
    Add('データベースの登録解除…',@UnregisterConnection,Kind=200);
    Separator;
    Add('データベースへ接続',@ConnectDatabaseClick,not ContextActive);
    Add('ユーザーを指定して接続…',@ConnectDatabaseAsClick,True);
    Add('データベースから切断',@DisconnectClick,ContextActive);
    Separator;
    Add('データベースの作成…',@CreateDatabaseClick,True);
    if Kind=200 then Add('データベースの削除…',@DeleteDatabaseClick,True);
    Separator;
    Item:=TMenuItem.Create(FContext);Item.Caption:='メンテナンス';Item.Enabled:=ContextActive;FContext.Items.Add(Item);
    SubMenu:=Item;
    AddSub(SubMenu,'統計情報…',@DatabaseStatistics,ContextActive);
    AddSub(SubMenu,'スイープ…',@SweepClick,ContextActive);
    AddSub(SubMenu,'検証…',@ValidateClick,ContextActive);
    Item:=TMenuItem.Create(FContext);Item.Caption:='バックアップ／リストア';Item.Enabled:=ContextActive;FContext.Items.Add(Item);
    SubMenu:=Item;
    AddSub(SubMenu,'バックアップ…',@BackupClick,ContextActive);
    AddSub(SubMenu,'リストア…',@RestoreClick,ContextActive);
    Separator;
    Add('対話型SQL…',@OpenSQL,ContextActive);
    if Kind=200 then Add('メタデータの表示…',@DatabaseMetadata,ContextActive);
    Add('接続中ユーザー…',@ConnectedUsers,ContextActive);
    Add('データベースのプロパティ…',@DatabaseProperties,ContextActive);
  end else if Kind in [1,2] then begin
    Add('データを表示',@OpenTableData,ContextActive);
    FContext.Items[FContext.Items.Count-1].ImageIndex:=icTable;
    Add('構造・プロパティ',@BrowseObject,ContextActive);
    FContext.Items[FContext.Items.Count-1].ImageIndex:=icProperties;
    Separator;
    Item:=TMenuItem.Create(FContext);Item.Caption:='SQLステートメント';Item.ImageIndex:=icSQL;FContext.Items.Add(Item);
    SubMenu:=Item;
    AddSub(SubMenu,'SELECT',@OpenTableStatement,ContextActive,0);
    AddSub(SubMenu,'INSERT',@OpenTableStatement,ContextActive,1);
    AddSub(SubMenu,'UPDATE',@OpenTableStatement,ContextActive,2);
    AddSub(SubMenu,'DELETE',@OpenTableStatement,ContextActive,3);
    Add('定義を表示',@ShowDefinition,ContextActive);
    FContext.Items[FContext.Items.Count-1].ImageIndex:=icLog;
    Separator;
    Add('データベースから切断',@DisconnectClick,ContextActive);
    Item:=TMenuItem.Create(FContext);Item.Caption:='メンテナンス';Item.Enabled:=ContextActive;FContext.Items.Add(Item);
    SubMenu:=Item;
    AddSub(SubMenu,'統計情報…',@DatabaseStatistics,ContextActive);
    AddSub(SubMenu,'スイープ…',@SweepClick,ContextActive);
    AddSub(SubMenu,'検証…',@ValidateClick,ContextActive);
    Item:=TMenuItem.Create(FContext);Item.Caption:='バックアップ／リストア';Item.Enabled:=ContextActive;FContext.Items.Add(Item);
    SubMenu:=Item;
    AddSub(SubMenu,'バックアップ…',@BackupClick,ContextActive);
    AddSub(SubMenu,'リストア…',@RestoreClick,ContextActive);
    Add('メタデータの表示…',@DatabaseMetadata,ContextActive);
    Add('接続中のユーザー…',@ConnectedUsers,ContextActive);
    Add('データベースのプロパティ…',@DatabaseProperties,ContextActive);
    Separator;
    Add('名前をコピー',@CopyObjectName,True);
    Add('一覧を更新',@RefreshObjects,ContextActive);
  end else begin
    Add('開く',@BrowseObject,Kind<100);
    Add('メタデータの表示',@ShowDefinition,Kind<100);
    Add('一覧を更新',@RefreshObjects,ContextActive);
  end;
end;

procedure TConsoleForm.RefreshView(Sender:TObject);
var OldPath,OldTable:string;Node:TTreeNode;Index:Integer;
begin
  OldPath:='';
  if FObjects.Selected<>nil then OldPath:=FObjects.Selected.GetTextPath;
  OldTable:='';
  if FSQLCatalog.ItemIndex>=0 then OldTable:=FSQLCatalog.Items[FSQLCatalog.ItemIndex];
  RefreshObjects(nil);
  Node:=FObjects.Items.GetFirstNode;
  while Node<>nil do begin
    if Node.GetTextPath=OldPath then begin FObjects.Selected:=Node;Break;end;
    Node:=Node.GetNext;
  end;
  PopulateSQLCatalog;
  Index:=FSQLCatalog.Items.IndexOf(OldTable);
  if Index>=0 then begin FSQLCatalog.ItemIndex:=Index;SQLCatalogClick(nil);end;
end;

procedure TConsoleForm.ToggleSystemData(Sender:TObject);
var Ini:TIniFile;ShowSystem:Boolean;
begin
  ShowSystem:=not FSystemDataMenu.Checked;
  Ini:=TIniFile.Create(ExtractFileDir(FConfig)+PathDelim+'view.ini');
  try Ini.WriteBool('View','SystemData',ShowSystem);Ini.UpdateFile;finally Ini.Free;end;
  FSystemDataMenu.Checked:=ShowSystem;
  RefreshView(nil);
end;

procedure TConsoleForm.ClientInformation(Sender:TObject);
var LibraryPath,VersionText:string;Info:TFileVersionInfo;Settings:TConnectionSettings;
begin
  if FLoader.Enabled then LibraryPath:=FLoader.LibraryName
  else if SelectedConnectionSettings(Settings) then LibraryPath:=Settings.ClientLibrary
  else LibraryPath:='';
  VersionText:='未取得';
  if FileExists(LibraryPath) then begin
    Info:=TFileVersionInfo.Create(nil);
    try
      try
        Info.FileName:=LibraryPath;Info.ReadFileInfo;
        if Info.VersionStrings.Values['FileVersion']<>'' then VersionText:=Info.VersionStrings.Values['FileVersion'];
      except on E:Exception do VersionText:=UTF8Encode('取得できません: ')+E.Message;end;
    finally Info.Free;end;
  end;
  if LibraryPath='' then LibraryPath:='未設定';
  MessageDlg('クライアント情報',UTF8Encode('クライアントライブラリ: ')+LibraryPath+LineEnding+
    UTF8Encode('ファイルバージョン: ')+VersionText+LineEnding+
    UTF8Encode('FBConsole: ')+IntToStr(SizeOf(Pointer)*8)+' bit',mtInformation,[mbOK],0);
end;

procedure TConsoleForm.RefreshObjects(Sender: TObject);
const Kinds: array[1..12] of string = ('テーブル', 'ビュー', 'ストアドプロシージャ',
  'トリガー', 'シーケンス', 'ドメイン', 'インデックス', '外部関数', '例外', 'ロール', 'パッケージ', 'Blobフィルタ');
  Queries: array[1..12] of string = (
  'SELECT RDB$RELATION_NAME AS N FROM RDB$RELATIONS WHERE RDB$VIEW_BLR IS NULL',
  'SELECT RDB$RELATION_NAME AS N FROM RDB$RELATIONS WHERE RDB$VIEW_BLR IS NOT NULL',
  'SELECT RDB$PROCEDURE_NAME AS N FROM RDB$PROCEDURES WHERE RDB$PACKAGE_NAME IS NULL',
  'SELECT RDB$TRIGGER_NAME AS N FROM RDB$TRIGGERS WHERE 1=1',
  'SELECT RDB$GENERATOR_NAME AS N FROM RDB$GENERATORS WHERE 1=1',
  'SELECT RDB$FIELD_NAME AS N FROM RDB$FIELDS WHERE 1=1',
  'SELECT RDB$INDEX_NAME AS N FROM RDB$INDICES WHERE 1=1',
  'SELECT RDB$FUNCTION_NAME AS N FROM RDB$FUNCTIONS WHERE RDB$PACKAGE_NAME IS NULL AND (RDB$MODULE_NAME IS NOT NULL OR RDB$ENGINE_NAME IS NOT NULL)',
  'SELECT RDB$EXCEPTION_NAME AS N FROM RDB$EXCEPTIONS WHERE 1=1',
  'SELECT RDB$ROLE_NAME AS N FROM RDB$ROLES WHERE 1=1',
  'SELECT RDB$PACKAGE_NAME AS N FROM RDB$PACKAGES WHERE 1=1',
  'SELECT RDB$FUNCTION_NAME AS N FROM RDB$FILTERS WHERE 1=1');
  DisplayOrder: array[1..12] of Integer=(6,1,2,3,8,5,9,12,10,4,7,11);
var Q, Q2: TSQLQuery; DatabaseNode, Category, Item, PackageNode, RoutineNode: TTreeNode;
    K,OrderIndex: Integer; PackageName:string;
begin
  if not FConnection.Connected then begin RebuildTree; Exit; end;
  RebuildTree;
  Q := NewQuery;
  Q2 := NewQuery;
  FObjects.OnChange := nil;
  FObjects.Items.BeginUpdate;
  try
    DatabaseNode := FObjects.Items.GetFirstNode;
    while DatabaseNode <> nil do
    begin
      if (PtrUInt(DatabaseNode.Data) = 200) and
        (DatabaseNode.Text = FSettings.Name) then Break;
      DatabaseNode := DatabaseNode.GetNext;
    end;
    if DatabaseNode = nil then raise Exception.Create('Active database node missing');
    for OrderIndex:=Low(DisplayOrder) to High(DisplayOrder) do
    begin
      K:=DisplayOrder[OrderIndex];
      Q.Close;
      Q.SQL.Text:=Queries[K];
      if (not FSystemDataMenu.Checked) and (K<>8) then begin
        Q.SQL.Add('AND COALESCE(RDB$SYSTEM_FLAG,0)=0');
        if K=6 then Q.SQL.Add('AND RDB$FIELD_NAME NOT STARTING WITH ''RDB$''');
      end;
      Q.SQL.Add('ORDER BY N');
      Q.Open;
      Category := FObjects.Items.AddChild(DatabaseNode, Kinds[K]);
      Category.Data := Pointer(PtrUInt(100 + K));
      while not Q.EOF do
      begin
        Item := FObjects.Items.AddChild(Category, TrimRight(Q.Fields[0].AsString));
        Item.Data := Pointer(PtrUInt(K));
        if K=11 then
        begin
          PackageNode:=Item;
          PackageName:=PackageNode.Text;
          Q2.Close;
          Q2.SQL.Text:='SELECT RDB$FUNCTION_NAME AS ROUTINE_NAME, 13 AS ROUTINE_KIND '+
            'FROM RDB$FUNCTIONS WHERE RDB$PACKAGE_NAME='+QuotedStr(PackageName)+
            ' UNION ALL SELECT RDB$PROCEDURE_NAME AS ROUTINE_NAME, 14 AS ROUTINE_KIND '+
            'FROM RDB$PROCEDURES WHERE RDB$PACKAGE_NAME='+QuotedStr(PackageName)+
            ' ORDER BY ROUTINE_KIND, ROUTINE_NAME';
          Q2.Open;
          while not Q2.EOF do
          begin
            RoutineNode:=FObjects.Items.AddChild(PackageNode,TrimRight(Q2.FieldByName('ROUTINE_NAME').AsString));
            RoutineNode.Data:=Pointer(PtrUInt(Q2.FieldByName('ROUTINE_KIND').AsInteger));
            Q2.Next;
          end;
          Q2.Close;
        end;
        Q.Next;
      end;
    end;
    DatabaseNode.Expand(False);
    FObjects.Selected := DatabaseNode;
  finally
    Q2.Free;
    Q.Free;
    FObjects.Items.EndUpdate;
    FObjects.OnChange := @TreeChanged;
    if (not FPending) and FTransaction.Active then FTransaction.Rollback;
  end;
  RefreshTreeImages;
  TreeChanged(nil, FObjects.Selected);
end;

procedure TConsoleForm.BrowseObject(Sender: TObject);
var Settings:TConnectionSettings;
begin
  if (FObjects.Selected = nil) or (FObjects.Selected.Data = nil) then Exit;
  case PtrUInt(FObjects.Selected.Data) of
    300:begin
      if FServerSession.IsLoggedIn and SelectedConnectionSettings(Settings) and
        FServerSession.Matches(Settings) then ConnectClick(nil)
      else ServerLoginClick(nil);
      Exit;
    end;
    501:begin BackupClick(nil);Exit;end;
    502:begin ServerLogClick(nil);Exit;end;
    503:begin UsersClick(nil);Exit;end;
  end;
  if PtrUInt(FObjects.Selected.Data) = 200 then begin ConnectClick(nil); Exit; end;
  if PtrUInt(FObjects.Selected.Data) >= 100 then
  begin
    FObjects.Selected.Expand(False);
    TreeChanged(nil, FObjects.Selected);
    Exit;
  end;
  if (PtrUInt(FObjects.Selected.Data) <> 1) and
    (PtrUInt(FObjects.Selected.Data) <> 2) then
  begin
    ShowDefinition(nil);
    Exit;
  end;
  OpenTable;
end;

procedure TConsoleForm.BackupClick(Sender:TObject);
begin Maintenance(soBackup);end;
procedure TConsoleForm.RestoreClick(Sender:TObject);
begin Maintenance(soRestore);end;
procedure TConsoleForm.SweepClick(Sender:TObject);
begin Maintenance(soSweep);end;
procedure TConsoleForm.ValidateClick(Sender:TObject);
begin Maintenance(soValidate);end;

procedure TConsoleForm.ServerLoginClick(Sender:TObject);
var Settings:TConnectionSettings; Target:TConsoleForm;
begin
  if not SelectedConnectionSettings(Settings) then Exit;
  Target:=Self;
  if FServerSession.IsLoggedIn and not FServerSession.Matches(Settings) then
    Target:=ConsoleHost.SessionForConnection;
  Target.LoginToServer(Settings);
end;

procedure TConsoleForm.LoginToServer(const Settings:TConnectionSettings);
var UserName,Role,Password:string;
begin
  Password:='';
  try
    try
      if FServerSession.IsLoggedIn then begin
        if FServerSession.Matches(Settings) then begin
          MessageDlg('サーバーログイン','このサーバーにはログイン済みです。',mtInformation,[mbOK],0);Exit;
        end;
        Exit;
      end;
      if FConnection.Connected and not SameText(ExpandFileName(FLoader.LibraryName),ExpandFileName(Settings.ClientLibrary)) then
        raise Exception.Create('別のFirebirdクライアントでデータベース接続中です。先に切断してください。');
      if not FConnection.Connected then begin
        if Assigned(ConsoleHost) then ConsoleHost.CheckLibrary(Settings.ClientLibrary);
      FLoader.Enabled:=False;FLoader.LibraryName:=Settings.ClientLibrary;FLoader.Enabled:=True;
      end;
      UserName:=Settings.UserName;Role:=Settings.Role;
      if not AskLogin(Self,ServerLabel(Settings),UserName,Role,Password) then Exit;
      FServerSession.Login(Settings,UserName,Password,Role);
      RebuildTree;
      Log('サーバーにログインしました: '+ServerLabel(Settings));
      MessageDlg('サーバーログイン','サーバーへログインしました。',mtInformation,[mbOK],0);
    except on E:Exception do MessageDlg('サーバーログイン',E.Message,mtError,[mbOK],0);end;
  finally Password:='';end;
end;

procedure TConsoleForm.ServerLogoutClick(Sender:TObject);
begin
  if not FServerSession.IsLoggedIn then begin
    MessageDlg('サーバーログアウト','ログイン中のサーバーはありません。',mtInformation,[mbOK],0);Exit;
  end;
  try
    try
      FServerSession.Logout;
    finally
      RebuildTree;
    end;
    Log('サーバーからログアウトしました。');
    MessageDlg('サーバーログアウト','サーバーからログアウトしました。',mtInformation,[mbOK],0);
  except on E:Exception do MessageDlg('サーバーログアウト',E.Message,mtError,[mbOK],0);end;
end;

procedure TConsoleForm.ServerPropertiesClick(Sender:TObject);
var Settings:TConnectionSettings;
begin
  try
    if not SelectedConnectionSettings(Settings) then raise Exception.Create('登録済みサーバーを選択してください。');
    if Settings.Mode=cmConnectionString then raise Exception.Create('直接指定接続ではサーバーのプロパティを編集できません。');
    if Trim(Settings.ServerAlias)='' then Settings.ServerAlias:=TreeServerLabel(Settings);
    EditServerProperties(Self,Settings,FServerSession,@ApplyServerProperties);
  except on E:Exception do MessageDlg('サーバーのプロパティ',E.Message,mtError,[mbOK],0);end;
end;

function TConsoleForm.ApplyServerProperties(const Original,Settings:TConnectionSettings):Boolean;
var Profile:TConnectionSettings;I:Integer;ChangedServer,WasActive:Boolean;
  function IsSameServer(const A,B:TConnectionSettings):Boolean;
  begin Result:=(A.Mode=B.Mode) and SameText(A.Host,B.Host) and (A.Port=B.Port);end;
begin
  Result:=False;
  try
    for I:=0 to FProfiles.Count-1 do begin
      ReadProfile(FProfiles[I],Profile);
      if (Trim(Profile.ServerAlias)<>'') and SameText(Profile.ServerAlias,Settings.ServerAlias) and
         not IsSameServer(Profile,Original) then
        raise Exception.Create('このサーバーエイリアスは別のサーバーで使用されています。');
    end;
    ChangedServer:=not IsSameServer(Original,Settings);
    if FServerSession.IsLoggedIn and FServerSession.Matches(Original) and ChangedServer then begin
      FServerSession.Logout;
      RefreshTreeImages;
      UpdateToolbarState;
    end;
    WasActive:=IsSameServer(FSettings,Original);
    if WasActive and FConnection.Connected and ChangedServer then
      if not EndSession then Exit;
    for I:=0 to FProfiles.Count-1 do begin
      ReadProfile(FProfiles[I],Profile);
      if IsSameServer(Profile,Original) then begin
        Profile.Mode:=Settings.Mode;Profile.Host:=Settings.Host;Profile.Port:=Settings.Port;
        Profile.ServerAlias:=Settings.ServerAlias;Profile.Description:=Settings.Description;
        if FProfiles.Objects[I] is TTemporaryServer then TTemporaryServer(FProfiles.Objects[I]).Settings:=Profile
        else WriteSettings(FConfig,Profile);
      end;
    end;
    if IsSameServer(FSettings,Original) then begin
      FSettings.Mode:=Settings.Mode;FSettings.Host:=Settings.Host;FSettings.Port:=Settings.Port;
      FSettings.ServerAlias:=Settings.ServerAlias;FSettings.Description:=Settings.Description;
      I:=FProfiles.IndexOf(FSettings.Name);
      if (I>=0) and (FProfiles.Objects[I]=nil) then WriteSettings(FConfig,FSettings);
    end;
    RebuildTree;Log('サーバーのプロパティを更新しました: '+Settings.ServerAlias);Result:=True;
  except on E:Exception do MessageDlg('サーバーのプロパティ',E.Message,mtError,[mbOK],0);end;
end;

procedure TConsoleForm.ServerLogClick(Sender:TObject);
begin Maintenance(soServerLog);end;
procedure TConsoleForm.UsersClick(Sender:TObject);
begin
  if (not FConnection.Connected) or (not ActiveSelection) then begin ConnectClick(nil);if not FConnection.Connected then Exit;end;
  RequireConnection;
  if not ActiveSelection then raise Exception.Create('接続中のサーバーまたはデータベースを選択してください。');
  TreeChanged(nil,FObjects.Selected);
end;

procedure TConsoleForm.UserListPopup(Sender:TObject);
var I:Integer; M:TMenuItem; PopupRef:TPopupMenu;
begin
  PopupRef:=TPopupMenu(Sender);
  PopupRef.Items.Clear;
  if (FObjects.Selected=nil) or (PtrUInt(FObjects.Selected.Data)<>503) then Exit;
  for I:=1 to 3 do begin
    M:=TMenuItem.Create(PopupRef);
    case I of
      1:M.Caption:='ユーザーの追加(A)…';
      2:M.Caption:='ユーザーの編集(M)…';
      3:M.Caption:='ユーザーの削除(D)';
    end;
    M.Tag:=I;M.OnClick:=@UserActionClick;
    M.Enabled:=(I=1) or (FList.Selected<>nil);
    PopupRef.Items.Add(M);
  end;
end;

procedure TConsoleForm.UserActionClick(Sender:TObject);
var Q:TSQLQuery;TargetUser,SQLText:string;ActionKind:Integer;Info:TUserInfo;DeleteRequested:Boolean;
begin
  ActionKind:=TMenuItem(Sender).Tag;
  Info:=Default(TUserInfo);TargetUser:='';
  if ActionKind=1 then begin
    if not EditUserInfo(Self,False,Info,DeleteRequested) then Exit;
    TargetUser:=Info.UserName;
  end else begin
    if FList.Selected=nil then Exit;
    TargetUser:=FList.Selected.Caption;
  end;
  if ActionKind=3 then begin
    if MessageDlg('ユーザーの削除',TargetUser+' を削除しますか？',mtConfirmation,[mbYes,mbNo],0)<>mrYes then Exit;
    SQLText:='DROP USER '+QuoteIdentifier(TargetUser);
  end else if ActionKind=1 then begin
    SQLText:='CREATE USER '+QuoteIdentifier(TargetUser)+' PASSWORD '+QuotedStr(Info.Password)+
      ' FIRSTNAME '+QuotedStr(Info.FirstName)+' MIDDLENAME '+QuotedStr(Info.MiddleName)+
      ' LASTNAME '+QuotedStr(Info.LastName);
  end else begin
    Info.UserName:=TargetUser;Info.FirstName:=FList.Selected.SubItems[0];
    Info.MiddleName:=FList.Selected.SubItems[1];Info.LastName:=FList.Selected.SubItems[2];
    if not EditUserInfo(Self,True,Info,DeleteRequested) then begin
      if not DeleteRequested then Exit;
      SQLText:='DROP USER '+QuoteIdentifier(TargetUser);
    end else begin
      SQLText:='ALTER USER '+QuoteIdentifier(TargetUser)+' FIRSTNAME '+QuotedStr(Info.FirstName)+
        ' MIDDLENAME '+QuotedStr(Info.MiddleName)+' LASTNAME '+QuotedStr(Info.LastName);
      if Info.Password<>'' then
        SQLText:=SQLText+' PASSWORD '+QuotedStr(Info.Password);
    end;
  end;
  RequireConnection;
  Q:=NewQuery;
  try
    Q.ReadOnly:=False;Q.SQL.Text:=SQLText;Q.ExecSQL;
    if FTransaction.Active then FTransaction.Commit;
    TreeChanged(nil,FObjects.Selected);
  finally Q.Free;end;
end;
procedure TConsoleForm.Maintenance(Operation:TServiceOperation);
const Titles:array[TServiceOperation] of string=('データベースのバックアップ','データベースのリストア','スイープ','データベースの検証','サーバーログ');
var UserName,Role,Password,DatabasePath,Host,ServiceName:string;
    BackupFiles:TStringList;ServiceOptions:TServiceOptions;ServerSettings:TConnectionSettings;
begin
  if Operation=soServerLog then begin
    if not SelectedConnectionSettings(ServerSettings) then raise Exception.Create('サーバーを選択してください。');
    if ServerSettings.Mode=cmConnectionString then raise Exception.Create('サーバーログは登録済みTCP/IPサーバーで表示してください。');
    UserName:=ServerSettings.UserName;Role:=ServerSettings.Role;Password:='';
    if ServerSettings.Mode=cmLocalTCP then Host:='localhost' else Host:=ServerSettings.Host;
    if (Pos(':',Host)>0) and (Host[1]<>'[') then Host:='['+Host+']';
    ServiceName:=Host+'/'+IntToStr(ServerSettings.Port)+':service_mgr';
    BackupFiles:=TStringList.Create;ServiceOptions:=Default(TServiceOptions);ServiceOptions.Verbose:=True;
    try
      if not AskLogin(Self,ServerLabel(ServerSettings),UserName,Role,Password) then Exit;
      ShowService(Self,Titles[Operation],ServiceName,UserName,Password,Role,'',BackupFiles,ServiceOptions,Operation);
    finally Password:='';BackupFiles.Free;end;
    Exit;
  end;
  RequireConnection;
  if not ActiveSelection then raise Exception.Create('接続中のサーバーまたはデータベースを選択してください。');
  if FSettings.Mode=cmConnectionString then
    raise Exception.Create('管理操作には接続文字列の直接指定ではなく、ローカル／リモートサーバーの登録を使用してください。');
  DatabasePath:=FSettings.Database;BackupFiles:=TStringList.Create;
  ServiceOptions:=Default(TServiceOptions);ServiceOptions.Verbose:=True;
  if Operation in [soBackup,soRestore] then begin
    BackupFiles.Add(FSettings.Database+'.fbk');
    if Operation=soRestore then DatabasePath:=FSettings.Database+'.restored.fdb';
    if not ExecuteBackupRestoreDialog(Self,Operation,ServerLabel(FSettings),DatabasePath,BackupFiles,ServiceOptions) then begin BackupFiles.Free;Exit;end;
  end;
  if Operation=soBackup then
    if MessageDlg(Titles[Operation],UTF8Encode('出力先: ')+BackupFiles.Text+LineEnding+
      UTF8Encode('同名のバックアップファイルは上書きされます。実行しますか？'),mtConfirmation,[mbYes,mbNo],0)<>mrYes then begin BackupFiles.Free;Exit;end;
  if (Operation=soRestore) and ServiceOptions.RestoreReplace then
    if MessageDlg(Titles[Operation],UTF8Encode(DatabasePath)+LineEnding+
      UTF8Encode('既存データベースを置き換えます。実行しますか？'),mtWarning,[mbYes,mbNo],0)<>mrYes then begin BackupFiles.Free;Exit;end;
  if Operation=soSweep then
    if MessageDlg(Titles[Operation],'このデータベースでスイープを実行しますか？',mtConfirmation,[mbYes,mbNo],0)<>mrYes then begin BackupFiles.Free;Exit;end;
  UserName:=FSettings.UserName;Role:=FSettings.Role;Password:='';
  if FSettings.Mode=cmLocalTCP then Host:='localhost' else Host:=FSettings.Host;
  if (Pos(':',Host)>0) and (Host[1]<>'[') then Host:='['+Host+']';
  ServiceName:=Host+'/'+IntToStr(FSettings.Port)+':service_mgr';
  try
    if not AskLogin(Self,ServerLabel(FSettings),UserName,Role,Password) then Exit;
    ShowService(Self,Titles[Operation],ServiceName,UserName,Password,Role,DatabasePath,BackupFiles,ServiceOptions,Operation);
  finally Password:='';BackupFiles.Free;end;
end;

function TConsoleForm.ActiveSelection:Boolean;
var N:TTreeNode;Kind:PtrUInt;
begin
  Result:=False;
  if not FConnection.Connected then Exit;
  N:=FObjects.Selected;
  while N<>nil do begin
    Kind:=PtrUInt(N.Data);
    if Kind=200 then Exit(N.Text=FSettings.Name);
    if Kind=300 then Exit(N.Text=TreeServerLabel(FSettings));
    N:=N.Parent;
  end;
end;

procedure TConsoleForm.UpdateQueryHistoryButtons;
begin
  if Assigned(FPreviousQueryTool) then
    FPreviousQueryTool.Enabled:=(FQueryHistory.Count>0) and (FQueryHistoryIndex<>0);
  if Assigned(FNextQueryTool) then
    FNextQueryTool.Enabled:=FQueryHistoryIndex>=0;
end;

procedure TConsoleForm.SQLChanged(Sender:TObject);
begin
  if (FQueryHistoryIndex>=0) and not FQueryNavigating then begin
    FQueryHistoryIndex:=-1;FQueryDraft:='';
    UpdateQueryHistoryButtons;
  end;
end;

procedure TConsoleForm.AddQueryToHistory(const SQL:string);
begin
  if (FQueryHistory.Count=0) or (FQueryHistory[FQueryHistory.Count-1]<>SQL) then
    FQueryHistory.Add(SQL);
  while FQueryHistory.Count>100 do FQueryHistory.Delete(0);
  FQueryHistoryIndex:=-1;FQueryDraft:='';
  UpdateQueryHistoryButtons;
end;

procedure TConsoleForm.PreviousQuery(Sender:TObject);
begin
  if FQueryHistory.Count=0 then Exit;
  if FQueryHistoryIndex<0 then begin
    FQueryDraft:=FSQL.Text;
    FQueryHistoryIndex:=FQueryHistory.Count-1;
  end else if FQueryHistoryIndex>0 then Dec(FQueryHistoryIndex)
  else Exit;
  FQueryNavigating:=True;
  try FSQL.Text:=FQueryHistory[FQueryHistoryIndex];finally FQueryNavigating:=False;end;
  FSQL.SelStart:=Length(FSQL.Text);
  UpdateQueryHistoryButtons;
end;

procedure TConsoleForm.NextQuery(Sender:TObject);
begin
  if FQueryHistoryIndex<0 then Exit;
  if FQueryHistoryIndex<FQueryHistory.Count-1 then begin
    Inc(FQueryHistoryIndex);
    FQueryNavigating:=True;
    try FSQL.Text:=FQueryHistory[FQueryHistoryIndex];finally FQueryNavigating:=False;end;
  end else begin
    FQueryHistoryIndex:=-1;
    FQueryNavigating:=True;
    try FSQL.Text:=FQueryDraft;finally FQueryNavigating:=False;end;
    FQueryDraft:='';
  end;
  FSQL.SelStart:=Length(FSQL.Text);
  UpdateQueryHistoryButtons;
end;

procedure TConsoleForm.AppendResultRow(Q:TSQLQuery; Row:Integer);
var Col:Integer;
begin
  FGrid.RowCount:=Row+1;
  for Col:=0 to Q.FieldCount-1 do
    if Q.Fields[Col].IsNull then FGrid.Cells[Col,Row]:='<NULL>'
    else if Q.Fields[Col].DataType=ftBlob then FGrid.Cells[Col,Row]:='<BLOB>'
    else FGrid.Cells[Col,Row]:=Q.Fields[Col].AsString;
end;

procedure TConsoleForm.HistoryPopup(Sender:TObject);
var HistoryMenu:TPopupMenu; Item:TMenuItem; Index,Step:Integer;
begin
  HistoryMenu:=TPopupMenu(Sender);
  HistoryMenu.Items.Clear;
  if HistoryMenu=FPreviousQueryTool.DropDownMenu then Step:=-1 else Step:=1;
  Index:=FQueryHistoryIndex;
  if Index<0 then Index:=FQueryHistory.Count;
  Inc(Index,Step);
  while (Index>=0) and (Index<FQueryHistory.Count) do begin
    Item:=TMenuItem.Create(HistoryMenu);
    Item.Caption:=StringReplace(UTF8Copy(Trim(StringReplace(FQueryHistory[Index],LineEnding,' ',[rfReplaceAll])),1,80),'&','&&',[rfReplaceAll]);
    Item.Tag:=Index;
    Item.OnClick:=@ChooseHistory;
    HistoryMenu.Items.Add(Item);
    Inc(Index,Step);
  end;
  if (Step=1) and (FQueryHistoryIndex>=0) then begin
    Item:=TMenuItem.Create(HistoryMenu);
    Item.Caption:='編集中のSQLに戻る';
    Item.Tag:=-1;
    Item.OnClick:=@ChooseHistory;
    HistoryMenu.Items.Add(Item);
  end;
end;

procedure TConsoleForm.ChooseHistory(Sender:TObject);
begin
  if FQueryHistoryIndex<0 then FQueryDraft:=FSQL.Text;
  FQueryHistoryIndex:=TMenuItem(Sender).Tag;
  FQueryNavigating:=True;
  try
    if FQueryHistoryIndex<0 then FSQL.Text:=FQueryDraft
    else FSQL.Text:=FQueryHistory[FQueryHistoryIndex];
  finally
    FQueryNavigating:=False;
  end;
  FSQLTabs.ActivePage:=FSQLSheet;
  UpdateQueryHistoryButtons;
end;

procedure TConsoleForm.PrepareSQL(Sender:TObject);
var Q:TSQLQuery; Status:array[0..19] of ISC_STATUS; Buf:array[0..32766] of AnsiChar;
    StmtHandle:isc_stmt_handle; Request:AnsiChar; Plan:string; Size:Integer; Started:Boolean;
begin
  RequireConnection;
  if Trim(FSQL.Text)='' then Exit;
  Started:=not FTransaction.Active;
  Q:=NewQuery;
  try
    try
      Q.ParamCheck:=FUseParams.Checked;
      Q.SQL.Text:=FSQL.Text;
      Q.Prepare;
      StmtHandle:=isc_stmt_handle(TPlanCursor(TPlanQuery(Q).Cursor).StatementHandle);
      Request:=Chr(isc_info_sql_get_plan);
      FillChar(Buf,SizeOf(Buf),0);
      if isc_dsql_sql_info(@Status[0],@StmtHandle,1,@Request,SizeOf(Buf),@Buf[0])<>0 then
        raise Exception.Create('Firebirdから実行計画を取得できませんでした。');
      if Buf[0]=Chr(isc_info_sql_get_plan) then begin
        Size:=Ord(Buf[1])+256*Ord(Buf[2]);
        if Size>SizeOf(Buf)-3 then raise Exception.Create('実行計画が応答サイズを超えました。');
        SetString(Plan,PAnsiChar(@Buf[3]),Size);
      end else if Buf[0]=Chr(isc_info_truncated) then
        raise Exception.Create('実行計画が応答サイズを超えました。');
      if Trim(Plan)='' then Plan:='このSQLに表示する実行計画はありません。';
      FSQLPlan.Text:=Trim(Plan);
      FResultTabs.ActivePage:=FPlanSheet;
    except on E:Exception do begin
      FSQLPlan.Clear;
      FResultTabs.ActivePage:=FErrorsSheet;
      Log('前処理エラー: '+E.Message);
    end;end;
  finally
    Q.Free;
    if Started and FTransaction.Active then FTransaction.Rollback;
  end;
end;

procedure TConsoleForm.PrintSQL(Sender:TObject);
var Dialog:TPrintDialog; I,Y,Margin,LineHeight,PrintWidth,Count:Integer; S,Part:string;
begin
  if Trim(FSQL.Text)='' then Exit;
  Dialog:=TPrintDialog.Create(FSQLWindow);
  try
    if not Dialog.Execute then Exit;
    Printer.Title:='FBConsole SQL';
    Printer.BeginDoc;
    try
      Printer.Canvas.Font.Name:='Consolas';
      Printer.Canvas.Font.Size:=10;
      LineHeight:=Max(1,Printer.Canvas.TextHeight('Agあ')*5 div 4);
      Margin:=LineHeight*2;
      PrintWidth:=Max(1,Printer.PageWidth-2*Margin);
      Y:=Margin;
      for I:=0 to FSQL.Lines.Count-1 do begin
        S:=StringReplace(FSQL.Lines[I],#9,'    ',[rfReplaceAll]);
        repeat
          Count:=Min(256,UTF8Length(S));
          Part:=UTF8Copy(S,1,Count);
          while (Count>1) and (Printer.Canvas.TextWidth(Part)>PrintWidth) do begin
            Dec(Count);
            Part:=UTF8Copy(S,1,Count);
          end;
          if Y+LineHeight>Printer.PageHeight-Margin then begin Printer.NewPage;Y:=Margin;end;
          Printer.Canvas.TextOut(Margin,Y,Part);
          Inc(Y,LineHeight);
          Delete(S,1,Length(Part));
        until S='';
      end;
      Printer.EndDoc;
    except
      if Printer.Printing then Printer.Abort;
      raise;
    end;
  finally Dialog.Free;end;
end;
procedure TConsoleForm.FetchAllClick(Sender:TObject);
begin
  if Sender=FFetchAllMenu then FFetchAllTool.Down:=not FFetchAllTool.Down;
  if Assigned(FFetchAllMenu) then FFetchAllMenu.Checked:=FFetchAllTool.Down;
  if FFetchAllTool.Down and Assigned(FRemainingRows) and FRemainingRows.Active then
  begin
    try
      while not FRemainingRows.EOF do begin
        AppendResultRow(FRemainingRows,FResultRows+1);
        Inc(FResultRows);
        FRemainingRows.Next;
      end;
      FResultTabs.ActivePage:=FDataSheet;
      Log(IntToStr(FResultRows)+' 行を取得しました。');
    finally
      FreeAndNil(FRemainingRows);
    end;
  end;
  if FFetchAllTool.Down then
    Log('全件取得を有効にしました。次回のSELECT実行で全行を読み込みます。')
  else
    Log('全件取得を解除しました。次回のSELECTは1000行まで読み込みます。');
end;

procedure TConsoleForm.FindSQLText(Sender:TObject);
var FindText,SQLText:string; I,StartAt,FoundAt:Integer;
begin
  FindText:='';
  if not InputQuery('SQL内を検索','検索する文字列:',FindText) or (FindText='') then Exit;
  SQLText:=FSQL.Text;
  StartAt:=FSQL.SelStart+FSQL.SelLength+1;
  FoundAt:=0;
  for I:=StartAt to Length(SQLText)-Length(FindText)+1 do
    if SameText(Copy(SQLText,I,Length(FindText)),FindText) then begin FoundAt:=I;Break;end;
  if FoundAt=0 then
    for I:=1 to Min(StartAt-1,Length(SQLText)-Length(FindText)+1) do
      if SameText(Copy(SQLText,I,Length(FindText)),FindText) then begin FoundAt:=I;Break;end;
  if FoundAt=0 then begin
    MessageDlg('SQL内を検索','文字列が見つかりません。',mtInformation,[mbOK],0);
    Exit;
  end;
  FSQL.SetFocus;FSQL.SelStart:=FoundAt-1;FSQL.SelLength:=Length(FindText);
end;

procedure TConsoleForm.WindowMenuPopup(Sender:TObject);
var Item:TMenuItem; K:Integer;
  procedure AddWindow(const ACaption:string;ImageIndex,TagValue:Integer);
  begin
    Item:=TMenuItem.Create(FWindowMenu);Item.Caption:=ACaption;
    Item.ImageIndex:=ImageIndex;Item.Tag:=TagValue;Item.OnClick:=@WindowMenuClick;
    FWindowMenu.Items.Add(Item);
  end;
begin
  FWindowMenu.Items.Clear;
  AddWindow('FBConsole',icServers,0);
  AddWindow('対話型SQL',icSQL,1);
  if FTables.Count>0 then FWindowMenu.Items.Add(TMenuItem.Create(FWindowMenu));
  for K:=0 to FTables.Count-1 do
    AddWindow(TTableWindow(FTables[K]).Caption,icTable,K+2);
end;

procedure TConsoleForm.SwitchSQLWindow(Sender:TObject);
var Target:TForm;
begin
  if FTables.Count>0 then Target:=TForm(FTables[0]) else Target:=Self;
  if Target.WindowState=wsMinimized then Target.WindowState:=wsNormal;
  Target.Show;
  Target.BringToFront;
end;

procedure TConsoleForm.WindowMenuClick(Sender:TObject);
var Index:Integer; W:TForm;
begin
  Index:=TMenuItem(Sender).Tag;
  if Index=0 then W:=Self
  else if Index=1 then W:=FSQLWindow
  else if (Index>=2) and (Index-2<FTables.Count) then W:=TForm(FTables[Index-2])
  else Exit;
  if W.WindowState=wsMinimized then W.WindowState:=wsNormal;
  W.Show;W.BringToFront;
end;

procedure TConsoleForm.ExecuteClick(Sender: TObject);
var Q: TSQLQuery; Statements:TStringList; R, C, K, TotalAffected: Integer;
    HasMore, IsResultStatement, ShowResult: Boolean; StartTick,ElapsedMS:QWord;
    RowsText,RowLimitText,Value,StatementText,UpperStatement:string;
  function UsesPSQLSyntax(const S:string):Boolean;
  var T:string;
  begin
    T:=UpperCase(TrimLeft(S));
    Result:=(Pos('EXECUTE BLOCK',T)=1) or (Pos('CREATE PROCEDURE',T)=1) or
      (Pos('ALTER PROCEDURE',T)=1) or (Pos('RECREATE PROCEDURE',T)=1) or
      (Pos('CREATE FUNCTION',T)=1) or (Pos('ALTER FUNCTION',T)=1) or
      (Pos('RECREATE FUNCTION',T)=1) or (Pos('CREATE TRIGGER',T)=1) or
      (Pos('ALTER TRIGGER',T)=1) or (Pos('RECREATE TRIGGER',T)=1) or
      (Pos('CREATE PACKAGE',T)=1) or (Pos('ALTER PACKAGE',T)=1) or
      (Pos('RECREATE PACKAGE',T)=1);
  end;
begin
  RequireConnection;
  if Trim(FSQL.Text) = '' then Exit;
  Statements:=SplitFirebirdScript(FSQL.Text);
  try
    if Statements.Count=0 then Exit;
    AddQueryToHistory(FSQL.Text);
    FreeAndNil(FRemainingRows);
    StartTick:=GetTickCount64;
    TotalAffected:=0;
    RowsText:='0';
    Q:=nil;
    Screen.Cursor:=crHourGlass;
    try
      try
        FPending:=True;
        FResultRows:=-1;
        FGrid.ColCount:=1;
        FGrid.RowCount:=2;
        FGrid.Cells[0,0]:='実行結果';
        FGrid.Cells[0,1]:='';
        for K:=0 to Statements.Count-1 do
        begin
          StatementText:=Trim(Statements[K]);
          UpperStatement:=UpperCase(StatementText);
          Q:=NewQuery;
          try
            Q.ParamCheck:=FUseParams.Checked and not UsesPSQLSyntax(StatementText);
            Q.SQL.Text:=StatementText;
            for C:=0 to Q.Params.Count-1 do
            begin
              Value:='';
              if not InputQuery('SQLパラメータ','値を入力してください  :'+Q.Params[C].Name,Value) then
                raise Exception.Create('SQLパラメータ入力がキャンセルされました。');
              Q.Params[C].AsString:=Value;
            end;
            Q.Prepare;
            if Q.StatementType in [stStartTrans,stCommit,stRollback] then
              raise Exception.Create('トランザクションは画面のコミット／ロールバックボタンで操作してください。');

            IsResultStatement:=Q.StatementType in [stSelect,stExecProcedure];
            if (not IsResultStatement) and FReturnsRows.Checked then
              IsResultStatement:=Pos(' RETURNING ', ' '+UpperStatement+' ')>0;
            ShowResult:=IsResultStatement and FReturnsRows.Checked;
            if IsResultStatement then
            begin
              Q.Open;
              if ShowResult then
              begin
                FGrid.RowCount:=2;
                FGrid.ColCount:=Max(1,Q.FieldCount);
                for C:=0 to Q.FieldCount-1 do
                  FGrid.Cells[C,0]:=Q.Fields[C].FieldName;
                R:=1;
                while (not Q.EOF) and (FFetchAllTool.Down or (R<=1000)) do
                begin
                  AppendResultRow(Q,R);
                  Inc(R);
                  Q.Next;
                end;
                HasMore:=not Q.EOF;
                FResultRows:=R-1;
                RowsText:=IntToStr(R-1);
                if R=1 then
                begin
                  FGrid.RowCount:=2;
                  for C:=0 to FGrid.ColCount-1 do FGrid.Cells[C,1]:='';
                end;
                Log(Format('SQL %d/%d: %d 行を表示しました。',[K+1,Statements.Count,R-1]));
                FResultTabs.ActivePage:=FDataSheet;
              end
              else
              begin
                while not Q.EOF do Q.Next;
                HasMore:=False;
              end;
              if HasMore and (K=Statements.Count-1) then
              begin
                FRemainingRows:=Q;
                Q:=nil;
                Log('残りの行は「全件取得」で読み込めます。');
              end;
              if HasMore then Log('後続SQLがあるため、この結果は先頭1000行まで表示します。');
            end
            else
            begin
              Q.ExecSQL;
              if Q.RowsAffected>0 then Inc(TotalAffected,Q.RowsAffected);
              Log(Format('SQL %d/%dを実行しました。影響行数: %d',[K+1,Statements.Count,Q.RowsAffected]));
            end;
          finally
            Q.Free;
            Q:=nil;
          end;
        end;
        ElapsedMS:=GetTickCount64-StartTick;
        if not FReturnsRows.Checked then RowLimitText:='結果表示なし'
        else if FFetchAllTool.Down then RowLimitText:='全件取得'
        else RowLimitText:='1000行';
        FSQLStats.Lines.Text:='実行時間: '+IntToStr(ElapsedMS)+' ms'+LineEnding+
          '文数: '+IntToStr(Statements.Count)+LineEnding+
          '影響行数: '+IntToStr(TotalAffected)+LineEnding+
          '最終結果行数: '+RowsText+LineEnding+
          '結果表示上限: '+RowLimitText+LineEnding+'トランザクション: 未確定';
        FResultTabs.ActivePage:=FStatsSheet;
        FSQL.Clear;
      except
        on E:Exception do
        begin
          ElapsedMS:=GetTickCount64-StartTick;
          FSQLStats.Lines.Text:='失敗までの時間: '+IntToStr(ElapsedMS)+' ms'+LineEnding+
            '実行済み文数: '+IntToStr(K);
          FResultTabs.ActivePage:=FErrorsSheet;
          Log('SQLスクリプト '+IntToStr(K+1)+'/'+IntToStr(Statements.Count)+' でエラー: '+E.Message);
        end;
      end;
    finally
      Q.Free;
      Screen.Cursor:=crDefault;
      UpdateStatus;
    end;
  finally
    Statements.Free;
  end;
end;

procedure TConsoleForm.CommitClick(Sender: TObject);
begin
  RequireConnection;
  FreeAndNil(FRemainingRows);
  if FTransaction.Active then FTransaction.Commit;
  FPending := False;
  Log('コミットしました。');
  UpdateStatus;
end;

procedure TConsoleForm.RollbackClick(Sender: TObject);
begin
  RequireConnection;
  FreeAndNil(FRemainingRows);
  if FTransaction.Active then FTransaction.Rollback;
  FPending := False;
  Log('ロールバックしました。表示結果は実行時点のものです。');
  UpdateStatus;
end;

procedure TConsoleForm.ExportClick(Sender: TObject);
var D: TSaveDialog; Lines: TStringList; R, C: Integer; S: string;
begin
  if FResultRows < 0 then
    raise Exception.Create('先に結果を返すSQLを実行してください。');
  D := TSaveDialog.Create(nil);
  Lines := TStringList.Create;
  try
    D.Filter := 'CSV UTF-8|*.csv';
    D.DefaultExt := 'csv';
    D.Options := D.Options + [ofOverwritePrompt];
    if not D.Execute then Exit;
    for R := 0 to FResultRows do
    begin
      S := '';
      for C := 0 to FGrid.ColCount - 1 do
      begin
        if C > 0 then S := S + ',';
        S := S + CSVCell(FGrid.Cells[C, R]);
      end;
      Lines.Add(S);
    end;
    Lines.SaveToFile(D.FileName);
    Log(IntToStr(FResultRows)+'行をCSVに保存しました。NULLは<NULL>、バイナリBLOBは<BLOB>です。');
  finally
    Lines.Free;
    D.Free;
  end;
end;

procedure TConsoleForm.SaveProfile(Sender: TObject);
begin
  WriteSettings(FConfig, FSettings);
  if FProfiles.IndexOf(FSettings.Name) < 0 then FProfiles.Add(FSettings.Name);
  if FConnection.Connected then RefreshObjects(nil) else RebuildTree;
  Log('接続設定を保存しました（パスワードを除く）。');
end;

procedure TConsoleForm.LoadSQL(Sender: TObject);
var D: TOpenDialog;
begin
  D := TOpenDialog.Create(nil);
  try
    D.Filter := 'SQL UTF-8|*.sql|All files|*';
    if D.Execute then
    begin
      FSQL.Lines.LoadFromFile(D.FileName);
      OpenSQL(nil);
    end;
  finally
    D.Free;
  end;
end;

procedure TConsoleForm.SaveSQL(Sender: TObject);
var D: TSaveDialog;
begin
  D := TSaveDialog.Create(nil);
  try
    D.Filter := 'SQL UTF-8|*.sql';
    D.DefaultExt := 'sql';
    D.Options := D.Options + [ofOverwritePrompt];
    if D.Execute then FSQL.Lines.SaveToFile(D.FileName);
  finally
    D.Free;
  end;
end;

procedure TConsoleForm.ShowDefinition(Sender: TObject);
var N, S: string; K: PtrUInt;
begin
  if (FObjects.Selected = nil) or (FObjects.Selected.Data = nil) then Exit;
  if PtrUInt(FObjects.Selected.Data) >= 100 then Exit;
  N := QuotedStr(FObjects.Selected.Text);
  K := PtrUInt(FObjects.Selected.Data);
  case K of
    1, 2: S := 'SELECT TRIM(RF.RDB$FIELD_NAME) AS COLUMN_NAME, ' +
      'RF.RDB$FIELD_POSITION AS COLUMN_POSITION, F.RDB$FIELD_TYPE AS TYPE_CODE, ' +
      'F.RDB$FIELD_SUB_TYPE AS SUB_TYPE, F.RDB$FIELD_LENGTH AS BYTE_LENGTH, ' +
      'F.RDB$FIELD_PRECISION AS NUMERIC_PRECISION, F.RDB$FIELD_SCALE AS SCALE, ' +
      'RF.RDB$NULL_FLAG AS NOT_NULL_FLAG, RF.RDB$DEFAULT_SOURCE AS DEFAULT_SQL, ' +
      'F.RDB$COMPUTED_SOURCE AS COMPUTED_SQL ' +
      'FROM RDB$RELATION_FIELDS RF JOIN RDB$FIELDS F ON F.RDB$FIELD_NAME=RF.RDB$FIELD_SOURCE ' +
      'WHERE RF.RDB$RELATION_NAME=' + N + ' ORDER BY RF.RDB$FIELD_POSITION';
    3: S := 'SELECT RDB$PROCEDURE_SOURCE AS SOURCE_SQL FROM RDB$PROCEDURES WHERE RDB$PROCEDURE_NAME=' + N;
    4: S := 'SELECT RDB$TRIGGER_SOURCE AS SOURCE_SQL, RDB$TRIGGER_TYPE AS TRIGGER_TYPE, RDB$TRIGGER_INACTIVE AS INACTIVE FROM RDB$TRIGGERS WHERE RDB$TRIGGER_NAME=' + N;
    5: S := 'SELECT RDB$GENERATOR_NAME AS SEQUENCE_NAME, RDB$INITIAL_VALUE AS INITIAL_VALUE, '+
      'RDB$GENERATOR_INCREMENT AS INCREMENT_BY, RDB$SYSTEM_FLAG AS SYSTEM_FLAG, '+
      'RDB$DESCRIPTION AS DESCRIPTION, GEN_ID('+QuoteIdentifier(FObjects.Selected.Text)+
      ', 0) AS CURRENT_VALUE FROM RDB$GENERATORS WHERE RDB$GENERATOR_NAME='+N;
    6: S := 'SELECT RDB$FIELD_TYPE AS TYPE_CODE, RDB$FIELD_PRECISION AS NUMERIC_PRECISION, RDB$FIELD_SCALE AS SCALE, RDB$DEFAULT_SOURCE AS DEFAULT_SQL, RDB$VALIDATION_SOURCE AS CHECK_SQL FROM RDB$FIELDS WHERE RDB$FIELD_NAME=' + N;
    7: S := 'SELECT TRIM(I.RDB$RELATION_NAME) AS TABLE_NAME, I.RDB$UNIQUE_FLAG AS UNIQUE_FLAG, I.RDB$INDEX_INACTIVE AS INACTIVE, TRIM(S.RDB$FIELD_NAME) AS COLUMN_NAME, S.RDB$FIELD_POSITION AS COLUMN_POSITION FROM RDB$INDICES I LEFT JOIN RDB$INDEX_SEGMENTS S ON S.RDB$INDEX_NAME=I.RDB$INDEX_NAME WHERE I.RDB$INDEX_NAME=' + N + ' ORDER BY S.RDB$FIELD_POSITION';
    8: S := 'SELECT RDB$FUNCTION_NAME AS FUNCTION_NAME, RDB$MODULE_NAME AS MODULE_NAME, ' +
      'RDB$ENGINE_NAME AS ENGINE_NAME, RDB$ENTRYPOINT AS ENTRYPOINT, ' +
      'RDB$FUNCTION_SOURCE AS SOURCE_SQL, RDB$DESCRIPTION AS DESCRIPTION ' +
      'FROM RDB$FUNCTIONS WHERE RDB$FUNCTION_NAME=' + N +
      ' AND RDB$PACKAGE_NAME IS NULL AND '+
      '(RDB$MODULE_NAME IS NOT NULL OR RDB$ENGINE_NAME IS NOT NULL)';
    12: S := 'SELECT RDB$FUNCTION_NAME AS FILTER_NAME, RDB$MODULE_NAME AS MODULE_NAME, '+
      'RDB$ENTRYPOINT AS ENTRYPOINT, RDB$INPUT_SUB_TYPE AS INPUT_SUB_TYPE, '+
      'RDB$OUTPUT_SUB_TYPE AS OUTPUT_SUB_TYPE, RDB$DESCRIPTION AS DESCRIPTION '+
      'FROM RDB$FILTERS WHERE RDB$FUNCTION_NAME='+N;
    9: S := 'SELECT RDB$MESSAGE AS MESSAGE FROM RDB$EXCEPTIONS WHERE RDB$EXCEPTION_NAME=' + N;
    10: S := 'SELECT RDB$ROLE_NAME AS ROLE_NAME, RDB$OWNER_NAME AS OWNER_NAME FROM RDB$ROLES WHERE RDB$ROLE_NAME=' + N;
    11: S := 'SELECT RDB$PACKAGE_HEADER_SOURCE AS HEADER_SQL, RDB$PACKAGE_BODY_SOURCE AS BODY_SQL FROM RDB$PACKAGES WHERE RDB$PACKAGE_NAME=' + N;
    13: S := 'SELECT RDB$PACKAGE_NAME AS PACKAGE_NAME, RDB$FUNCTION_NAME AS ROUTINE_NAME, '+
      'RDB$FUNCTION_SOURCE AS SOURCE_SQL, RDB$DESCRIPTION AS DESCRIPTION '+
      'FROM RDB$FUNCTIONS WHERE RDB$PACKAGE_NAME='+QuotedStr(FObjects.Selected.Parent.Text)+
      ' AND RDB$FUNCTION_NAME='+N;
    14: S := 'SELECT RDB$PACKAGE_NAME AS PACKAGE_NAME, RDB$PROCEDURE_NAME AS ROUTINE_NAME, '+
      'RDB$PROCEDURE_SOURCE AS SOURCE_SQL, RDB$DESCRIPTION AS DESCRIPTION '+
      'FROM RDB$PROCEDURES WHERE RDB$PACKAGE_NAME='+QuotedStr(FObjects.Selected.Parent.Text)+
      ' AND RDB$PROCEDURE_NAME='+N;
    else Exit;
  end;
  FSQL.Text := S;
  FReturnsRows.Checked := True;
  OpenSQL(nil);
  ExecuteClick(nil);
end;

procedure TConsoleForm.AboutClick(Sender: TObject);
begin
  ShowAboutDialog(Self);
end;

procedure TConsoleForm.RunSmokeTest(const ClientLibrary, DatabasePath, ReportPath: string);
var N: TTreeNode;Q:TSQLQuery;TestWindow:TTableWindow;MetadataLines:TStringList;
    BuilderIndex,ButtonIndex,RightEdge:Integer;
    Bar:TToolBar;
    Button:TToolButton;
begin
  // Invoked only with --smoke-test against the scratch integration database.
  // No profile or password is saved, and all query transactions are rolled back.
  FSettings := DefaultSettings;
  FSettings.Name := 'Smoke test';
  FSettings.ClientLibrary := ClientLibrary;
  FSettings.Database := DatabasePath;
  FSettings.Mode := cmConnectionString;
  ConnectTo(FSettings, '');
  if not FConnection.Connected then
    raise Exception.Create('Smoke test: connection failed: ' + FLog.Text);
  if FObjects.Items.Count < 14 then
    raise Exception.Create('Smoke test: catalog tree not populated');
  OpenSQL(nil);
  if (FSQLTabs.ActivePage<>FSQLSheet) or (FSQL.Text<>'') then
    raise Exception.Create('Smoke test: initial SQL editor must be visible and empty');
  BuilderIndex:=FSQLCatalog.Items.IndexOf('TX_TEST');
  if BuilderIndex<0 then raise Exception.Create('Smoke test: SQL catalog missing test table');
  FSQLCatalog.ItemIndex:=BuilderIndex;
  SQLCatalogClick(nil);
  AddSQLTable(nil);
  FSQLFields.ItemIndex:=FSQLFields.Items.IndexOf('ID');
  AddSQLField(nil);
  FUseTableAlias.Checked:=True;
  FBuilderGrid.Cells[4,1]:='DESC';
  UpdateBuilderSQL(nil);
  if (Pos('SELECT T1."ID"',FSQL.Text)=0) or
     (Pos('FROM "TX_TEST" AS T1',FSQL.Text)=0) or
     (Pos('ORDER BY T1."ID" DESC',FSQL.Text)=0) then
    raise Exception.Create('Smoke test: query builder SQL generation mismatch: '+FSQL.Text);
  Log('PASS: SQL catalog, field list, table alias, sort and SELECT generation.');
  N := FObjects.Items.GetFirstNode;
  while (N <> nil) and (N.Text <> 'TX_TEST') do N := N.GetNext;
  if N = nil then raise Exception.Create('Smoke test: table missing');
  FObjects.Selected := N;
  TreeChanged(nil, N.Parent);
  if (FList.Items.Count < 1) or (FList.Items[0].Caption <> 'TX_TEST') then
    raise Exception.Create('Smoke test: right pane object list mismatch');
  BrowseObject(nil);
  if FTables.Count<>1 then raise Exception.Create('Table properties window missing');
  TTableWindow(FTables[0]).RunSelfTest;
  Q:=NewQuery;
  try
    Q.SQL.Text:='CREATE TABLE FBCONSOLE_EDIT_TEST (WORK_DATE DATE NOT NULL, UID VARCHAR(32) NOT NULL, '+
      'IN_TIME TIME, OUT_TIME TIME, WORK_HOURS NUMERIC(5,2), NOTE VARCHAR(80) CHARACTER SET UTF8, '+
      'GENERATED_VALUE INTEGER GENERATED BY DEFAULT AS IDENTITY, WIDE_VALUE INT128, REF_ID INTEGER, '+
      'TOTAL COMPUTED BY (WORK_HOURS*2), PRIMARY KEY(WORK_DATE,UID), CHECK(WORK_HOURS>=0), '+
      'CONSTRAINT FK_FBCONSOLE_REF FOREIGN KEY(REF_ID) REFERENCES TX_TEST(ID))';
    Q.ExecSQL;FTransaction.Commit;
    try
      TestWindow:=TTableWindow.CreateTable(Self,FConnection,'FBCONSOLE_EDIT_TEST',False);
      try TestWindow.RunCompositeSelfTest;finally TestWindow.Free;end;
      MetadataLines:=ExtractDatabaseMetadata(FConnection,FTransaction);
      try
        if MetadataLines.IndexOf('CREATE TABLE "FBCONSOLE_EDIT_TEST" (')<0 then
          raise Exception.Create('Smoke test: database metadata missing table DDL');
        if MetadataLines.IndexOf('  CONSTRAINT "INTEG_5" PRIMARY KEY ("WORK_DATE", "UID")')<0 then
          if Pos('PRIMARY KEY ("WORK_DATE", "UID")',MetadataLines.Text)=0 then
            raise Exception.Create('Smoke test: database metadata missing composite primary key');
        if Pos('FOREIGN KEY ("REF_ID") REFERENCES "TX_TEST" ("ID")',MetadataLines.Text)=0 then
          raise Exception.Create('Smoke test: database metadata missing foreign key');
        if (Pos('CHECK',MetadataLines.Text)=0) or (Pos('WORK_HOURS',MetadataLines.Text)=0) then
          raise Exception.Create('Smoke test: database metadata missing check constraint');
      finally MetadataLines.Free;end;
    finally
      Q.SQL.Text:='DROP TABLE FBCONSOLE_EDIT_TEST';Q.ExecSQL;FTransaction.Commit;
    end;
  finally Q.Free;end;
  DatabaseProperties(nil);ConnectedUsers(nil);DatabaseStatistics(nil);
  ShowDefinition(nil);
  if (FResultRows <> 1) or (FGrid.Cells[0, 1] <> 'ID') then
    raise Exception.Create('Smoke test: column metadata mismatch: ' + FLog.Text);
  RollbackClick(nil);
  FSQL.Text := 'SELECT CAST(12345678901234567890123456789012345678 AS INT128) AS I FROM RDB$DATABASE';
  FReturnsRows.Checked := True;
  ExecuteClick(nil);
  if FGrid.Cells[0, 1] <> '12345678901234567890123456789012345678' then
    raise Exception.Create('Smoke test: INT128 mismatch');
  RollbackClick(nil);
  FSQLWindow.Width:=FSQLWindow.Constraints.MinWidth;
  FSQLWindow.Show;
  Application.ProcessMessages;
  Bar:=TToolBar(FFetchAllTool.Parent);
  RightEdge:=0;
  for ButtonIndex:=0 to Bar.ButtonCount-1 do begin
    Button:=Bar.Buttons[ButtonIndex];
    if (Button.Top<>Bar.Buttons[0].Top) or (Button.Left<RightEdge) or
       (Button.Left+Button.Width>Bar.ClientWidth) or
       (Button.Top+Button.Height>Bar.ClientHeight) then
      raise Exception.CreateFmt('Smoke test: clipped SQL toolbar button %d (%d,%d %dx%d in %dx%d)',
        [ButtonIndex,Button.Left,Button.Top,Button.Width,Button.Height,Bar.ClientWidth,Bar.ClientHeight]);
    RightEdge:=Button.Left+Button.Width;
  end;
  if (FUseParams.Left<FFetchAllTool.Parent.Left+FFetchAllTool.Parent.Width) or
     (FReturnsRows.Left<FUseParams.Left+FUseParams.Width) or
     (FReturnsRows.Left+FReturnsRows.Width>FReturnsRows.Parent.ClientWidth) then
    raise Exception.CreateFmt('Smoke test: SQL toolbar layout (%d %d %d %d %d %d)',
      [FFetchAllTool.Parent.Width,FUseParams.Left,FUseParams.Width,FReturnsRows.Left,FReturnsRows.Width,FReturnsRows.Parent.ClientWidth]);
  FSQL.Text:='SELECT ID FROM TX_TEST WHERE ID=:id';
  PrepareSQL(nil);
  if (FResultTabs.ActivePage<>FPlanSheet) or (Pos('TX_TEST',UpperCase(FSQLPlan.Text))=0) then
    raise Exception.Create('Smoke test: missing Firebird plan: '+FSQLPlan.Text);
  FSQL.Text:='SELECT FIRST 1010 A.RDB$FIELD_NAME FROM RDB$RELATION_FIELDS A CROSS JOIN RDB$RELATION_FIELDS B';
  ExecuteClick(nil);
  if FSQL.Text<>'' then raise Exception.Create('Smoke test: executed SQL still in editor');
  PreviousQuery(nil);
  if Pos('SELECT FIRST 1010',FSQL.Text)<>1 then raise Exception.Create('Smoke test: executed SQL not recalled');
  NextQuery(nil);
  if FSQL.Text<>'' then raise Exception.Create('Smoke test: draft should be empty');
  if FResultRows<>1000 then raise Exception.Create('Smoke test: initial fetch limit');
  FetchAllClick(FFetchAllMenu);
  if FResultRows<>1010 then raise Exception.Create('Smoke test: fetch remaining rows');
  RollbackClick(nil);
  FSQL.Text:='SELECT FROM';
  ExecuteClick(nil);
  if (FResultTabs.ActivePage<>FErrorsSheet) or (Trim(FSQL.Text)<>'SELECT FROM') then
    raise Exception.Create('Smoke test: failed SQL should remain editable');
  FSQL.Text:='draft';
  HistoryPopup(FPreviousQueryTool.DropDownMenu);
  ChooseHistory(FPreviousQueryTool.DropDownMenu.Items[0]);
  NextQuery(nil);
  if Trim(FSQL.Text)<>'draft' then raise Exception.Create('Smoke test: history draft');
  if not EndSession then raise Exception.Create('Smoke test: disconnect failed');
  if FSQLWindow.Visible then raise Exception.Create('Smoke test: SQL window not hidden on disconnect');
  if FObjects.Items.Count < 3 then raise Exception.Create('Smoke test: registrations lost on disconnect');
  Log('PASS: connection, tree/actions, table property tabs, scalar/composite-key CRUD, date/time/decimal/UTF8/NULL, identity/computed columns, failed apply rollback, monitoring queries, database metadata extraction, INT128, disconnect.');
  FLog.Lines.SaveToFile(ReportPath);
end;

{$IFDEF MULTIDB_TEST}{$I tests/multidb.inc}{$ENDIF}
end.








