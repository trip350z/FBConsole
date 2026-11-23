program IconPreview;
{$mode objfpc}{$H+}
uses Interfaces,Forms,SysUtils,Types,Graphics,Controls,ConsoleImages;
const Names:array[0..ConsoleIconCount-1] of string=(
  'Server online','Database online','Folder','Table','View','Procedure','Domain','Function','Sequence',
  'Exception','Role','Backup','Log','Users','Connect','Disconnect','SQL','Commit','Rollback','Properties',
  'Refresh','Server offline','Trigger','Index','Package','Restore','Sweep','Validate','CSV export','Save',
  'Open','Copy','Form','Statistics','Register','Database offline','Servers','Previous query','Next query',
  'Search','Fetch all','Database connect');
var Icons:TImageList;Atlas,Icon:TBitmap;PNG:TPortableNetworkGraphic;K,X,Y:Integer;
begin
  Application.Initialize;
  Icons:=CreateConsoleImages(nil,32);Atlas:=TBitmap.Create;Icon:=TBitmap.Create;PNG:=TPortableNetworkGraphic.Create;
  try
    if Icons.Count<>ConsoleIconCount then raise Exception.Create('Wrong icon count');
    Atlas.SetSize(800,((ConsoleIconCount+7) div 8)*90);Atlas.Canvas.Brush.Color:=clWhite;Atlas.Canvas.FillRect(0,0,Atlas.Width,Atlas.Height);
    Atlas.Canvas.Font.Name:='Arial';Atlas.Canvas.Font.Size:=8;Atlas.Canvas.Font.Color:=clBlack;
    for K:=0 to Icons.Count-1 do begin
      X:=(K mod 8)*100;Y:=(K div 8)*90;
      Icon.Clear;Icons.GetBitmap(K,Icon);Atlas.Canvas.StretchDraw(Rect(X+25,Y+6,X+73,Y+54),Icon);
      Atlas.Canvas.TextOut(X+5,Y+58,IntToStr(K)+' '+Names[K]);
    end;
    PNG.Assign(Atlas);PNG.SaveToFile(ParamStr(1));
  finally PNG.Free;Icon.Free;Atlas.Free;Icons.Free;end;
end.
