unit UserInfoDialog;

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls;

type
  TUserInfo = record
    UserName, Password, PasswordConfirm, FirstName, MiddleName, LastName: string;
  end;

function EditUserInfo(AOwner: TComponent; const Editing: Boolean;
  var Info: TUserInfo; out DeleteRequested: Boolean): Boolean;

implementation

uses Dialogs, AppTheme;

type
  TUserInfoForm = class(TForm)
  public
    UserName, Password, Confirm, FirstName, MiddleName, LastName: TEdit;
    Editing: Boolean;
    procedure Accept(Sender: TObject);
    procedure ClearFields(Sender: TObject);
    procedure DeleteCurrent(Sender: TObject);
  end;

procedure TUserInfoForm.ClearFields(Sender: TObject);
begin
  UserName.Clear; Password.Clear; Confirm.Clear;
  FirstName.Clear; MiddleName.Clear; LastName.Clear;
  UserName.SetFocus;
end;

procedure TUserInfoForm.DeleteCurrent(Sender:TObject);
begin
  if MessageDlg('ユーザーの削除',UserName.Text+' を削除しますか？',
    mtConfirmation,[mbYes,mbNo],0)=mrYes then ModalResult:=mrYes;
end;

procedure TUserInfoForm.Accept(Sender: TObject);
begin
  if Trim(UserName.Text)='' then begin
    MessageDlg('ユーザー情報','ユーザー名を入力してください。',mtWarning,[mbOK],0);
    UserName.SetFocus; Exit;
  end;
  if not Editing and (Password.Text='') then begin
    MessageDlg('ユーザー情報','パスワードを入力してください。',mtWarning,[mbOK],0);
    Password.SetFocus; Exit;
  end;
  if Password.Text<>Confirm.Text then begin
    MessageDlg('ユーザー情報','パスワードと確認入力が一致しません。',mtWarning,[mbOK],0);
    Confirm.SetFocus; Exit;
  end;
  ModalResult:=mrOK;
end;

function EditUserInfo(AOwner:TComponent;const Editing:Boolean;var Info:TUserInfo;
  out DeleteRequested:Boolean):Boolean;
var D:TUserInfoForm;Required,Optional:TGroupBox;L:TLabel;B:TButton;
  function Field(AParent:TWinControl;const Caption:string;Top:Integer):TEdit;
  begin
    L:=TLabel.Create(D);L.Parent:=AParent;L.SetBounds(10,Top+4,95,20);L.Caption:=Caption;
    Result:=TEdit.Create(D);Result.Parent:=AParent;Result.SetBounds(108,Top,238,24);
  end;
begin
  D:=TUserInfoForm.CreateNew(AOwner);
  try
    D.Caption:='ユーザー情報';D.BorderStyle:=bsDialog;D.Position:=poOwnerFormCenter;
    D.ClientWidth:=370;D.ClientHeight:=302;D.Editing:=Editing;
    Required:=TGroupBox.Create(D);Required.Parent:=D;Required.SetBounds(8,8,354,120);Required.Caption:='必須情報';
    D.UserName:=Field(Required,'ユーザー名(U):',22);
    D.Password:=Field(Required,'パスワード(P):',47);D.Password.PasswordChar:='*';
    D.Confirm:=Field(Required,'確認入力(O):',72);D.Confirm.PasswordChar:='*';
    Optional:=TGroupBox.Create(D);Optional.Parent:=D;Optional.SetBounds(8,134,354,126);Optional.Caption:='任意情報';
    D.FirstName:=Field(Optional,'名(F):',20);
    D.MiddleName:=Field(Optional,'ミドルネーム(M):',47);
    D.LastName:=Field(Optional,'姓(L):',74);
    D.UserName.Text:=Info.UserName;D.FirstName.Text:=Info.FirstName;
    D.MiddleName.Text:=Info.MiddleName;D.LastName.Text:=Info.LastName;
    D.UserName.ReadOnly:=Editing;
    if Editing then D.Password.TextHint:='変更しない場合は空欄';
    B:=TButton.Create(D);B.Parent:=D;B.SetBounds(8,270,73,25);B.Caption:='新規(N)';B.OnClick:=@D.ClearFields;
    B:=TButton.Create(D);B.Parent:=D;B.SetBounds(84,270,73,25);B.Caption:='追加(A)';B.Default:=True;B.OnClick:=@D.Accept;
    B:=TButton.Create(D);B.Parent:=D;B.SetBounds(160,270,73,25);B.Caption:='削除(D)';B.Enabled:=Editing;B.OnClick:=@D.DeleteCurrent;
    B:=TButton.Create(D);B.Parent:=D;B.SetBounds(289,270,73,25);B.Caption:='キャンセル';B.Cancel:=True;B.ModalResult:=mrCancel;
    ApplyModernTheme(D);
    DeleteRequested:=False;
    Result:=D.ShowModal=mrOK;
    DeleteRequested:=D.ModalResult=mrYes;
    if Result then begin
      Info.UserName:=Trim(D.UserName.Text);Info.Password:=D.Password.Text;
      Info.PasswordConfirm:=D.Confirm.Text;Info.FirstName:=D.FirstName.Text;
      Info.MiddleName:=D.MiddleName.Text;Info.LastName:=D.LastName.Text;
    end;
  finally D.Free;end;
end;

end.
