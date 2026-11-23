unit ServiceWindow;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes,SysUtils,Forms,Controls,StdCtrls,ExtCtrls,FirebirdServices;
procedure ShowService(AOwner:TComponent;const Title,ServiceName,UserName,Password,Role,DatabasePath:string;
  BackupFiles:TStrings;const Options:TServiceOptions;Operation:TServiceOperation);
implementation
uses AppTheme;
type
  TServiceWorker=class(TThread)
  private
    FLine:string;
    procedure Deliver;
    procedure Collect(const Line:string);
  protected
    procedure Execute;override;
  public
    ServiceName,UserName,Password,Role,DatabasePath,ErrorMessage:string;
    BackupFiles:TStringList;
    Options:TServiceOptions;
    Operation:TServiceOperation;
    Lines:TMemo;
  end;
  TProgressForm=class(TForm)
  public
    Done:Boolean;
    CloseButton:TButton;
    Worker:TServiceWorker;
    procedure Finished(Sender:TObject);
    procedure CheckClose(Sender:TObject;var CanClose:Boolean);
  end;
procedure TServiceWorker.Deliver;
begin Lines.Lines.Add(FLine);end;
procedure TServiceWorker.Collect(const Line:string);
begin FLine:=Line;Synchronize(@Deliver);end;
procedure TServiceWorker.Execute;
begin
  try RunService(ServiceName,UserName,Password,Role,DatabasePath,BackupFiles,Options,Operation,@Collect);
  except on E:Exception do ErrorMessage:=E.Message;end;
  Password:='';
end;
procedure TProgressForm.Finished(Sender:TObject);
begin
  Done:=True;CloseButton.Enabled:=True;
  if Worker.ErrorMessage='' then Worker.Lines.Lines.Add('完了しました。')
  else Worker.Lines.Lines.Add(UTF8Encode('失敗: ')+Worker.ErrorMessage);
end;
procedure TProgressForm.CheckClose(Sender:TObject;var CanClose:Boolean);
begin CanClose:=Done;end;
procedure ShowService(AOwner:TComponent;const Title,ServiceName,UserName,Password,Role,DatabasePath:string;
  BackupFiles:TStrings;const Options:TServiceOptions;Operation:TServiceOperation);
var D:TProgressForm;Memo:TMemo;Worker:TServiceWorker;
begin
  D:=TProgressForm.CreateNew(AOwner);Worker:=TServiceWorker.Create(True);Worker.BackupFiles:=TStringList.Create;
  try
    D.Caption:=Title;D.SetBounds(150,100,850,550);D.Position:=poOwnerFormCenter;D.OnCloseQuery:=@D.CheckClose;
    D.CloseButton:=TButton.Create(D);D.CloseButton.Parent:=D;D.CloseButton.Align:=alBottom;
    D.CloseButton.Height:=32;D.CloseButton.Caption:='閉じる';D.CloseButton.ModalResult:=mrOK;D.CloseButton.Enabled:=False;
    Memo:=TMemo.Create(D);Memo.Parent:=D;Memo.Align:=alClient;Memo.ReadOnly:=True;Memo.ScrollBars:=ssBoth;Memo.WordWrap:=False;
    Memo.Lines.Add('サーバーで実行中です。完了までお待ちください。');
    Worker.ServiceName:=ServiceName;Worker.UserName:=UserName;Worker.Password:=Password;Worker.Role:=Role;
    Worker.DatabasePath:=DatabasePath;Worker.BackupFiles.Assign(BackupFiles);Worker.Options:=Options;Worker.Operation:=Operation;
    Worker.Lines:=Memo;Worker.OnTerminate:=@D.Finished;D.Worker:=Worker;
    ApplyModernTheme(D);
    Worker.Start;D.ShowModal;Worker.WaitFor;
  finally Worker.BackupFiles.Free;Worker.Free;D.Free;end;
end;
end.
