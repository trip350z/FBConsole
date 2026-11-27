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

uses Math;

const
  CInk = $0054493F;         // Slate outline; all ordinary symbols use this color.
  COnline = $0052971E;      // RGB(30,151,82)
  COffline = $003939D8;     // RGB(216,57,57)
  CTransparent = $00FDF9F7; // Matches the light workspace behind antialiased edges.
  RenderScale = 4;

function CreateConsoleImages(AOwner: TComponent; IconSize: Integer): TImageList;
var
  Source, Scaled: Graphics.TBitmap;
  C: TCanvas;
  K: Integer;

  function Px(Value: Double): Integer;
  begin
    Result := Round(Value * RenderScale);
  end;

  procedure Pen(Color: TColor = CInk; Width: Double = 1.4);
  begin
    C.Pen.Color := Color;
    C.Pen.Width := Px(Width);
    C.Pen.Style := psSolid;
    C.Brush.Style := bsClear;
  end;

  procedure Line(X1, Y1, X2, Y2: Double; Color: TColor = CInk);
  begin
    Pen(Color);
    C.MoveTo(Px(X1), Px(Y1));
    C.LineTo(Px(X2), Px(Y2));
  end;

  procedure Path(const Coordinates: array of Double; Closed: Boolean = False);
  var I: Integer;
  begin
    Pen;
    C.MoveTo(Px(Coordinates[0]), Px(Coordinates[1]));
    for I := 1 to Length(Coordinates) div 2 - 1 do
      C.LineTo(Px(Coordinates[I * 2]), Px(Coordinates[I * 2 + 1]));
    if Closed then C.LineTo(Px(Coordinates[0]), Px(Coordinates[1]));
  end;

  procedure Box(Left, Top, Right, Bottom: Double);
  begin
    Pen;
    C.RoundRect(Px(Left), Px(Top), Px(Right), Px(Bottom), Px(2), Px(2));
  end;

  procedure Ellipse(Left, Top, Right, Bottom: Double);
  begin
    Pen;
    C.Ellipse(Px(Left), Px(Top), Px(Right), Px(Bottom));
  end;

  procedure Arc(CX, CY, RX, RY, FirstAngle, LastAngle: Double);
  var I: Integer; Angle: Double;
  begin
    Pen;
    for I := 0 to 24 do begin
      Angle := (FirstAngle + (LastAngle - FirstAngle) * I / 24) * Pi / 180;
      if I = 0 then C.MoveTo(Px(CX + RX * Cos(Angle)), Px(CY + RY * Sin(Angle)))
      else C.LineTo(Px(CX + RX * Cos(Angle)), Px(CY + RY * Sin(Angle)));
    end;
  end;

  procedure ClearBadge;
  begin
    C.Pen.Style := psClear;
    C.Brush.Style := bsSolid;
    C.Brush.Color := CTransparent;
    C.Ellipse(Px(9.5), Px(9.5), Px(20.5), Px(20.5));
    Pen;
  end;

  procedure Check(Color: TColor; Online: Boolean);
  begin
    ClearBadge;
    if Online then begin
      Line(11.5, 14.5, 14, 17, Color);
      Line(14, 17, 19, 11.5, Color);
    end else begin
      Line(12, 12, 18, 18, Color);
      Line(18, 12, 12, 18, Color);
    end;
  end;

  procedure PlusBadge;
  begin
    ClearBadge;
    Line(15, 11, 15, 19);
    Line(11, 15, 19, 15);
  end;

  procedure ArrowBadge(Down: Boolean);
  begin
    ClearBadge;
    if Down then begin
      Line(15, 10, 15, 18);
      Path([11.5, 14.5, 15, 18, 18.5, 14.5]);
    end else begin
      Line(15, 19, 15, 11);
      Path([11.5, 14.5, 15, 11, 18.5, 14.5]);
    end;
  end;

  procedure Server;
  begin
    Box(3, 2, 16, 18);
    Line(3, 7.5, 16, 7.5);
    Line(3, 12.5, 16, 12.5);
    Line(5.5, 5, 7, 5);
    Line(5.5, 10, 7, 10);
    Line(5.5, 15, 7, 15);
  end;

  procedure Database;
  begin
    Ellipse(3, 2, 17, 7);
    Line(3, 4.5, 3, 15.5);
    Line(17, 4.5, 17, 15.5);
    Arc(10, 10, 7, 2.5, 0, 180);
    Arc(10, 15.5, 7, 2.5, 0, 180);
  end;

  procedure Folder;
  begin
    Path([2, 6, 2, 17, 18, 17, 18, 8, 10, 8, 8, 5, 2, 5], True);
  end;

  procedure Document;
  begin
    Path([4, 2, 12, 2, 16, 6, 16, 18, 4, 18], True);
    Path([12, 2, 12, 6, 16, 6]);
  end;

  procedure Table;
  begin
    Box(3, 3, 17, 17);
    Line(3, 7, 17, 7);
    Line(3, 12, 17, 12);
    Line(8, 7, 8, 17);
    Line(12.5, 7, 12.5, 17);
  end;

  procedure Person(X, Y: Double);
  begin
    Ellipse(X + 2, Y, X + 8, Y + 6);
    Arc(X + 5, Y + 14, 5, 5, 180, 360);
    Line(X, Y + 14, X + 10, Y + 14);
  end;

begin
  IconSize := EnsureRange(IconSize, 16, 64);
  Result := TImageList.Create(AOwner);
  Result.Width := IconSize;
  Result.Height := IconSize;
  Source := Graphics.TBitmap.Create;
  Scaled := Graphics.TBitmap.Create;
  try
    // Use the same oversampled paths on Windows and Linux, including 16px tabs.
    Source.SetSize(20 * RenderScale, 20 * RenderScale);
    Scaled.SetSize(IconSize, IconSize);
    C := Source.Canvas;
    for K := 0 to ConsoleIconCount - 1 do begin
      C.Brush.Style := bsSolid;
      C.Brush.Color := CTransparent;
      C.FillRect(0, 0, Source.Width, Source.Height);
      Pen;
      case K of
        icServer, icConnect: begin Server; Check(COnline, True); end;
        icServerOffline, icDisconnect: begin Server; Check(COffline, False); end;
        icRegister: begin Server; PlusBadge; end;
        icServers: begin
          Box(2, 2, 13, 14); Box(7, 6, 18, 18);
          Line(9.5, 10, 15.5, 10); Line(9.5, 14, 15.5, 14);
        end;
        icDatabase, icDatabaseConnect: begin Database; Check(COnline, True); end;
        icDatabaseOffline: begin Database; Check(COffline, False); end;
        icDatabaseCreate: begin Database; PlusBadge; end;
        icDatabaseRegister: begin
          Database; ClearBadge; Box(11, 10, 19, 19);
          Line(13, 13, 17, 13); Line(13, 16, 17, 16);
        end;
        icBackup: begin Database; ArrowBadge(True); end;
        icRestore: begin Database; ArrowBadge(False); end;
        icFolder: Folder;
        icOpen: begin Folder; ArrowBadge(False); end;
        icTable: Table;
        icView: begin
          Table; ClearBadge; Ellipse(9.5, 11, 19, 17);
          Ellipse(12.5, 12, 16, 15.5);
        end;
        icProcedure: begin
          Document; Path([7, 9, 9.5, 11, 7, 13]); Line(11, 14, 14, 14);
        end;
        icDomain: Path([10, 2, 18, 10, 10, 18, 2, 10], True);
        icFunction: begin
          Path([10, 3, 8, 3, 6, 17, 4, 17]); Line(4, 8, 10, 8);
          Arc(14, 10, 3.5, 6, 110, 250); Arc(14, 10, 3.5, 6, -70, 70);
          Line(12, 8, 16, 12); Line(16, 8, 12, 12);
        end;
        icSequence: begin
          Line(3, 5, 10, 5); Line(3, 10, 10, 10); Line(3, 15, 10, 15);
          Path([14, 3, 17, 6, 14, 9]); Path([14, 11, 17, 14, 14, 17]);
        end;
        icException: begin
          Path([10, 2, 19, 18, 1, 18], True);
          Line(10, 7, 10, 12); Line(10, 14, 10, 15.5);
        end;
        icRole: begin Person(2, 3); ClearBadge; Ellipse(11, 11, 16, 16); Path([15, 15, 19, 19, 19, 16]); end;
        icUsers: begin Person(1, 3); Arc(13, 6, 3, 3, -90, 90); Arc(13, 17, 5, 5, 270, 360); end;
        icLog: begin Document; Line(7, 9, 13, 9); Line(7, 12, 13, 12); Line(7, 15, 12, 15); end;
        icSQL: begin
          Box(1.5, 3, 18.5, 17);
          {$IFDEF WINDOWS}C.Font.Name := 'Consolas';{$ELSE}C.Font.Name := 'Monospace';{$ENDIF}
          C.Font.Height := -Px(6); C.Font.Style := []; C.Font.Color := CInk;
          C.Brush.Style := bsClear;
          C.TextOut((Source.Width - C.TextWidth('SQL')) div 2,
            (Source.Height - C.TextHeight('SQL')) div 2, 'SQL');
        end;
        icCommit: Path([3, 10, 8, 15, 18, 4]);
        icRollback: begin Arc(10, 11, 7, 6, -170, 110); Path([2, 8, 3, 3, 8, 4]); end;
        icProperties: begin
          Line(3, 5, 17, 5); Line(3, 10, 17, 10); Line(3, 15, 17, 15);
          Box(6, 3, 9, 7); Box(12, 8, 15, 12); Box(5, 13, 8, 17);
        end;
        icRefresh: begin Arc(10, 10, 7, 7, -50, 255); Path([12, 3, 17, 3, 17, 8]); end;
        icTrigger: Path([11, 1.5, 4, 11, 9, 11, 8, 18.5, 16, 8, 11, 8], True);
        icIndex: begin Ellipse(2, 3, 10, 11); Path([8.5, 9.5, 17, 18, 19, 16]); Line(12, 13, 14, 11); end;
        icPackage: begin
          Path([10, 2, 18, 6, 18, 15, 10, 19, 2, 15, 2, 6], True);
          Path([2, 6, 10, 10, 18, 6]); Line(10, 10, 10, 19); Line(6, 4, 14, 8);
        end;
        icSweep: begin
          Line(15, 2, 8, 11); Path([5, 9, 12, 14, 9, 18, 2, 13], True);
          Line(6, 12, 4, 15); Line(9, 14, 7, 17);
        end;
        icValidate: begin
          Path([10, 2, 17, 5, 16, 13, 10, 18, 4, 13, 3, 5], True);
          Path([6, 10, 9, 13, 14, 7]);
        end;
        icExport: begin Document; ArrowBadge(False); end;
        icSave: begin
          Path([3, 2, 15, 2, 18, 5, 18, 18, 3, 18], True);
          Box(6, 2, 13, 7); Box(6, 11, 15, 18);
        end;
        icCopy: begin Box(7, 2, 18, 14); Box(2, 6, 13, 18); end;
        icForm: begin Box(2, 3, 18, 17); Line(2, 7, 18, 7); Line(5, 5, 6, 5); Line(8, 5, 9, 5); end;
        icStatistics: begin Box(3, 11, 6, 18); Box(8.5, 7, 11.5, 18); Box(14, 2, 17, 18); end;
        icPreviousQuery: begin Path([9, 4, 3, 10, 9, 16]); Line(3, 10, 18, 10); end;
        icNextQuery: begin Path([11, 4, 17, 10, 11, 16]); Line(2, 10, 17, 10); end;
        icSearch: begin Ellipse(2, 2, 14, 14); Line(12.5, 12.5, 18.5, 18.5); end;
        icFetchAll: begin
          Database; ClearBadge; Line(15, 10, 15, 16);
          Path([11.5, 13, 15, 16, 18.5, 13]);
          Path([11.5, 16, 15, 19, 18.5, 16]);
        end;
        icPlan: begin
          Box(7, 2, 13, 7); Path([10, 7, 10, 11, 4, 11, 4, 14]);
          Path([10, 11, 16, 11, 16, 14]); Box(1, 14, 7, 19); Box(13, 14, 19, 19);
        end;
        icPrint: begin Box(5, 2, 15, 8); Box(2, 7, 18, 15); Box(5, 12, 15, 19); Line(14, 10, 15, 10); end;
        icBlobFilter: Path([2, 3, 18, 3, 12, 10, 12, 16, 8, 18, 8, 10], True);
      end;
      Scaled.Canvas.Brush.Style := bsSolid;
      Scaled.Canvas.Brush.Color := CTransparent;
      Scaled.Canvas.FillRect(0, 0, IconSize, IconSize);
      {$IFDEF WINDOWS}
      SetStretchBltMode(Scaled.Canvas.Handle, HALFTONE);
      SetBrushOrgEx(Scaled.Canvas.Handle, 0, 0, nil);
      {$ENDIF}
      Scaled.Canvas.StretchDraw(Types.Rect(0, 0, IconSize, IconSize), Source);
      Result.AddMasked(Scaled, CTransparent);
    end;
  finally
    Scaled.Free;
    Source.Free;
  end;
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
  if Pos(UTF8Encode('データベースの作成'),Caption)>0 then Exit(icDatabaseCreate);
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
