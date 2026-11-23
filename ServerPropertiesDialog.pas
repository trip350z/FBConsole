unit ServerPropertiesDialog;

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses Classes, Forms, Controls, StdCtrls, ConnectionSettings, ServerSession;

type TApplyServerProperties=function(const Original,Candidate:TConnectionSettings):Boolean of object;

function EditServerProperties(AOwner:TComponent;var Settings:TConnectionSettings;Session:TServerSession=nil;ApplyHandler:TApplyServerProperties=nil):Boolean;

implementation

uses SysUtils, ComCtrls, Dialogs, LoginDialog, AppTheme;

type
  TServerPropertiesForm=class(TForm)
  private
    FAlias,FHost,FPort,FDescription:TEdit;
    FProtocol:TComboBox;
    FOriginal:TConnectionSettings;
    FSession:TServerSession;
    FApplyHandler:TApplyServerProperties;
    FApply:TButton;
    FVersion,FCounts:TLabel;
    FDatabases:TListBox;
    procedure Changed(Sender:TObject);
    procedure RefreshInfo(Sender:TObject);
    procedure ApplyClick(Sender:TObject);
    function SaveChanges:Boolean;
    procedure Accept(Sender:TObject);
  public
    constructor CreateDialog(AOwner:TComponent;const Settings:TConnectionSettings);
  end;

constructor TServerPropertiesForm.CreateDialog(AOwner:TComponent;const Settings:TConnectionSettings);
var Pages:TPageControl;Tab: TTabSheet;L:TLabel;B:TButton;
  function AddEdit(const Title,Value:string;X,Y,W:Integer):TEdit;
  begin
    L:=TLabel.Create(Self);L.Parent:=Tab;L.SetBounds(X,Y,W,20);L.Caption:=Title;
    Result:=TEdit.Create(Self);Result.Parent:=Tab;Result.SetBounds(X,Y+20,W,25);Result.Text:=Value;
  end;
begin
  inherited CreateNew(AOwner);
  Caption:='サーバーのプロパティ';BorderStyle:=bsDialog;Position:=poOwnerFormCenter;
  ClientWidth:=500;ClientHeight:=390;FOriginal:=Settings;
  Pages:=TPageControl.Create(Self);Pages.Parent:=Self;Pages.SetBounds(10,10,480,340);Pages.ActivePageIndex:=0;
  Tab:=TTabSheet.Create(Pages);Tab.PageControl:=Pages;Tab.Caption:='エイリアス';
  FAlias:=AddEdit('エイリアス名(L):',Settings.ServerAlias,12,15,435);
  FHost:=AddEdit('ホスト名(H):',Settings.Host,12,63,285);
  L:=TLabel.Create(Self);L.Parent:=Tab;L.SetBounds(315,63,145,20);L.Caption:='ネットワークプロトコル(N):';
  FProtocol:=TComboBox.Create(Self);FProtocol.Parent:=Tab;FProtocol.SetBounds(315,83,145,25);
  FProtocol.Style:=csDropDownList;FProtocol.Items.Add('TCP');FProtocol.ItemIndex:=0;
  FPort:=AddEdit('ポート:',IntToStr(Settings.Port),12,161,100);
  FDescription:=AddEdit('説明(D):',Settings.Description,12,112,455);
  Tab:=TTabSheet.Create(Pages);Tab.PageControl:=Pages;Tab.Caption:='一般';
  FVersion:=TLabel.Create(Self);FVersion.Parent:=Tab;FVersion.SetBounds(12,12,450,20);FVersion.Caption:='バージョン:  未取得';
  L:=TLabel.Create(Self);L.Parent:=Tab;L.SetBounds(12,38,450,45);L.Caption:='ライセンス情報:  Firebird（ユーザー数のライセンス制限なし）';L.WordWrap:=True;
  L:=TLabel.Create(Self);L.Parent:=Tab;L.SetBounds(12,125,450,20);L.Caption:='接続中のデータベース';
  FDatabases:=TListBox.Create(Self);FDatabases.Parent:=Tab;FDatabases.SetBounds(12,147,450,120);
  FCounts:=TLabel.Create(Self);FCounts.Parent:=Tab;FCounts.SetBounds(12,274,330,36);FCounts.Caption:='データベース数: 未取得'+LineEnding+'接続中のセッション数: 未取得';
  B:=TButton.Create(Self);B.Parent:=Tab;B.SetBounds(383,278,78,26);B.Caption:='更新(R)';B.OnClick:=@RefreshInfo;
  Pages.ActivePageIndex:=0;
  B:=TButton.Create(Self);B.Parent:=Self;B.SetBounds(255,358,74,26);B.Caption:='OK';B.Default:=True;B.OnClick:=@Accept;
  B:=TButton.Create(Self);B.Parent:=Self;B.SetBounds(335,358,74,26);B.Caption:='キャンセル';B.Cancel:=True;B.ModalResult:=mrCancel;
  FApply:=TButton.Create(Self);FApply.Parent:=Self;FApply.SetBounds(415,358,74,26);FApply.Caption:='適用(A)';FApply.Enabled:=False;FApply.OnClick:=@ApplyClick;
  FAlias.OnChange:=@Changed;FHost.OnChange:=@Changed;FPort.OnChange:=@Changed;FDescription.OnChange:=@Changed;
  ApplyModernTheme(Self);
end;

function TServerPropertiesForm.SaveChanges:Boolean;
var P:Integer;S:string;Candidate:TConnectionSettings;
begin
  Result:=False;S:=Trim(FAlias.Text);
  if (S='') or (Pos('[',S)>0) or (Pos(']',S)>0) or (Pos('=',S)>0) or
     (Pos(#13,S)>0) or (Pos(#10,S)>0) then begin
    MessageDlg('サーバーのプロパティ','エイリアス名を入力してください。角括弧・=・改行は使えません。',mtWarning,[mbOK],0);Exit;
  end;
  if Trim(FHost.Text)='' then begin MessageDlg('サーバーのプロパティ','ホスト名を入力してください。',mtWarning,[mbOK],0);Exit;end;
  if not TryStrToInt(Trim(FPort.Text),P) or (P<1) or (P>65535) then begin
    MessageDlg('サーバーのプロパティ','ポートは1～65535で指定してください。',mtWarning,[mbOK],0);Exit;
  end;
  Candidate:=FOriginal;Candidate.ServerAlias:=S;Candidate.Host:=Trim(FHost.Text);Candidate.Port:=P;Candidate.Description:=FDescription.Text;
  if (Candidate.Mode=cmLocalTCP) and not SameText(Candidate.Host,'localhost') then Candidate.Mode:=cmRemoteTCP;
  if Assigned(FApplyHandler) and not FApplyHandler(FOriginal,Candidate) then Exit;
  FOriginal:=Candidate;FApply.Enabled:=False;Result:=True;
end;

procedure TServerPropertiesForm.Changed(Sender:TObject);
begin FApply.Enabled:=Assigned(FApplyHandler);end;
procedure TServerPropertiesForm.ApplyClick(Sender:TObject);
begin SaveChanges;end;
procedure TServerPropertiesForm.Accept(Sender:TObject);
begin if SaveChanges then ModalResult:=mrOK;end;
procedure TServerPropertiesForm.RefreshInfo(Sender:TObject);
var Temp,ServiceSession:TServerSession;U,R,P,V:string;DBs:TStringList;DC,AC:LongWord;
begin
  FVersion.Caption:='バージョン: 未取得';FCounts.Caption:='データベース数: 未取得'+LineEnding+'接続中のセッション数: 未取得';FDatabases.Clear;
  Temp:=nil;DBs:=TStringList.Create;P:='';
  try
    try
      ServiceSession:=FSession;
      if (ServiceSession=nil) or not ServiceSession.Matches(FOriginal) then begin
        U:=FOriginal.UserName;R:=FOriginal.Role;
        if not AskLogin(Self,ServerLabel(FOriginal),U,R,P) then Exit;
        Temp:=TServerSession.Create;Temp.Login(FOriginal,U,P,R);ServiceSession:=Temp;
      end;
      ServiceSession.ReadInformation(V,DBs,DC,AC);
      FVersion.Caption:='バージョン: '+V;FDatabases.Items.Assign(DBs);
      FCounts.Caption:='データベース数: '+IntToStr(DC)+LineEnding+'接続中のセッション数: '+IntToStr(AC);
    except on E:Exception do MessageDlg('サーバー情報',E.Message,mtError,[mbOK],0);end;
  finally P:='';Temp.Free;DBs.Free;end;
end;

function EditServerProperties(AOwner:TComponent;var Settings:TConnectionSettings;Session:TServerSession;ApplyHandler:TApplyServerProperties):Boolean;
var D:TServerPropertiesForm;
begin
  D:=TServerPropertiesForm.CreateDialog(AOwner,Settings);
  try
    D.FSession:=Session;D.FApplyHandler:=ApplyHandler;
    D.RefreshInfo(nil);
    Result:=D.ShowModal=mrOK;
    if Result then Settings:=D.FOriginal;
  finally D.Free;end;
end;

end.
