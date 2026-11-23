unit ConnectionDialog;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses Classes, SysUtils, Forms, Controls, StdCtrls, Dialogs, ConnectionSettings;

type
  TConnectionDialog = class(TForm)
  private
    FName, FHost, FPort, FDatabase, FUser, FPassword, FRole, FLibrary: TEdit;
    FSubmit:TButton;
    FMode: TComboBox;
    FServerAliasValue,FDescriptionValue:string;
    FSave: TCheckBox;
    FPreview: TEdit;
    function AddEdit(const ACaption, AValue: string; X, Y, W: Integer): TEdit;
    procedure Changed(Sender: TObject);
    procedure BrowseClient(Sender: TObject);
    procedure Accept(Sender: TObject);
    function Settings: TConnectionSettings;
  public
    constructor Create(AOwner: TComponent); override;
    procedure RegistrationMode;
    function Execute(var S: TConnectionSettings; out Password: string;
      out SaveProfile: Boolean): Boolean;
  end;

implementation

uses AppTheme;

function TConnectionDialog.AddEdit(const ACaption, AValue: string; X, Y, W: Integer): TEdit;
var L: TLabel;
begin
  L := TLabel.Create(Self);
  L.Parent := Self;
  L.SetBounds(X, Y, W, 20);
  L.Caption := ACaption;
  Result := TEdit.Create(Self);
  Result.Parent := Self;
  Result.SetBounds(X, Y + 22, W, 28);
  Result.Text := AValue;
end;

constructor TConnectionDialog.Create(AOwner: TComponent);
var L: TLabel; B: TButton;
begin
  inherited CreateNew(AOwner);
  Caption := 'サーバー／データベースの登録と接続';
  BorderStyle := bsDialog;
  Position := poOwnerFormCenter;
  ClientWidth := 600;
  ClientHeight := 605;
  FName := AddEdit('登録名', '', 20, 15, 560);
  L := TLabel.Create(Self);
  L.Parent := Self;
  L.SetBounds(20, 80, 560, 20);
  L.Caption := '接続方法';
  FMode := TComboBox.Create(Self);
  FMode.Parent := Self;
  FMode.SetBounds(20, 102, 560, 28);
  FMode.Style := csDropDownList;
  FMode.Items.Add('ローカルサーバー（TCP/IP）');
  FMode.Items.Add('リモートサーバー（TCP/IP）');
  FMode.Items.Add('接続文字列を直接指定');
  FHost := AddEdit('サーバー名／IPアドレス', '', 20, 145, 420);
  FPort := AddEdit('ポート', '3050', 455, 145, 125);
  FDatabase := AddEdit('DBの別名またはサーバー上のパス', '', 20, 210, 560);
  L := TLabel.Create(Self);
  L.Parent := Self;
  L.SetBounds(20, 263, 560, 20);
  L.Caption := '例: timecard または /var/firebird/timecard.fdb（サーバー側のパス）';
  FUser := AddEdit('ユーザー', 'SYSDBA', 20, 290, 175);
  FPassword := AddEdit('パスワード（保存しません）', '', 210, 290, 175);
  FPassword.PasswordChar := '*';
  FRole := AddEdit('ロール（任意）', '', 400, 290, 180);
  FLibrary := AddEdit('Firebird 5のクライアントライブラリ', '', 20, 355, 475);
  B := TButton.Create(Self);
  B.Parent := Self;
  B.SetBounds(505, 376, 75, 28);
  B.Caption := '参照…';
  B.OnClick := @BrowseClient;
  FPreview := AddEdit('接続先の確認', '', 20, 420, 560);
  FPreview.ReadOnly := True;
  FPreview.TabStop := False;
  FSave := TCheckBox.Create(Self);
  FSave.Parent := Self;
  FSave.SetBounds(20, 490, 560, 28);
  FSave.Caption := 'この接続設定を登録する（パスワードを除く）';
  FSave.Checked := True;
  B := TButton.Create(Self);
  B.Parent := Self;
  B.SetBounds(350, 545, 110, 34);
  FSubmit:=B;B.Caption := '接続';
  B.Default := True;
  B.OnClick := @Accept;
  B := TButton.Create(Self);
  B.Parent := Self;
  B.SetBounds(470, 545, 110, 34);
  B.Caption := 'キャンセル';
  B.Cancel := True;
  B.ModalResult := mrCancel;
  FMode.OnChange := @Changed;
  FHost.OnChange := @Changed;
  FPort.OnChange := @Changed;
  FDatabase.OnChange := @Changed;
  ApplyModernTheme(Self);
end;

procedure TConnectionDialog.RegistrationMode;
begin
  Caption:='データベースの登録';FSubmit.Caption:='登録';FPassword.Enabled:=False;
  FSave.Checked:=True;FSave.Enabled:=False;
end;

function TConnectionDialog.Settings: TConnectionSettings;
begin
  Result.Name := Trim(FName.Text);
  Result.Mode := TConnectionMode(FMode.ItemIndex);
  Result.Host := Trim(FHost.Text);
  Result.Port := StrToIntDef(FPort.Text, 0);
  Result.Database := Trim(FDatabase.Text);
  Result.UserName := FUser.Text;
  Result.Role := FRole.Text;
  Result.ClientLibrary := FLibrary.Text;
end;

procedure TConnectionDialog.Changed(Sender: TObject);
begin
  FHost.Enabled := FMode.ItemIndex = Ord(cmRemoteTCP);
  FPort.Enabled := FMode.ItemIndex <> Ord(cmConnectionString);
  try
    FPreview.Text := ConnectionString(Settings);
  except
    on E: Exception do FPreview.Text := E.Message;
  end;
end;

procedure TConnectionDialog.Accept(Sender: TObject);
var S: TConnectionSettings;
begin
  try
    S := Settings;
    ConnectionString(S);
    if (S.Name = '') or (Pos('[', S.Name) > 0) or (Pos(']', S.Name) > 0) then
      raise Exception.Create('登録名を入力してください。角括弧は使用できません。');
    if not FileExists(S.ClientLibrary) then
      raise Exception.Create('Firebird 5のクライアントライブラリを指定してください。');
    ModalResult := mrOK;
  except
    on E: Exception do MessageDlg('接続設定', E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TConnectionDialog.BrowseClient(Sender: TObject);
var D: TOpenDialog;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Filter := 'Firebird client|fbclient.dll;libfbclient.so*;libfbclient.dylib|All files|*';
    if D.Execute then FLibrary.Text := D.FileName;
  finally
    D.Free;
  end;
end;

function TConnectionDialog.Execute(var S: TConnectionSettings; out Password: string;
  out SaveProfile: Boolean): Boolean;
begin
  FName.Text := S.Name;
  FServerAliasValue:=S.ServerAlias;FDescriptionValue:=S.Description;
  FMode.ItemIndex := Ord(S.Mode);
  FHost.Text := S.Host;
  FPort.Text := IntToStr(S.Port);
  FDatabase.Text := S.Database;
  FUser.Text := S.UserName;
  FPassword.Clear;
  FRole.Text := S.Role;
  FLibrary.Text := S.ClientLibrary;
  Changed(nil);
  Result := ShowModal = mrOK;
  Password := '';
  SaveProfile := False;
  if Result then
  begin
    S := Settings;
    S.ServerAlias:=FServerAliasValue;S.Description:=FDescriptionValue;
    Password := FPassword.Text;
    SaveProfile := FSave.Checked;
  end;
  FPassword.Clear;
end;

end.
