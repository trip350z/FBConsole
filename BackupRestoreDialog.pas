unit BackupRestoreDialog;

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses Classes, FirebirdServices;

function ExecuteBackupRestoreDialog(AOwner:TComponent; Operation:TServiceOperation;
  const ServerName:string; var DatabasePath:string; BackupFiles:TStrings;
  var Options:TServiceOptions):Boolean;

implementation

uses SysUtils, StrUtils, Forms, Controls, StdCtrls, ExtCtrls, Grids, Graphics, Types, Dialogs, AppTheme;

type
  TBackupRestoreForm=class(TForm)
  private
    FOperation:TServiceOperation;
    FDatabase:TEdit;
    FFiles:TStringGrid;
    FFileName:TEdit;
    FRemoveFile:TButton;
    FOptions:TStringGrid;
    procedure AddFile(Sender:TObject);
    procedure RemoveFile(Sender:TObject);
    procedure CycleOption(Sender:TObject);
    procedure DrawOptionCell(Sender:TObject;ACol,ARow:Integer;Rect:TRect;State:TGridDrawState);
    procedure LayoutFileList(Sender:TObject);
    procedure Accept(Sender:TObject);
    procedure FillOptions;
    procedure ReadOptions(var AOptions:TServiceOptions);
  public
    constructor CreateDialog(AOwner:TComponent; Operation:TServiceOperation;
      const ServerName,DatabasePath:string; BackupFiles:TStrings);
  end;

constructor TBackupRestoreForm.CreateDialog(AOwner:TComponent; Operation:TServiceOperation;
  const ServerName,DatabasePath:string; BackupFiles:TStrings);
var LeftPane,RightPane,TopGroup,BottomGroup:TGroupBox; L:TLabel; B:TButton;
  P:TPanel; I:Integer;
  procedure LabelAt(AParent:TWinControl; const S:string; X,Y,W:Integer);
  begin L:=TLabel.Create(Self);L.Parent:=AParent;L.Caption:=S;L.SetBounds(X,Y,W,20);end;
  procedure AddGridPath(const S:string);
  begin
    if Trim(S)='' then Exit;
    if FFiles.RowCount<2 then FFiles.RowCount:=2;
    if FFiles.Cells[0,1]<>'' then begin I:=FFiles.RowCount;FFiles.RowCount:=I+1;end else I:=1;
    FFiles.Cells[0,I]:=Trim(S);FFiles.Cells[1,I]:='';
  end;
begin
  inherited CreateNew(AOwner);
  FOperation:=Operation;
  Caption:=IfThen(Operation=soBackup,'データベースのバックアップ','データベースのリストア');
  SetBounds(0,0,820,500);Position:=poOwnerFormCenter;BorderStyle:=bsSizeable;
  Constraints.MinWidth:=700;Constraints.MinHeight:=430;
  RightPane:=TGroupBox.Create(Self);RightPane.Parent:=Self;RightPane.Caption:='オプション';
  RightPane.Align:=alRight;RightPane.Width:=300;RightPane.Constraints.MinWidth:=280;
  FOptions:=TStringGrid.Create(Self);FOptions.Parent:=RightPane;FOptions.Align:=alClient;
  FOptions.BorderSpacing.Around:=8;FOptions.FixedRows:=0;FOptions.FixedCols:=0;
  FOptions.ColCount:=2;FOptions.RowCount:=1;FOptions.DefaultRowHeight:=26;
  FOptions.Options:=[goThumbTracking];FOptions.ColWidths[0]:=165;FOptions.ColWidths[1]:=100;
  FOptions.OnDblClick:=@CycleOption;
  FOptions.OnDrawCell:=@DrawOptionCell;
  L:=TLabel.Create(Self);L.Parent:=RightPane;L.Align:=alBottom;L.Height:=22;
  L.Alignment:=taCenter;L.Caption:='値をダブルクリックして変更';

  LeftPane:=TGroupBox.Create(Self);LeftPane.Parent:=Self;LeftPane.Caption:='';LeftPane.Align:=alClient;
  LeftPane.BorderSpacing.Around:=6;
  if Operation=soBackup then begin
    TopGroup:=TGroupBox.Create(Self);TopGroup.Parent:=LeftPane;TopGroup.Align:=alTop;
    TopGroup.Height:=112;TopGroup.Caption:='データベース';
    LabelAt(TopGroup,'サーバー:',10,24,65);LabelAt(TopGroup,ServerName,82,24,220);
    LabelAt(TopGroup,'エイリアス／パス:',10,56,115);
    FDatabase:=TEdit.Create(Self);FDatabase.Parent:=TopGroup;FDatabase.SetBounds(128,52,LeftPane.Width-145,26);FDatabase.Anchors:=[akLeft,akTop,akRight];FDatabase.Text:=DatabasePath;
    L:=TLabel.Create(Self);L.Parent:=LeftPane;L.Align:=alTop;L.Height:=36;L.Alignment:=taCenter;L.Layout:=tlCenter;L.Font.Size:=15;L.Font.Color:=clNavy;L.Caption:='▼';
    BottomGroup:=TGroupBox.Create(Self);BottomGroup.Parent:=LeftPane;BottomGroup.Align:=alClient;BottomGroup.Caption:='バックアップファイル';
    LabelAt(BottomGroup,'サーバー:',10,22,65);LabelAt(BottomGroup,ServerName,82,22,200);
  end else begin
    TopGroup:=TGroupBox.Create(Self);TopGroup.Parent:=LeftPane;TopGroup.Align:=alTop;
    TopGroup.Height:=230;TopGroup.Caption:='バックアップファイル';
    LabelAt(TopGroup,'サーバー:',10,22,65);LabelAt(TopGroup,ServerName,82,22,220);
    L:=TLabel.Create(Self);L.Parent:=LeftPane;L.Align:=alTop;L.Height:=36;L.Alignment:=taCenter;L.Layout:=tlCenter;L.Font.Size:=15;L.Font.Color:=clNavy;L.Caption:='▼';
    BottomGroup:=TGroupBox.Create(Self);BottomGroup.Parent:=LeftPane;BottomGroup.Align:=alClient;BottomGroup.Caption:='データベース';
    LabelAt(BottomGroup,'サーバー:',10,22,65);LabelAt(BottomGroup,ServerName,82,22,220);
    LabelAt(BottomGroup,'エイリアス／パス:',10,54,115);
    FDatabase:=TEdit.Create(Self);FDatabase.Parent:=BottomGroup;FDatabase.SetBounds(128,50,LeftPane.Width-145,26);FDatabase.Anchors:=[akLeft,akTop,akRight];FDatabase.Text:=DatabasePath;
  end;
  FFileName:=TEdit.Create(Self);FFileName.Parent:=BottomGroup;
  FFileName.Top:=49;
  if Operation=soRestore then FFileName.Parent:=TopGroup;
  FFileName.SetBounds(10,FFileName.Top,LeftPane.Width-105,25);FFileName.Anchors:=[akLeft,akTop,akRight];
  FFileName.TextHint:='サーバー上のファイルパス';
  B:=TButton.Create(Self);B.Parent:=BottomGroup;
  if Operation=soRestore then B.Parent:=TopGroup;
  B.Caption:='追加';B.SetBounds(LeftPane.Width-88,FFileName.Top,70,25);B.Anchors:=[akRight,akTop];B.OnClick:=@AddFile;
  FFiles:=TStringGrid.Create(Self);
  if Operation=soBackup then FFiles.Parent:=BottomGroup else FFiles.Parent:=TopGroup;
  if Operation=soBackup then FFiles.SetBounds(10,FFileName.Top+31,LeftPane.Width-24,130)
  else FFiles.SetBounds(10,FFileName.Top+31,LeftPane.Width-24,100);
  FFiles.Anchors:=[akLeft,akTop,akRight];
  FFiles.ColCount:=2;FFiles.RowCount:=2;FFiles.FixedRows:=1;FFiles.FixedCols:=0;
  FFiles.Cells[0,0]:='ファイル名';FFiles.Cells[1,0]:=IfThen(Operation=soBackup,'サイズ (Bytes)','ページ');
  FFiles.ColWidths[0]:=FFiles.Width-110;FFiles.ColWidths[1]:=85;
  FFiles.Options:=[goRowSelect,goThumbTracking];
  FRemoveFile:=TButton.Create(Self);FRemoveFile.Parent:=FFiles.Parent;FRemoveFile.Caption:='選択行を削除';
  FRemoveFile.SetBounds(10,FFiles.Top+FFiles.Height+5,110,24);FRemoveFile.Anchors:=[akLeft,akBottom];FRemoveFile.OnClick:=@RemoveFile;
  FFiles.Parent.OnResize:=@LayoutFileList;
  LayoutFileList(FFiles.Parent);

  if (BackupFiles<>nil) then for I:=0 to BackupFiles.Count-1 do AddGridPath(BackupFiles[I]);
  if FFiles.Cells[0,1]='' then AddGridPath(DatabasePath+'.fbk');
  FillOptions;
  if Operation=soBackup then begin
    FOptions.RowCount:=7;
    FOptions.Cells[0,0]:='フォーマット';FOptions.Cells[1,0]:='移行可能形式';
    FOptions.Cells[0,1]:='メタデータのみ';FOptions.Cells[1,1]:='不可';
    FOptions.Cells[0,2]:='ガベージコレクション';FOptions.Cells[1,2]:='プロセス';
    FOptions.Cells[0,3]:='Limboトランザクション';FOptions.Cells[1,3]:='プロセス';
    FOptions.Cells[0,4]:='チェックサム';FOptions.Cells[1,4]:='プロセス';
    FOptions.Cells[0,5]:='外部テーブル変換';FOptions.Cells[1,5]:='不可';
    FOptions.Cells[0,6]:='出力先';FOptions.Cells[1,6]:='画面へ';
  end else begin
    FOptions.RowCount:=8;
    FOptions.Cells[0,0]:='ページサイズ (Bytes)';FOptions.Cells[1,0]:='4096';
    FOptions.Cells[0,1]:='上書き';FOptions.Cells[1,1]:='不可';
    FOptions.Cells[0,2]:='テーブル毎のコミット';FOptions.Cells[1,2]:='不可';
    FOptions.Cells[0,3]:='シャドウファイル作成';FOptions.Cells[1,3]:='可';
    FOptions.Cells[0,4]:='インデックス停止';FOptions.Cells[1,4]:='不可';
    FOptions.Cells[0,5]:='制約に適合しないデータ';FOptions.Cells[1,5]:='リストア';
    FOptions.Cells[0,6]:='ページに100%書き込む';FOptions.Cells[1,6]:='不可';
    FOptions.Cells[0,7]:='出力先';FOptions.Cells[1,7]:='画面へ';
  end;
  FOptions.ColWidths[0]:=RightPane.Width-125;
  FOptions.ColWidths[1]:=100;

  { Create the footer last so the aligned content panes cannot cover it. }
  P:=TPanel.Create(Self);P.Parent:=Self;P.Align:=alBottom;P.Height:=46;P.BevelOuter:=bvNone;
  B:=TButton.Create(Self);B.Parent:=P;B.Caption:='実行';B.ModalResult:=mrNone;B.OnClick:=@Accept;
  B.SetBounds(P.ClientWidth-190,8,86,28);B.Anchors:=[akRight,akTop];
  B:=TButton.Create(Self);B.Parent:=P;B.Caption:='キャンセル';B.ModalResult:=mrCancel;
  B.SetBounds(P.ClientWidth-96,8,86,28);B.Anchors:=[akRight,akTop];
  P.BringToFront;
  ApplyModernTheme(Self);
end;

procedure TBackupRestoreForm.FillOptions;
begin
  FOptions.Cells[0,0]:='';FOptions.Cells[1,0]:='';
end;

procedure TBackupRestoreForm.AddFile(Sender:TObject);
var R:Integer;
begin
  if Trim(FFileName.Text)='' then Exit;
  if FFiles.RowCount<2 then FFiles.RowCount:=2;
  if FFiles.Cells[0,1]<>'' then begin R:=FFiles.RowCount;FFiles.RowCount:=R+1;end else R:=1;
  FFiles.Cells[0,R]:=Trim(FFileName.Text);FFiles.Cells[1,R]:='';FFileName.Clear;
end;

procedure TBackupRestoreForm.LayoutFileList(Sender:TObject);
var P:TWinControl;TopY,GridH:Integer;
begin
  if not Assigned(FFiles) or not Assigned(FRemoveFile) then Exit;
  P:=FFiles.Parent;TopY:=FFiles.Top;GridH:=P.ClientHeight-TopY-FRemoveFile.Height-18;
  if GridH<55 then GridH:=55;
  FFiles.SetBounds(10,TopY,P.ClientWidth-24,GridH);
  FRemoveFile.SetBounds(10,P.ClientHeight-FRemoveFile.Height-7,120,FRemoveFile.Height);
  if FFiles.ColCount>1 then begin
    FFiles.ColWidths[1]:=90;
    FFiles.ColWidths[0]:=FFiles.ClientWidth-FFiles.ColWidths[1]-8;
  end;
end;

procedure TBackupRestoreForm.RemoveFile(Sender:TObject);
var R,I:Integer;
begin
  R:=FFiles.Row;if R<1 then Exit;
  for I:=R to FFiles.RowCount-2 do FFiles.Rows[I].Assign(FFiles.Rows[I+1]);
  if FFiles.RowCount>2 then FFiles.RowCount:=FFiles.RowCount-1
  else begin FFiles.Cells[0,1]:='';FFiles.Cells[1,1]:='';end;
end;

procedure TBackupRestoreForm.CycleOption(Sender:TObject);
var R:Integer;S:string;
begin
  R:=FOptions.Row;if (R<0) then Exit;
  S:=FOptions.Cells[1,R];
  if FOperation=soBackup then case R of
    0:if S='移行可能形式' then S:='非移行可能形式' else S:='移行可能形式';
    1,5:if S='不可' then S:='可' else S:='不可';
    2,3,4:if S='プロセス' then S:='無視' else S:='プロセス';
    6:if S='画面へ' then S:='無効' else S:='画面へ';
  end else case R of
    0:if S='4096' then S:='8192' else if S='8192' then S:='1024' else if S='1024' then S:='2048' else S:='4096';
    1,2,4,6:if S='不可' then S:='可' else S:='不可';
    3:if S='可' then S:='不可' else S:='可';
    5:if S='リストア' then S:='無視' else S:='リストア';
    7:if S='画面へ' then S:='無効' else S:='画面へ';
  end;
  FOptions.Cells[1,R]:=S;
end;

procedure TBackupRestoreForm.DrawOptionCell(Sender:TObject;ACol,ARow:Integer;Rect:TRect;State:TGridDrawState);
begin
  if gdSelected in State then begin FOptions.Canvas.Brush.Color:=clHighlight;FOptions.Canvas.Font.Color:=clHighlightText;end
  else begin FOptions.Canvas.Brush.Color:=$00C8C8C8;if ACol=1 then FOptions.Canvas.Font.Color:=clBlue else FOptions.Canvas.Font.Color:=clWindowText;end;
  FOptions.Canvas.FillRect(Rect);
  FOptions.Canvas.TextRect(Rect,Rect.Left+5,Rect.Top+4,FOptions.Cells[ACol,ARow]);
end;

procedure TBackupRestoreForm.ReadOptions(var AOptions:TServiceOptions);
begin
  AOptions:=Default(TServiceOptions);AOptions.Verbose:=True;
  if FOperation=soBackup then begin
    AOptions.BackupNonTransportable:=FOptions.Cells[1,0]='非移行可能形式';
    AOptions.BackupMetadataOnly:=FOptions.Cells[1,1]='可';
    AOptions.BackupNoGarbageCollection:=FOptions.Cells[1,2]='無視';
    AOptions.BackupIgnoreLimbo:=FOptions.Cells[1,3]='無視';
    AOptions.BackupIgnoreChecksums:=FOptions.Cells[1,4]='無視';
    AOptions.BackupConvertExternalTables:=FOptions.Cells[1,5]='可';
    AOptions.Verbose:=FOptions.Cells[1,6]='画面へ';
  end else begin
    AOptions.RestorePageSize:=StrToIntDef(FOptions.Cells[1,0],4096);
    AOptions.RestoreReplace:=FOptions.Cells[1,1]='可';
    AOptions.RestoreCommitEachTable:=FOptions.Cells[1,2]='可';
    AOptions.RestoreNoShadow:=FOptions.Cells[1,3]='不可';
    AOptions.RestoreDeactivateIndices:=FOptions.Cells[1,4]='可';
    AOptions.RestoreNoValidity:=FOptions.Cells[1,5]='無視';
    AOptions.RestoreUseAllSpace:=FOptions.Cells[1,6]='可';
    AOptions.Verbose:=FOptions.Cells[1,7]='画面へ';
  end;
end;

procedure TBackupRestoreForm.Accept(Sender:TObject);
var I:Integer;S:string;
begin
  if Trim(FDatabase.Text)='' then begin ModalResult:=mrNone;MessageDlg('DBパスを入力してください。',mtWarning,[mbOK],0);Exit;end;
  S:='';for I:=1 to FFiles.RowCount-1 do begin S:=Trim(FFiles.Cells[0,I]);if S<>'' then Break;end;
  if S='' then begin ModalResult:=mrNone;MessageDlg('ファイルパスを1つ以上追加してください。',mtWarning,[mbOK],0);Exit;end;
  ModalResult:=mrOK;
end;

function ExecuteBackupRestoreDialog(AOwner:TComponent; Operation:TServiceOperation;
  const ServerName:string; var DatabasePath:string; BackupFiles:TStrings;
  var Options:TServiceOptions):Boolean;
var D:TBackupRestoreForm;I:Integer;S:string;
begin
  D:=TBackupRestoreForm.CreateDialog(AOwner,Operation,ServerName,DatabasePath,BackupFiles);
  try
    Result:=D.ShowModal=mrOK;
    if not Result then Exit;
    DatabasePath:=Trim(D.FDatabase.Text);
    BackupFiles.Clear;
    for I:=1 to D.FFiles.RowCount-1 do begin S:=Trim(D.FFiles.Cells[0,I]);if S<>'' then BackupFiles.Add(S);end;
    D.ReadOptions(Options);
  finally D.Free;end;
end;

end.
