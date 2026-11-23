procedure TConsoleHost.CheckTwoDatabases;
var A,B:TConsoleForm; S:TConnectionSettings; N:TTreeNode;
  {$ifdef LCLQt6}KeyText:WideString;{$endif}
  procedure Check(Value:Boolean; const Msg:string);
  begin if not Value then raise Exception.Create(Msg); end;
  function DBNode(const Name:string):TTreeNode;
  begin
    Result:=Explorer.Items.GetFirstNode;
    while Result<>nil do begin
      if (PtrUInt(Result.Data)=200) and (Result.Text=Name) then Exit;
      Result:=Result.GetNext;
    end;
  end;
begin
  A:=TConsoleForm(Pages.ActivePage.Controls[0]);
  S:=DefaultSettings;
  S.Mode:=cmConnectionString;
  S.ClientLibrary:=ParamStr(1);
  S.Database:=ParamStr(2);S.Name:='First';
  WriteSettings(A.FConfig,S); A.FProfiles.Add(S.Name);
  S.Database:=ParamStr(3);S.Name:='Second';
  WriteSettings(A.FConfig,S); A.FProfiles.Add(S.Name);
  S.Database:=ParamStr(2);S.Name:='First';
  A.ConnectAdditional(S,'');
  Check(A.FConnection.Connected,'First connection: '+A.FLog.Text);
  N:=A.FObjects.Items.GetFirstNode;
  while (N<>nil) and not ((PtrUInt(N.Data)=1) and (N.Text='TX_TEST')) do N:=N.GetNext;
  Check(N<>nil,'Test table TX_TEST missing');
  A.FObjects.Selected:=N;
  A.OpenTable;
  TTableWindow(A.FTables[0]).SelectData;
  TTableWindow(A.FTables[0]).Close;
  Application.ProcessMessages;
  Check(A.FTables.Count=0,'Closed table still registered');
  A.OpenTable;
  Check(A.FTables.Count=1,'Table did not reopen');
  TTableWindow(A.FTables[0]).SelectData;
  TTableWindow(A.FTables[0]).Close;
  Application.ProcessMessages;
  Application.ProcessMessages;
  N:=DBNode('Second');Check(N<>nil,'Second registered database missing');
  Explorer.Selected:=N;
  A.SelectedConnectionSettings(S); Check(S.Name='Second','Wrong target: '+S.Name+' local='+A.FObjects.Selected.Text+' explorer='+Explorer.Selected.Text);
  A.FSQL.Text:='select 1 from rdb$database';
  A.ExecuteClick(nil);
  Check(A.FPending and A.FTransaction.Active,'First transaction missing');
  A.OpenSQL(nil);
  Application.ProcessMessages;
  Check(A.FSQL.Focused,'SQL editor did not receive keyboard focus');
  {$ifdef LCLQt6}
  KeyText:='s';
  QCoreApplication_postEvent(QObjectH(QApplication_focusWidget()),
    QEventH(QKeyEvent_Create(QEventKeyPress,Ord('S'),0,@KeyText)));
  Application.ProcessMessages;
  Check(Trim(A.FSQL.Text)='s','Qt key press did not reach SQL editor');
  {$endif}
  A.FSQL.Text:='select 3 from rdb$database';
  {$ifdef LCLQt6}
  QAbstractButton_click(QAbstractButtonH(TQtWidget(TButton(
    A.FSQLWindow.FindComponent('CloseSQLButton')).Handle).Widget));
  {$else}
  A.CloseSQLClick(nil);
  {$endif}
  Application.ProcessMessages;
  Check(not A.FSQLWindow.Visible,'SQL window did not close');
  {$ifdef LCLQt6}
  Check(not QWidget_isVisible(TQtWidget(A.FSQLWindow.Handle).Widget),'Qt SQL window still visible');
  {$endif}
  A.OpenSQL(nil);
  Check(A.FSQLWindow.Visible and (Trim(A.FSQL.Text)='select 3 from rdb$database') and
    A.FTransaction.Active and A.FPending,'SQL state lost on reopen');
  {$ifdef LCLQt6}
  QWidget_close(TQtWidget(A.FSQLWindow.Handle).Widget);
  Application.ProcessMessages;
  {$else}
  A.FSQLWindow.Close;
  {$endif}
  Check(not A.FSQLWindow.Visible,'Reopened SQL window did not close');
  A.ConnectAdditional(S,'');
  Application.ProcessMessages;
  B:=TConsoleForm(Pages.ActivePage.Controls[0]);
  Check((A<>B) and B.FConnection.Connected,'Second connection: '+B.FLog.Text);
  B.FSQL.Text:='select 2 from rdb$database'; B.ExecuteClick(nil);
  Check(B.FGrid.Cells[0,1]='2','Second SQL failed');
  Explorer.Selected:=DBNode('First');
  Check(Pages.ActivePage.Controls[0]=A,'First tree selection failed');
  Explorer.Selected:=DBNode('Second');
  Check(Pages.ActivePage.Controls[0]=B,'Second tree selection failed');
  B.RollbackClick(nil); B.DisconnectClick(nil);
  Check(A.FConnection.Connected and A.FTransaction.Active,'Other session changed');
  A.RollbackClick(nil); A.DisconnectClick(nil);
end;
