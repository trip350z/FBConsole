unit LoginDialog;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls;
function AskLogin(AOwner:TComponent;const Server:string;var UserName,Role:string;out Password:string;EditIdentity:Boolean=True):Boolean;
implementation
uses AppTheme;
function AskLogin(AOwner:TComponent;const Server:string;var UserName,Role:string;out Password:string;EditIdentity:Boolean):Boolean;
var D:TForm; L:TLabel; EUser,EPassword,ERole:TEdit; Sensitive:TCheckBox; B:TButton; Line:TBevel;
  function Edit(const Title,Value:string;Y:Integer):TEdit;
  var LabelControl:TLabel;
  begin
    LabelControl:=TLabel.Create(D);LabelControl.Parent:=D;LabelControl.SetBounds(16,Y+4,95,22);LabelControl.Caption:=Title;
    Result:=TEdit.Create(D);Result.Parent:=D;Result.SetBounds(112,Y,235,26);Result.Text:=Value;
  end;
begin
  Password:='';D:=TForm.CreateNew(AOwner);
  try
    D.Caption:='サーバー・ログイン';D.BorderStyle:=bsDialog;D.Position:=poOwnerFormCenter;D.ClientWidth:=365;D.ClientHeight:=280;
    L:=TLabel.Create(D);L.Parent:=D;L.SetBounds(16,20,335,22);L.Caption:=UTF8Encode('サーバー名:  ')+Server;
    Line:=TBevel.Create(D);Line.Parent:=D;Line.SetBounds(16,52,332,2);Line.Shape:=bsTopLine;
    EUser:=Edit('ユーザー名(&U):',UserName,77);EPassword:=Edit('パスワード(&P):','',115);EPassword.PasswordChar:='*';ERole:=Edit('Role:',Role,153);
    Sensitive:=TCheckBox.Create(D);Sensitive.Parent:=D;Sensitive.SetBounds(112,188,240,24);Sensitive.Caption:='Case sensitive role name';
    EUser.ReadOnly:=not EditIdentity;ERole.ReadOnly:=not EditIdentity;Sensitive.Enabled:=EditIdentity;
    Sensitive.Checked:=(Role<>'') and (Role<>UpperCase(Role));
    B:=TButton.Create(D);B.Parent:=D;B.SetBounds(145,230,95,28);B.Caption:='ログイン(&L)';B.Default:=True;B.ModalResult:=mrOK;
    B:=TButton.Create(D);B.Parent:=D;B.SetBounds(250,230,95,28);B.Caption:='キャンセル';B.Cancel:=True;B.ModalResult:=mrCancel;
    ApplyModernTheme(D);
    D.ActiveControl:=EPassword;Result:=D.ShowModal=mrOK;
    if Result then begin UserName:=EUser.Text;Password:=EPassword.Text;if Sensitive.Checked then Role:=ERole.Text else Role:=UpperCase(ERole.Text);end;
    EPassword.Clear;
  finally D.Free;end;
end;
end.
