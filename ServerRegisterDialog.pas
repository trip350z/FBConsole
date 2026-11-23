unit ServerRegisterDialog;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, Forms, StdCtrls, Controls, ConnectionSettings;
type
  TServerRegisterDialog=class(TForm)
  private
    LocalChoice,RemoteChoice:TRadioButton;
    HostEdit,AliasEdit,DescriptionEdit,UserEdit,PasswordEdit:TEdit;
    Protocol:TComboBox;
    Remember:TCheckBox;
    procedure ModeChanged(Sender:TObject);
    procedure Accept(Sender:TObject);
  public
    constructor Create(AOwner:TComponent);override;
    function Execute(var Settings:TConnectionSettings;out SaveAlias:Boolean;out Password:string):Boolean;
  end;
implementation
uses SysUtils,Dialogs,AppTheme;

constructor TServerRegisterDialog.Create(AOwner:TComponent);
var Kind,Info,Login:TGroupBox;Button:TButton;
  function Group(const Title:string;Y,H:Integer):TGroupBox;
  begin
    Result:=TGroupBox.Create(Self);Result.Parent:=Self;Result.Caption:=Title;
    Result.SetBounds(9,Y,306,H);
  end;
  procedure LabelAt(ParentControl:TWinControl;const Title:string;X,Y:Integer);
  var L:TLabel;
  begin
    L:=TLabel.Create(Self);L.Parent:=ParentControl;L.Caption:=Title;L.SetBounds(X,Y,140,20);
  end;
  function EditAt(ParentControl:TWinControl;X,Y,W:Integer):TEdit;
  begin
    Result:=TEdit.Create(Self);Result.Parent:=ParentControl;Result.SetBounds(X,Y,W,23);
  end;
begin
  inherited CreateNew(AOwner);
  Caption:='サーバーの登録と接続';BorderStyle:=bsDialog;Position:=poOwnerFormCenter;
  ClientWidth:=324;ClientHeight:=392;
  Kind:=Group('サーバーの種類',7,53);
  LocalChoice:=TRadioButton.Create(Self);LocalChoice.Parent:=Kind;
  LocalChoice.Caption:='ローカル(&L)';LocalChoice.SetBounds(8,4,125,23);
  RemoteChoice:=TRadioButton.Create(Self);RemoteChoice.Parent:=Kind;
  RemoteChoice.Caption:='リモート(&R)';RemoteChoice.SetBounds(158,4,125,23);
  Info:=Group('サーバー情報',66,188);
  LabelAt(Info,'サーバー名(&E)',8,1);LabelAt(Info,'ネットワークプロトコル(&N)',151,1);
  HostEdit:=EditAt(Info,8,20,134);
  Protocol:=TComboBox.Create(Self);Protocol.Parent:=Info;Protocol.Style:=csDropDownList;
  Protocol.SetBounds(151,20,144,23);Protocol.Items.Add('TCP/IP');Protocol.ItemIndex:=0;
  LabelAt(Info,'エイリアス名(&A)',8,51);AliasEdit:=EditAt(Info,8,70,287);
  LabelAt(Info,'説明(&D)',8,100);DescriptionEdit:=EditAt(Info,8,119,287);
  Remember:=TCheckBox.Create(Self);Remember.Parent:=Info;Remember.Checked:=True;
  Remember.Caption:='エイリアス情報を保存(&S)';Remember.SetBounds(8,146,275,22);
  Login:=Group('ログイン情報',260,85);
  LabelAt(Login,'ユーザー名(&U)',8,3);UserEdit:=EditAt(Login,94,1,201);
  LabelAt(Login,'パスワード(&P)',8,32);PasswordEdit:=EditAt(Login,94,30,201);PasswordEdit.PasswordChar:='*';
  Button:=TButton.Create(Self);Button.Parent:=Self;Button.SetBounds(156,357,74,28);
  Button.Caption:='OK';Button.Default:=True;Button.OnClick:=@Accept;
  Button:=TButton.Create(Self);Button.Parent:=Self;Button.SetBounds(237,357,78,28);
  Button.Caption:='キャンセル';Button.Cancel:=True;Button.ModalResult:=mrCancel;
  RemoteChoice.Checked:=True;LocalChoice.OnClick:=@ModeChanged;RemoteChoice.OnClick:=@ModeChanged;
  ModeChanged(nil);
  ApplyModernTheme(Self);
end;

procedure TServerRegisterDialog.ModeChanged(Sender:TObject);
begin
  HostEdit.Enabled:=RemoteChoice.Checked;Protocol.Enabled:=RemoteChoice.Checked;
  AliasEdit.Enabled:=RemoteChoice.Checked;
end;

procedure TServerRegisterDialog.Accept(Sender:TObject);
var AliasName:string;
begin
  AliasName:=Trim(AliasEdit.Text);
  if RemoteChoice.Checked then begin
    if Trim(HostEdit.Text)='' then begin ShowMessage('サーバー名を入力してください。');HostEdit.SetFocus;Exit;end;
    if (AliasName='') or (Pos('[',AliasName)>0) or (Pos(']',AliasName)>0) or (Pos('=',AliasName)>0) then begin
      ShowMessage('エイリアス名を入力してください。角括弧と = は使用できません。');AliasEdit.SetFocus;Exit;
    end;
  end;
  if (Trim(UserEdit.Text)='')<>(PasswordEdit.Text='') then begin
    ShowMessage('接続する場合はユーザー名とパスワードの両方を入力してください。');Exit;
  end;
  ModalResult:=mrOK;
end;

function TServerRegisterDialog.Execute(var Settings:TConnectionSettings;out SaveAlias:Boolean;out Password:string):Boolean;
begin
  Password:='';SaveAlias:=False;Result:=ShowModal=mrOK;
  if Result then begin
    if LocalChoice.Checked then begin
      Settings.Mode:=cmLocalTCP;Settings.Host:='localhost';Settings.ServerAlias:='Local Server';
    end else begin
      Settings.Mode:=cmRemoteTCP;Settings.Host:=Trim(HostEdit.Text);Settings.ServerAlias:=Trim(AliasEdit.Text);
    end;
    Settings.Name:=Settings.ServerAlias;Settings.Description:=DescriptionEdit.Text;
    if Trim(UserEdit.Text)<>'' then Settings.UserName:=Trim(UserEdit.Text);
    Password:=PasswordEdit.Text;SaveAlias:=Remember.Checked;
  end;
  PasswordEdit.Clear;
end;
end.
