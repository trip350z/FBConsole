unit DatabaseCreateDialog;

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses Classes;

function ExecuteDatabaseCreateDialog(AOwner:TComponent;const ServerName,InitialPath,InitialAlias:string;
  Files,PageLengths:TStrings;var PageSize:Integer;var CharacterSet:string;
  var Dialect:Integer;var RegisterDatabase:Boolean;var AliasName:string):Boolean;

implementation

uses SysUtils, Forms, Controls, StdCtrls, Grids, Dialogs, AppTheme;

type
  TDatabaseCreateForm=class(TForm)
  private
    FFiles,FOptions:TStringGrid;
    FRegister:TCheckBox;
    FAlias:TEdit;
    procedure Accept(Sender:TObject);
    procedure RegisterChanged(Sender:TObject);
  public
    constructor CreateDialog(AOwner:TComponent;const ServerName,InitialPath,InitialAlias:string);
  end;

constructor TDatabaseCreateForm.CreateDialog(AOwner:TComponent;const ServerName,InitialPath,InitialAlias:string);
var L:TLabel;B:TButton;
begin
  inherited CreateNew(AOwner);
  Caption:='データベースの作成';BorderStyle:=bsDialog;Position:=poOwnerFormCenter;
  ClientWidth:=510;ClientHeight:=500;
  L:=TLabel.Create(Self);L.Parent:=Self;L.SetBounds(12,10,485,22);
  L.Caption:='サーバー:  '+ServerName;
  L:=TLabel.Create(Self);L.Parent:=Self;L.SetBounds(12,42,485,20);L.Caption:='ファイル(E):';
  FFiles:=TStringGrid.Create(Self);FFiles.Parent:=Self;FFiles.SetBounds(12,64,486,128);
  FFiles.ColCount:=2;FFiles.RowCount:=6;FFiles.FixedCols:=0;FFiles.FixedRows:=1;
  FFiles.Cells[0,0]:='ファイル名';FFiles.Cells[1,0]:='サイズ (ページ)';
  FFiles.ColWidths[0]:=330;FFiles.ColWidths[1]:=145;FFiles.DefaultRowHeight:=22;
  FFiles.Options:=[goEditing,goThumbTracking];FFiles.Cells[0,1]:=InitialPath;
  L:=TLabel.Create(Self);L.Parent:=Self;L.SetBounds(12,202,485,20);L.Caption:='オプション(P):';
  FOptions:=TStringGrid.Create(Self);FOptions.Parent:=Self;FOptions.SetBounds(12,224,486,82);
  FOptions.ColCount:=2;FOptions.RowCount:=3;FOptions.FixedCols:=0;FOptions.FixedRows:=0;
  FOptions.ColWidths[0]:=300;FOptions.ColWidths[1]:=180;FOptions.DefaultRowHeight:=25;
  FOptions.Options:=[goEditing,goThumbTracking];
  FOptions.Cells[0,0]:='ページサイズ';FOptions.Cells[1,0]:='4096';
  FOptions.Cells[0,1]:='デフォルト文字コード';FOptions.Cells[1,1]:='UTF8';
  FOptions.Cells[0,2]:='SQL ダイアレクト';FOptions.Cells[1,2]:='3';
  FRegister:=TCheckBox.Create(Self);FRegister.Parent:=Self;FRegister.SetBounds(14,318,480,24);
  FRegister.Caption:='データベースを登録';FRegister.Checked:=True;FRegister.OnChange:=@RegisterChanged;
  L:=TLabel.Create(Self);L.Parent:=Self;L.SetBounds(14,353,82,22);L.Caption:='エイリアス(A):';
  FAlias:=TEdit.Create(Self);FAlias.Parent:=Self;FAlias.SetBounds(106,349,392,26);FAlias.Text:=InitialAlias;
  B:=TButton.Create(Self);B.Parent:=Self;B.SetBounds(315,454,88,30);B.Caption:='OK';B.Default:=True;B.OnClick:=@Accept;
  B:=TButton.Create(Self);B.Parent:=Self;B.SetBounds(410,454,88,30);B.Caption:='キャンセル';B.Cancel:=True;B.ModalResult:=mrCancel;
  ApplyModernTheme(Self);
end;

procedure TDatabaseCreateForm.RegisterChanged(Sender:TObject);
begin FAlias.Enabled:=FRegister.Checked;end;

procedure TDatabaseCreateForm.Accept(Sender:TObject);
var I,N,P:Integer;S,CS:string;Seen:TStringList;
begin
  try
    FFiles.EditorMode:=False;FOptions.EditorMode:=False;
    Seen:=TStringList.Create;
    try
      Seen.CaseSensitive:=False;N:=0;
      for I:=1 to FFiles.RowCount-1 do begin
        S:=Trim(FFiles.Cells[0,I]);
        if S='' then begin if Trim(FFiles.Cells[1,I])<>'' then raise Exception.Create('ファイルサイズを指定した行にはファイル名も入力してください。');Continue;end;
        if (Pos(#13,S)>0) or (Pos(#10,S)>0) or (Pos(#0,S)>0) then raise Exception.Create('ファイル名に改行や制御文字は使用できません。');
        if Seen.IndexOf(S)>=0 then raise Exception.Create('ファイル名が重複しています: '+S);
        Seen.Add(S);Inc(N);
        if Trim(FFiles.Cells[1,I])<>'' then begin
          if not TryStrToInt(Trim(FFiles.Cells[1,I]),P) or (P<1) then raise Exception.Create('ファイルサイズは1以上のページ数で指定してください。');
        end;
      end;
      if N=0 then raise Exception.Create('データベースのファイル名を入力してください。');
    finally Seen.Free;end;
    if not TryStrToInt(Trim(FOptions.Cells[1,0]),P) or
       not ((P=1024) or (P=2048) or (P=4096) or (P=8192) or (P=16384)) then
      raise Exception.Create('ページサイズは1024、2048、4096、8192、16384のいずれかを指定してください。');
    CS:=UpperCase(Trim(FOptions.Cells[1,1]));
    if Pos('|'+CS+'|','|UTF8|NONE|ASCII|WIN1252|SJIS_0208|ISO8859_1|')=0 then
      raise Exception.Create('文字コードはUTF8、NONE、ASCII、WIN1252、SJIS_0208、ISO8859_1から選択してください。');
    if not TryStrToInt(Trim(FOptions.Cells[1,2]),N) or not (N in [1,3]) then
      raise Exception.Create('SQLダイアレクトは1または3を指定してください。');
    if FRegister.Checked then begin
      CS:=Trim(FAlias.Text);
      if CS='' then raise Exception.Create('登録するエイリアス名を入力してください。');
      if (Pos('[',CS)>0) or (Pos(']',CS)>0) or (Pos('=',CS)>0) or
         (Pos(#13,CS)>0) or (Pos(#10,CS)>0) or (Pos(#0,CS)>0) then
        raise Exception.Create('エイリアス名に [, ], = や制御文字は使用できません。');
    end;
    ModalResult:=mrOK;
  except on E:Exception do begin ModalResult:=mrNone;MessageDlg('データベースの作成',E.Message,mtWarning,[mbOK],0);end;end;
end;

function ExecuteDatabaseCreateDialog(AOwner:TComponent;const ServerName,InitialPath,InitialAlias:string;
  Files,PageLengths:TStrings;var PageSize:Integer;var CharacterSet:string;
  var Dialect:Integer;var RegisterDatabase:Boolean;var AliasName:string):Boolean;
var D:TDatabaseCreateForm;I:Integer;S:string;
begin
  D:=TDatabaseCreateForm.CreateDialog(AOwner,ServerName,InitialPath,InitialAlias);
  try
    Result:=D.ShowModal=mrOK;if not Result then Exit;
    Files.Clear;PageLengths.Clear;
    for I:=1 to D.FFiles.RowCount-1 do begin
      S:=Trim(D.FFiles.Cells[0,I]);
      if S<>'' then begin Files.Add(S);PageLengths.Add(Trim(D.FFiles.Cells[1,I]));end;
    end;
    PageSize:=StrToInt(D.FOptions.Cells[1,0]);CharacterSet:=UpperCase(Trim(D.FOptions.Cells[1,1]));
    Dialect:=StrToInt(D.FOptions.Cells[1,2]);RegisterDatabase:=D.FRegister.Checked;AliasName:=Trim(D.FAlias.Text);
  finally D.Free;end;
end;

end.
