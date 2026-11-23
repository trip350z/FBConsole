program FBConsole;

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}{$APPTYPE GUI}{$ENDIF}
{$IFDEF WINDOWS}{$R FBConsole.res}{$ENDIF}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  LinuxDisplay,
  Interfaces, Forms, SysUtils, MainForm, Graphics;

procedure SaveMainWindow(const FileName: string);
var

  Bitmap: TBitmap;
  Picture: TPortableNetworkGraphic;

begin
  if FileExists(FileName) then raise Exception.Create('Output file already exists');
  Application.ProcessMessages;
  ConsoleHost.Update;

  Bitmap := ConsoleHost.GetFormImage;
  Picture := TPortableNetworkGraphic.Create;
  try
    Picture.Assign(Bitmap);
    Picture.SaveToFile(FileName);
  finally
    Picture.Free;
    Bitmap.Free;
  end;
end;

function StableApplicationName:string;
begin
  Result:='FBConsole';
end;

begin
  OnGetApplicationName:=@StableApplicationName;
  RequireDerivedFormResource := False;
  Application.Initialize;
  Application.Title := 'FBConsole';
  {$IFDEF WINDOWS}
  Application.Icon.LoadFromResourceName(HInstance, 'MAINICON');
  {$ELSE}
  if FileExists(ExtractFilePath(ParamStr(0))+'FBConsole.ico') then
    Application.Icon.LoadFromFile(ExtractFilePath(ParamStr(0))+'FBConsole.ico');
  {$ENDIF}

  if (ParamCount = 4) and (ParamStr(1) = '--smoke-test') then
  begin
    Application.CreateForm(TConsoleForm,ConsoleForm);
    try
      ConsoleForm.RunSmokeTest(ParamStr(2), ParamStr(3), ParamStr(4));
    except
      on E: Exception do
      begin
        {$I-}WriteLn(StdErr, E.Message);{$I+}
        if IOResult<>0 then begin end;
        Halt(1);
      end;
    end;
    ConsoleForm.Free;
    Exit;
  end;
  Application.CreateForm(TConsoleHost,ConsoleHost);
  ConsoleForm:=ConsoleHost.AddSession;
  ConsoleHost.Show;
  {$IFDEF MULTIDB_TEST}
  try ConsoleHost.CheckTwoDatabases; except on E:Exception do begin AssignFile(Output,ParamStr(4)); Rewrite(Output); WriteLn(E.ClassName,' ',E.Message); CloseFile(Output); Halt(1);end;end;
  Exit;
  {$ENDIF}
  if (ParamCount=2) and (ParamStr(1)='--connect-profile') then
    ConsoleForm.OpenRegisteredSession(ParamStr(2));
  if (ParamCount=2) and (ParamStr(1)='--capture-main') then
  begin
    SaveMainWindow(ExpandFileName(ParamStr(2)));
    Exit;
  end;
  Application.Run;
end.

