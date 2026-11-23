unit ConsoleImages;

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses Classes, SysUtils, Types, Graphics, Controls, ImgList, ComCtrls {$IFDEF WINDOWS}, Windows{$ENDIF};

const
  icServer=0; icDatabase=1; icFolder=2; icTable=3; icView=4; icProcedure=5;
  icDomain=6; icFunction=7; icSequence=8; icException=9; icRole=10;
  icBackup=11; icLog=12; icUsers=13; icConnect=14; icDisconnect=15;
  icSQL=16; icCommit=17; icRollback=18; icProperties=19; icRefresh=20;
  icServerOffline=21; icTrigger=22; icIndex=23; icPackage=24; icRestore=25;
  icSweep=26; icValidate=27; icExport=28; icSave=29; icOpen=30; icCopy=31;
  icForm=32; icStatistics=33; icRegister=34; icDatabaseOffline=35;
  icServers=36; icPreviousQuery=37; icNextQuery=38; icSearch=39;
  icFetchAll=40; icDatabaseConnect=41; icDatabaseCreate=42; icDatabaseRegister=43; icPlan=44; icPrint=45;
  icBlobFilter=46; ConsoleIconCount=47;

function CreateConsoleImages(AOwner: TComponent; IconSize:Integer=24): TImageList;
function IconForCaption(const Caption: string): Integer;
procedure AssignTreeImages(Tree: TTreeView; OnlineServers: TStrings; Connected: Boolean; const ActiveDatabase: string);

implementation

const
  CBlue=$00D17A32; CBlueLight=$00F0A64B; CCyan=$00C5A445;
  COrange=$003C6EF3; CGreen=$0047A77B; CRed=$00595EDC;
  CInk=$00505042; CMuted=$0072685A; CPaper=$00F8F7F3;
  CYellow=$003CC6F5; CWhite=clWhite; CTransparent=$00F8F7F3;

function CreateConsoleImages(AOwner: TComponent; IconSize:Integer): TImageList;
var B,ScaledB: Graphics.TBitmap; C: TCanvas; K: Integer; {$IFDEF WINDOWS}OldExtent:Windows.TSize;{$ENDIF}
  function Pixel(Coordinate:Integer):Integer; inline;
  begin
    {$IFDEF WINDOWS}
    Result:=Coordinate; // The Windows canvas mapping applies the scale.
    {$ELSE}
    Result:=Coordinate*4;
    {$ENDIF}
  end;
  procedure FillRect(A,Top,Right,Bottom: Integer; Color:TColor);
  begin C.Pen.Color:=Color; C.Brush.Color:=Color; C.Rectangle(Pixel(A),Pixel(Top),Pixel(Right),Pixel(Bottom)); end;
  procedure RoundBox(A,Top,Right,Bottom,Radius:Integer;Color:TColor);
  begin C.Pen.Color:=Color; C.Brush.Color:=Color; C.RoundRect(Pixel(A),Pixel(Top),Pixel(Right),Pixel(Bottom),Pixel(A+Radius),Pixel(Top+Radius)); end;
  procedure Line(X1,Y1,X2,Y2:Integer;Color:TColor;Width:Integer=2);
  begin C.Pen.Color:=Color;C.Pen.Width:=Pixel(Width);C.MoveTo(Pixel(X1),Pixel(Y1));C.LineTo(Pixel(X2),Pixel(Y2));C.Pen.Width:=Pixel(1);end;
  procedure Circle(A,Top,Right,Bottom:Integer;Color:TColor;Filled:Boolean=True);
  begin
    C.Pen.Color:=Color;
    if Filled then begin C.Brush.Style:=bsSolid;C.Brush.Color:=Color;end
    else C.Brush.Style:=bsClear;
    C.Ellipse(Pixel(A),Pixel(Top),Pixel(Right),Pixel(Bottom));C.Brush.Style:=bsSolid;
  end;
  procedure Doc;
  begin
    C.Pen.Color:=CInk;C.Brush.Color:=CWhite;C.RoundRect(Pixel(4),Pixel(2),Pixel(16),Pixel(19),Pixel(3),Pixel(3));
    Line(7,7,13,7,CInk,1);Line(7,10,13,10,CInk,1);Line(7,13,13,13,CInk,1);
  end;
  procedure DrawDB;
  begin
    C.Pen.Color:=CBlue;C.Brush.Color:=CBlueLight;C.Ellipse(Pixel(2),Pixel(2),Pixel(18),Pixel(9));
    FillRect(2,5,18,16,CBlue);
    C.Pen.Color:=CBlueLight;C.Brush.Color:=CBlue;C.Ellipse(Pixel(2),Pixel(12),Pixel(18),Pixel(19));
    C.Pen.Color:=CBlueLight;C.Brush.Style:=bsClear;
    C.Arc(Pixel(2),Pixel(7),Pixel(18),Pixel(14),Pixel(2),Pixel(10),Pixel(18),Pixel(10));C.Arc(Pixel(2),Pixel(10),Pixel(18),Pixel(17),Pixel(2),Pixel(13),Pixel(18),Pixel(13));
    C.Brush.Style:=bsSolid;
  end;
  procedure DrawServer;
  begin
    C.Pen.Color:=CInk;C.Brush.Color:=$00E2E0D8;C.RoundRect(Pixel(3),Pixel(2),Pixel(17),Pixel(18),Pixel(3),Pixel(3));
    C.Pen.Color:=CBlue;C.Brush.Color:=CBlue;C.Rectangle(Pixel(5),Pixel(4),Pixel(15),Pixel(8));
    C.Pen.Color:=CInk;C.Brush.Color:=$00D3D0C9;C.Rectangle(Pixel(5),Pixel(10),Pixel(15),Pixel(14));
    Circle(7,5,9,7,CGreen);Circle(7,11,9,13,$00E5A74A);
    Line(11,6,14,6,CWhite,1);Line(11,12,14,12,CInk,1);
  end;
  procedure DrawFolder;
  begin
    RoundBox(2,6,18,17,3,CYellow);
    FillRect(3,5,9,8,CYellow);
    Line(3,9,17,9,CWhite,1);
  end;
  procedure DrawTable;
  begin
    C.Pen.Color:=CInk;C.Brush.Color:=CWhite;C.RoundRect(Pixel(3),Pixel(2),Pixel(17),Pixel(18),Pixel(3),Pixel(3));
    FillRect(4,3,16,7,CBlue);
    Line(4,9,16,9,$00989082,1);Line(4,12,16,12,$00989082,1);Line(4,15,16,15,$00989082,1);
    Line(9,7,9,17,$00989082,1);Line(13,7,13,17,$00989082,1);
  end;
  procedure DrawPerson(A,Top:Integer;Color:TColor);
  begin Circle(A+3,Top,A+9,Top+6,CBlueLight);RoundBox(A,Top+7,A+12,Top+15,3,Color);end;
begin
  if IconSize<16 then IconSize:=24;
  if IconSize>64 then IconSize:=64;
  Result:=TImageList.Create(AOwner); Result.Width:=IconSize; Result.Height:=IconSize;
  B:=Graphics.TBitmap.Create;ScaledB:=Graphics.TBitmap.Create;
  try
    { Draw at four times the logical size, then reduce with HALFTONE. This
      keeps the original IBConsole-style pictograms crisp at toolbar size. }
    B.SetSize(80,80);C:=B.Canvas;ScaledB.SetSize(IconSize,IconSize);
    for K:=0 to ConsoleIconCount-1 do begin
      {$IFDEF WINDOWS}
      SetMapMode(C.Handle,MM_ANISOTROPIC);
      SetWindowExtEx(C.Handle,20,20,@OldExtent);
      SetViewportExtEx(C.Handle,80,80,@OldExtent);
      {$ENDIF}
      C.Brush.Style:=bsSolid;C.Brush.Color:=CTransparent;C.FillRect(Pixel(0),Pixel(0),Pixel(20),Pixel(20));
      C.Pen.Width:=Pixel(1);C.Pen.Style:=psSolid;
      case K of
        icServer,icServerOffline,icConnect,icDisconnect,icRegister:
          begin
            DrawServer;
            if K=icConnect then begin
              Circle(12,10,19,17,CGreen);
              Line(13,13,15,15,CWhite,2);Line(15,15,18,11,CWhite,2);
            end else if K=icDisconnect then begin
              Circle(12,10,19,17,CRed);Line(14,12,17,15,CWhite,2);Line(17,12,14,15,CWhite,2);
            end else if K=icServer then begin
              Circle(12,10,19,17,CGreen);Line(13,13,15,15,CWhite,2);Line(15,15,18,11,CWhite,2);
            end else if K=icServerOffline then begin
              Circle(12,10,19,17,CRed);Line(14,12,17,15,CWhite,2);Line(17,12,14,15,CWhite,2);
            end else begin
              Circle(12,10,19,17,CBlue);Line(15,11,15,16,CWhite,2);Line(13,13,17,13,CWhite,2);
            end;
          end;
        icDatabase,icDatabaseOffline,icBackup,icRestore,icDatabaseConnect,icDatabaseCreate,icDatabaseRegister:begin
          DrawDB;
          if K=icDatabaseCreate then begin
            Line(3,3,9,9,COrange,2);Line(9,3,3,9,COrange,2);
            Line(6,1,6,11,COrange,2);Line(1,6,11,6,COrange,2);
          end;
          if K=icDatabaseRegister then begin
            Circle(12,1,19,8,CBlue);Line(15,2,15,7,CWhite,2);Line(13,4,18,4,CWhite,2);
          end;
          if K=icDatabaseOffline then begin Circle(12,1,19,8,CRed);Line(14,3,17,6,CWhite,2);Line(17,3,14,6,CWhite,2);end;
          if K=icDatabaseConnect then begin Circle(12,1,19,8,CGreen);Line(13,4,15,6,CWhite,2);Line(15,6,18,2,CWhite,2);end;
          if K=icBackup then begin Circle(12,1,19,8,CGreen);Line(15,2,15,6,CWhite,2);Line(13,4,15,6,CWhite,2);Line(15,6,17,4,CWhite,2);end;
          if K=icRestore then begin Circle(12,1,19,8,CBlue);Line(15,6,15,2,CWhite,2);Line(13,4,15,2,CWhite,2);Line(15,2,17,4,CWhite,2);end;
        end;
        icFolder:DrawFolder;
        icOpen:begin DrawFolder;Line(5,13,14,13,CGreen,2);Line(11,10,14,13,CGreen,2);Line(14,13,11,16,CGreen,2);end;
        icTable:DrawTable;
        icView:begin DrawTable;C.Pen.Color:=CBlue;C.Brush.Color:=CWhite;C.Ellipse(Pixel(9),Pixel(9),Pixel(19),Pixel(17));Circle(12,11,16,15,CBlue);end;
        icProcedure:begin Doc;Circle(12,10,19,17,CBlue);C.Pen.Color:=CWhite;C.Brush.Color:=CWhite;C.Polygon([Types.Point(Pixel(14),Pixel(11)),Types.Point(Pixel(14),Pixel(16)),Types.Point(Pixel(17),Pixel(13))]);end;
        icDomain:begin C.Pen.Color:=CCyan;C.Brush.Color:=CCyan;C.Polygon([Types.Point(Pixel(10),Pixel(2)),Types.Point(Pixel(17),Pixel(10)),Types.Point(Pixel(10),Pixel(18)),Types.Point(Pixel(3),Pixel(10))]);C.Font.Name:='Segoe UI';C.Font.Size:=Pixel(7);C.Font.Style:=[fsBold];C.Font.Color:=CWhite;C.TextOut(Pixel(7),Pixel(6),'D');end;
        icFunction:begin
          RoundBox(2,3,18,17,3,CWhite);
          C.Font.Name:='Consolas';C.Font.Size:=Pixel(7);C.Font.Style:=[fsBold];
          C.Font.Color:=CBlue;C.TextOut(3,6,'f(x)');
        end;
        icBlobFilter:begin
          C.Pen.Color:=CCyan;C.Brush.Color:=CCyan;
          C.Polygon([Types.Point(Pixel(2),Pixel(3)),Types.Point(Pixel(18),Pixel(3)),Types.Point(Pixel(12),Pixel(10)),
            Types.Point(Pixel(12),Pixel(15)),Types.Point(Pixel(9),Pixel(18)),Types.Point(Pixel(9),Pixel(10))]);
          Circle(14,13,19,18,CBlueLight);Line(16,15,17,17,CWhite,1);
        end;
        icSequence:begin Circle(2,2,18,18,$00A6C77A);Line(10,5,10,15,CWhite,2);Line(5,10,15,10,CWhite,2);end;
        icException:begin C.Pen.Color:=CRed;C.Brush.Color:=CRed;C.Polygon([Types.Point(Pixel(10),Pixel(2)),Types.Point(Pixel(19),Pixel(18)),Types.Point(Pixel(1),Pixel(18))]);Line(10,7,10,12,CWhite,2);Circle(9,14,11,16,CWhite);end;
        icRole,icUsers:begin DrawPerson(2,3,$00DDA46A);if K=icUsers then DrawPerson(9,5,$00A0C4E8) else begin Circle(10,3,17,10,CCyan,False);Line(10,11,17,11,CCyan,2);end;end;
        icLog:Doc;
        icSQL:begin RoundBox(2,3,18,17,4,CBlue);C.Font.Name:='Consolas';C.Font.Size:=Pixel(8);C.Font.Style:=[fsBold];C.Font.Color:=CWhite;C.TextOut(Pixel(4),Pixel(6),'SQL');end;
        icCommit:begin
          DrawDB;Circle(12,11,19,18,CGreen);Line(13,14,15,16,CWhite,2);Line(15,16,18,12,CWhite,2);
        end;
        icValidate:begin
          C.Pen.Color:=CGreen;C.Brush.Color:=CWhite;C.Polygon([Types.Point(Pixel(10),Pixel(2)),Types.Point(Pixel(18),Pixel(5)),Types.Point(Pixel(17),Pixel(13)),Types.Point(Pixel(10),Pixel(19)),Types.Point(Pixel(3),Pixel(13)),Types.Point(Pixel(2),Pixel(5))]);
          Line(5,10,8,13,CGreen,2);Line(8,13,15,6,CGreen,2);
        end;
        icRollback:begin
          DrawDB;Circle(12,11,19,18,CRed);Line(14,13,17,16,CWhite,2);Line(17,13,14,16,CWhite,2);
        end;
        icProperties:begin Doc;Circle(12,12,19,19,CBlue);Circle(15,15,17,17,CWhite);end;
        icRefresh:begin
          { Folded sheet with two clockwise arrows, as in the IBConsole toolbar. }
          C.Pen.Color:=CBlue;
          C.Brush.Color:=CWhite;
          C.Polygon([Types.Point(Pixel(2),Pixel(1)),Types.Point(Pixel(14),Pixel(1)),Types.Point(Pixel(18),Pixel(5)),
            Types.Point(Pixel(18),Pixel(19)),Types.Point(Pixel(2),Pixel(19))]);
          C.Brush.Color:=CBlue;
          C.Polygon([Types.Point(Pixel(14),Pixel(1)),Types.Point(Pixel(18),Pixel(5)),Types.Point(Pixel(14),Pixel(5))]);
          C.Pen.Color:=$00377516;
          C.Brush.Color:=C.Pen.Color;
          C.Polygon([Types.Point(Pixel(4),Pixel(10)),Types.Point(Pixel(6),Pixel(6)),Types.Point(Pixel(10),Pixel(5)),
            Types.Point(Pixel(13),Pixel(6)),Types.Point(Pixel(15),Pixel(4)),Types.Point(Pixel(15),Pixel(10)),
            Types.Point(Pixel(9),Pixel(10)),Types.Point(Pixel(11),Pixel(8)),Types.Point(Pixel(8),Pixel(8))]);
          C.Polygon([Types.Point(Pixel(16),Pixel(11)),Types.Point(Pixel(14),Pixel(15)),Types.Point(Pixel(10),Pixel(16)),
            Types.Point(Pixel(7),Pixel(15)),Types.Point(Pixel(5),Pixel(17)),Types.Point(Pixel(5),Pixel(11)),
            Types.Point(Pixel(11),Pixel(11)),Types.Point(Pixel(9),Pixel(13)),Types.Point(Pixel(12),Pixel(13))]);
        end;
        icTrigger:begin C.Pen.Color:=COrange;C.Brush.Color:=COrange;C.Polygon([Types.Point(Pixel(12),Pixel(1)),Types.Point(Pixel(5),Pixel(11)),Types.Point(Pixel(10),Pixel(11)),Types.Point(Pixel(8),Pixel(19)),Types.Point(Pixel(16),Pixel(8)),Types.Point(Pixel(11),Pixel(8))]);end;
        icIndex:begin Circle(2,2,13,13,CBlue,False);Line(12,12,18,18,CBlue,3);Line(5,7,10,7,CCyan,1);Line(7,5,7,10,CCyan,1);end;
        icPackage:begin RoundBox(3,5,17,18,3,$00E7B269);Line(3,8,17,8,$00A76728,1);Line(10,5,10,18,$00A76728,1);end;
        icSweep:begin Line(14,2,5,12,$00B28543,3);C.Pen.Color:=CCyan;C.Brush.Color:=CCyan;C.Polygon([Types.Point(Pixel(2),Pixel(11)),Types.Point(Pixel(11),Pixel(12)),Types.Point(Pixel(9),Pixel(18)),Types.Point(Pixel(1),Pixel(17))]);end;
        icExport:begin DrawTable;Line(10,13,10,5,CGreen,2);Line(7,8,10,5,CGreen,2);Line(10,5,13,8,CGreen,2);end;
        icSave:begin RoundBox(3,2,17,18,2,CBlue);RoundBox(6,3,14,8,1,CWhite);RoundBox(6,11,14,17,1,CWhite);end;
        icCopy:begin RoundBox(6,3,17,17,2,CBlueLight);RoundBox(3,6,14,19,2,CWhite);Line(6,10,11,10,CMuted,1);Line(6,13,11,13,CMuted,1);end;
        icForm:begin RoundBox(2,3,18,18,3,CWhite);FillRect(3,4,17,8,CBlue);Circle(5,10,8,13,CCyan);Line(10,10,15,10,CMuted,1);Line(10,13,15,13,CMuted,1);end;
        icStatistics:begin Line(3,17,17,17,CMuted,1);FillRect(4,11,7,17,CCyan);FillRect(9,7,12,17,CBlue);FillRect(14,3,17,17,COrange);end;
        icServers:begin DrawServer;RoundBox(9,9,19,19,2,CCyan);C.Pen.Color:=CWhite;C.Brush.Color:=CWhite;C.Polygon([Types.Point(Pixel(12),Pixel(12)),Types.Point(Pixel(12),Pixel(16)),Types.Point(Pixel(16),Pixel(14))]);end;
        icPreviousQuery:begin
          Circle(2,2,18,18,CGreen);Line(12,5,7,10,CWhite,3);Line(7,10,12,15,CWhite,3);Line(7,10,16,10,CWhite,3);
        end;
        icNextQuery:begin
          Circle(2,2,18,18,CGreen);Line(8,5,13,10,CWhite,3);Line(13,10,8,15,CWhite,3);Line(13,10,4,10,CWhite,3);
        end;
        icSearch:begin
          Circle(2,2,14,14,CBlue,False);Line(12,12,19,19,CBlue,3);
        end;
        icPlan:begin Doc;Line(2,10,11,10,CGreen,3);Line(8,6,12,10,CGreen,2);Line(12,10,8,14,CGreen,2);end;
        icPrint:begin FillRect(5,2,15,8,CWhite);RoundBox(2,7,18,15,3,CMuted);FillRect(5,12,15,19,CWhite);Line(7,15,13,15,CInk,1);end;
        icFetchAll:begin
          DrawDB;Line(10,1,10,9,CGreen,3);Line(6,6,10,10,CGreen,2);Line(10,10,14,6,CGreen,2);
        end;
      end;
      C.Brush.Style:=bsSolid;
      {$IFDEF WINDOWS}SetMapMode(C.Handle,MM_TEXT);{$ENDIF}
      ScaledB.Canvas.Brush.Color:=CTransparent;
      ScaledB.Canvas.FillRect(0,0,IconSize,IconSize);
      {$IFDEF WINDOWS}
      SetStretchBltMode(ScaledB.Canvas.Handle,HALFTONE);
      SetBrushOrgEx(ScaledB.Canvas.Handle,0,0,nil);
      {$ENDIF}
      ScaledB.Canvas.StretchDraw(Types.Rect(0,0,IconSize,IconSize),B);
      Result.AddMasked(ScaledB,CTransparent);
    end;
  finally ScaledB.Free;B.Free;end;
end;

function IconForCaption(const Caption:string):Integer;
begin
  Result:=icProperties;
  if (Caption=UTF8Encode('カラム')) or (Caption=UTF8Encode('データ')) then Exit(icTable);
  if (Caption=UTF8Encode('インデックス')) or (Caption=UTF8Encode('ユニーク制約')) or (Caption=UTF8Encode('一意制約')) or
     (Caption=UTF8Encode('依存関係')) then Exit(icIndex);
  if Caption=UTF8Encode('トリガー') then Exit(icTrigger);
  if Caption=UTF8Encode('チェック制約') then Exit(icValidate);
  if (Caption=UTF8Encode('権限')) or (Caption=UTF8Encode('参照制約')) then Exit(icRole);
  if Caption=UTF8Encode('メタデータ') then Exit(icLog);
  if Pos(UTF8Encode('バックアップ'),Caption)>0 then Exit(icBackup);
  if (Pos(UTF8Encode('リストア'),Caption)>0) or (Pos(UTF8Encode('復元'),Caption)>0) then Exit(icRestore);
  if Pos(UTF8Encode('切断'),Caption)>0 then Exit(icDisconnect);
  if Pos(UTF8Encode('登録解除'),Caption)>0 then Exit(icServerOffline);
  if Pos(UTF8Encode('ログアウト'),Caption)>0 then Exit(icDisconnect);
  if Pos(UTF8Encode('ログイン'),Caption)>0 then Exit(icConnect);
  if Pos(UTF8Encode('プロパティ'),Caption)>0 then Exit(icProperties);
  if Pos(UTF8Encode('ログファイル'),Caption)>0 then Exit(icLog);
  if Pos(UTF8Encode('ユーザー情報'),Caption)>0 then Exit(icUsers);
  if Pos(UTF8Encode('データベースの削除'),Caption)>0 then Exit(icDatabaseOffline);
  if Pos(UTF8Encode('データベースの作成'),Caption)>0 then Exit(icDatabaseConnect);
  if Pos(UTF8Encode('ロールバック'),Caption)>0 then Exit(icRollback);
  if (Pos(UTF8Encode('コミット'),Caption)>0) or (Pos(UTF8Encode('適用'),Caption)>0) then Exit(icCommit);
  if Pos(UTF8Encode('取り消し'),Caption)>0 then Exit(icRollback);
  if (Pos(UTF8Encode('ユーザー'),Caption)>0) then Exit(icUsers);
  if Pos(UTF8Encode('実行'),Caption)>0 then Exit(icTrigger);
  if Pos(UTF8Encode('統計'),Caption)>0 then Exit(icStatistics);
  if Pos(UTF8Encode('スイープ'),Caption)>0 then Exit(icSweep);
  if Pos(UTF8Encode('検証'),Caption)>0 then Exit(icValidate);
  if (Pos(UTF8Encode('更新'),Caption)>0) or (Pos(UTF8Encode('再表示'),Caption)>0) then Exit(icRefresh);
  if Pos('CSV',Caption)>0 then Exit(icExport);
  if Pos(UTF8Encode('保存'),Caption)>0 then Exit(icSave);
  if Pos(UTF8Encode('コピー'),Caption)>0 then Exit(icCopy);
  if Pos(UTF8Encode('フォーム'),Caption)>0 then Exit(icForm);
  if Pos(UTF8Encode('登録'),Caption)>0 then Exit(icRegister);
  if (Pos(UTF8Encode('ログイン'),Caption)>0) or (Pos(UTF8Encode('接続…'),Caption)>0) then Exit(icConnect);
  if Pos(UTF8Encode('開く'),Caption)>0 then Exit(icOpen);
  if Pos('SQL',Caption)>0 then Exit(icSQL);
end;

procedure AssignTreeImages(Tree: TTreeView; OnlineServers: TStrings; Connected: Boolean; const ActiveDatabase: string);
var N:TTreeNode;Kind:PtrUInt;Image:Integer;
begin
  N:=Tree.Items.GetFirstNode;
  while N<>nil do begin
    Kind:=PtrUInt(N.Data);Image:=icFolder;
    if Kind=400 then Image:=icServers
    else if Kind=300 then begin
      if OnlineServers.IndexOf(N.Text)>=0 then Image:=icServer else Image:=icServerOffline;
    end else if Kind=200 then begin
      if Connected and (N.Text=ActiveDatabase) then Image:=icDatabase else Image:=icDatabaseOffline;
    end else if Kind=501 then Image:=icBackup else if Kind=502 then Image:=icLog else if Kind=503 then Image:=icUsers
    else begin
      if (Kind>100) and (Kind<200) then Dec(Kind,100);
      case Kind of
        1:Image:=icTable;2:Image:=icView;3:Image:=icProcedure;4:Image:=icTrigger;
        5:Image:=icSequence;6:Image:=icDomain;7:Image:=icIndex;8:Image:=icFunction;
        9:Image:=icException;10:Image:=icRole;11:Image:=icPackage;12:Image:=icBlobFilter;
      end;
    end;
    N.ImageIndex:=Image;N.SelectedIndex:=Image;N:=N.GetNext;
  end;
end;

end.
