unit AppTheme;

{$mode objfpc}{$H+}

interface

uses Classes, Controls, Forms, Graphics, ExtCtrls;

type
  TWorkspaceSurface=class(TPanel)
  protected
    procedure Paint; override;
  end;

procedure ApplyModernTheme(AForm: TCustomForm);

implementation

uses ConsolePreferences, SysUtils, Math, StdCtrls, ComCtrls, Grids, Buttons,
  DBGrids, {$IFDEF WINDOWS}Windows, UxTheme,{$ENDIF} LCLType, LCLProc, Menus, Types, ImgList;

var
  ThemeBackground, ThemeSurface, ThemeText, ThemeMuted, ThemeHeader,
    ThemeLine: TColor;

type
  TMenuThemePainter = class(TComponent)
  private
    procedure DrawMenuItem(Sender: TObject; ACanvas: TCanvas; ARect: TRect;
      AState: TOwnerDrawState);
    procedure MeasureMenuItem(Sender: TObject; ACanvas: TCanvas;
      var AWidth, AHeight: Integer);
    procedure DrawStatusPanel(StatusBar: TStatusBar; Panel: TStatusPanel;
      const ARect: TRect);
    procedure ApplyControlThemes(AControl: TControl);
  public
    procedure ApplyToForm(AForm: TCustomForm);
  end;

function CleanMenuCaption(const S: string): string;
var I: Integer;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do begin
    if (S[I] = '(') and (I + 3 <= Length(S)) and (S[I + 1] = '&') and
       (S[I + 3] = ')') then
      Inc(I, 4)
    else if S[I] = '&' then begin
      if (I < Length(S)) and (S[I + 1] = '&') then begin
        Result := Result + '&';
        Inc(I, 2);
      end else
        Inc(I);
    end else begin
      Result := Result + S[I];
      Inc(I);
    end;
  end;
end;

procedure TMenuThemePainter.MeasureMenuItem(Sender: TObject; ACanvas: TCanvas;
  var AWidth, AHeight: Integer);
var Item: TMenuItem; S: string; Img: TCustomImageList; ImgWidth, IconWidth: Integer;
    IsMenuBarItem: Boolean;
begin
  if not (Sender is TMenuItem) then Exit;
  Item := TMenuItem(Sender);
  IsMenuBarItem := (Item.GetParentMenu is TMainMenu) and
    (Item.Parent=Item.GetParentMenu.Items);
  if Item.IsLine then begin
    AWidth := Max(AWidth, 90);
    AHeight := 9;
    Exit;
  end;
  ACanvas.Font.Name := 'Segoe UI';
  ACanvas.Font.Size := 9;
  S := CleanMenuCaption(Item.Caption);
  Item.GetImageList(Img, ImgWidth);
  IconWidth := 0;
  if (Img <> nil) and (Item.ImageIndex >= 0) then begin
    IconWidth := ImgWidth;
    if IconWidth <= 0 then IconWidth := Img.Width;
  end;
  if IsMenuBarItem then begin
    AWidth := ACanvas.TextWidth(S) + 18;
  end else AWidth := ACanvas.TextWidth(S) + 36;
  if IconWidth > 0 then
    AWidth := Max(AWidth, ACanvas.TextWidth(S) + IconWidth + 41);
  if (not IsMenuBarItem) and (Item.ShortCut <> 0) then
    Inc(AWidth, ACanvas.TextWidth(ShortCutToText(Item.ShortCut)) + 28);
  if (Item.Count > 0) and (not IsMenuBarItem) then Inc(AWidth, 16);
  AHeight := 28;
end;

procedure TMenuThemePainter.DrawMenuItem(Sender: TObject; ACanvas: TCanvas;
  ARect: TRect; AState: TOwnerDrawState);
var Item: TMenuItem; Img: TCustomImageList; ImgWidth, IconWidth, X, Y: Integer;
    Selected, Disabled: Boolean; BackColor, TextColor, LineColor: TColor;
    S, ShortcutText: string; R: TRect; P: array[0..2] of TPoint;
    IsMenuBarItem: Boolean;
begin
  if not (Sender is TMenuItem) then Exit;
  Item := TMenuItem(Sender);
  IsMenuBarItem := (Item.GetParentMenu is TMainMenu) and
    (Item.Parent=Item.GetParentMenu.Items);
  Selected := odSelected in AState;
  Disabled := not Item.Enabled;
  if IsMenuBarItem then BackColor:=ThemeHeader
  else BackColor := RGBToColor(255, 255, 255);
  TextColor := RGBToColor(32, 36, 42);
  LineColor := RGBToColor(218, 224, 231);
  if Selected then BackColor := RGBToColor(220, 235, 250);
  ACanvas.Brush.Style := bsSolid;
  ACanvas.Brush.Color := BackColor;
  ACanvas.FillRect(ARect);
  if Item.IsLine then begin
    ACanvas.Pen.Color := LineColor;
    ACanvas.MoveTo(ARect.Left + 8, (ARect.Top + ARect.Bottom) div 2);
    ACanvas.LineTo(ARect.Right - 8, (ARect.Top + ARect.Bottom) div 2);
    Exit;
  end;
  ACanvas.Font.Name := 'Segoe UI';
  ACanvas.Font.Size := 9;
  if Disabled then TextColor := RGBToColor(135, 140, 148);
  ACanvas.Font.Color := TextColor;
  S := CleanMenuCaption(Item.Caption);
  X := ARect.Left + 10;
  Item.GetImageList(Img, ImgWidth);
  if (Img <> nil) and (Item.ImageIndex >= 0) then begin
    IconWidth := ImgWidth;
    if IconWidth <= 0 then IconWidth := Img.Width;
    Y := ARect.Top + (ARect.Bottom - ARect.Top - Img.Height) div 2;
    Img.Draw(ACanvas, X, Y, Item.ImageIndex, Item.Enabled);
    Inc(X, IconWidth + 6);
  end else if Item.Checked then begin
    ACanvas.TextOut(X, ARect.Top + (ARect.Bottom - ARect.Top - ACanvas.TextHeight('✓')) div 2, '✓');
    Inc(X, 18);
  end;
  R := ARect;
  R.Left := X;
  if IsMenuBarItem then R.Right := ARect.Right - 6
  else if Item.ShortCut <> 0 then
    R.Right := ARect.Right - 24 - ACanvas.TextWidth(ShortCutToText(Item.ShortCut)) - 10
  else R.Right := ARect.Right - 24;
  R.Top := ARect.Top + (ARect.Bottom - ARect.Top - ACanvas.TextHeight(S)) div 2;
  R.Bottom := R.Top + ACanvas.TextHeight(S);
  ACanvas.TextRect(R, R.Left, R.Top, S);
  if (not IsMenuBarItem) and (Item.ShortCut <> 0) then begin
    ShortcutText := ShortCutToText(Item.ShortCut);
    ACanvas.TextOut(ARect.Right - 24 - ACanvas.TextWidth(ShortcutText), R.Top, ShortcutText);
  end;
  if (Item.Count > 0) and (not IsMenuBarItem) then begin
    P[0] := Point(ARect.Right - 14, (ARect.Top + ARect.Bottom) div 2 - 4);
    P[1] := Point(ARect.Right - 8, (ARect.Top + ARect.Bottom) div 2);
    P[2] := Point(ARect.Right - 14, (ARect.Top + ARect.Bottom) div 2 + 4);
    ACanvas.Brush.Color := TextColor;
    ACanvas.Pen.Color := TextColor;
    ACanvas.Polygon(P);
  end;
end;

procedure TMenuThemePainter.ApplyToForm(AForm: TCustomForm);
var I: Integer; C: TComponent; M: TMenu;
begin
  for I := 0 to AForm.ComponentCount - 1 do begin
    C := AForm.Components[I];
    if C is TMenu then begin
      M := TMenu(C);
      M.OwnerDraw := True;
      M.OnDrawItem := @DrawMenuItem;
      M.OnMeasureItem := @MeasureMenuItem;
    end;
  end;
  ApplyControlThemes(AForm);
end;

procedure TMenuThemePainter.DrawStatusPanel(StatusBar: TStatusBar;
  Panel: TStatusPanel; const ARect: TRect);
begin
  StatusBar.Canvas.Brush.Color := RGBToColor(225,231,241);
  StatusBar.Canvas.Font.Color := RGBToColor(32, 36, 42);
  StatusBar.Canvas.FillRect(ARect);
  StatusBar.Canvas.TextRect(ARect, ARect.Left + 4, ARect.Top + 2, Panel.Text);
end;

procedure TMenuThemePainter.ApplyControlThemes(AControl: TControl);
var I: Integer; W: TWinControl; SB: TStatusBar;
begin
  if AControl is TStatusBar then begin
    SB := TStatusBar(AControl);
    SB.Color := ThemeHeader;
    SB.OnDrawPanel := @DrawStatusPanel;
    for I := 0 to SB.Panels.Count - 1 do
      SB.Panels[I].Style := psOwnerDraw;
  end;
  if AControl is TWinControl then begin
    W := TWinControl(AControl);
    for I := 0 to W.ControlCount - 1 do
      ApplyControlThemes(W.Controls[I]);
  end;
end;

procedure LoadThemeColors;
begin
  ThemeBackground:=RGBToColor(196,208,225);
  ThemeSurface:=RGBToColor(247,249,253);
  ThemeText:=RGBToColor(32,36,42);
  ThemeMuted:=RGBToColor(94,102,112);
  ThemeHeader:=RGBToColor(225,231,241);
  ThemeLine:=RGBToColor(214,222,231);
end;

procedure TWorkspaceSurface.Paint;
begin
  Canvas.Brush.Color:=ThemeBackground;
  Canvas.FillRect(ClientRect);
  Canvas.Pen.Color:=RGBToColor(214,222,233);
  Canvas.Brush.Color:=Color;
  Canvas.RoundRect(0,0,ClientWidth-1,ClientHeight-1,16,16);
end;

{$IFDEF WINDOWS}
procedure ApplyCaptionColor(AForm:TCustomForm);
type TSetAttribute=function(Wnd:HWND;Attribute:DWORD;Value:Pointer;Size:DWORD):LongInt; stdcall;
var Module:HMODULE;SetAttribute:TSetAttribute;CaptionColor,TextColor:DWORD;
begin
  if AForm.BorderStyle=bsNone then Exit;
  Module:=LoadLibrary('dwmapi.dll');
  if Module=0 then Exit;
  try
    Pointer(SetAttribute):=GetProcAddress(Module,'DwmSetWindowAttribute');
    if Assigned(SetAttribute) then begin
      CaptionColor:=RGB(47,52,62);TextColor:=RGB(235,239,246);
      SetAttribute(AForm.Handle,35,@CaptionColor,SizeOf(CaptionColor));
      SetAttribute(AForm.Handle,36,@TextColor,SizeOf(TextColor));
    end;
  finally FreeLibrary(Module);end;
end;
{$ENDIF}

{$IFDEF WINDOWS}
procedure ApplyListViewTheme(AList:TListView);
var ThemeName: WideString;
begin
  ThemeName := 'Explorer';
  if not AList.HandleAllocated then Exit;
  if not InitThemeLibrary then Exit;
  try
    SetWindowTheme(AList.Handle, PWideChar(ThemeName), nil);
    AList.Invalidate;
  finally
    FreeThemeLibrary;
  end;
end;

{$ENDIF}
procedure StyleControl(AControl: TControl);
var
  I: Integer;
  C: TControl;
  KeepMonoFont: Boolean;
begin
  KeepMonoFont := SameText(AControl.Font.Name, 'Consolas');
  {$IFDEF WINDOWS}
  if not KeepMonoFont then AControl.Font.Name := 'Segoe UI';
  {$ELSE}
  if KeepMonoFont then AControl.Font.Name := 'Monospace';
  {$ENDIF}
  if AControl.Font.Size<=9 then AControl.Font.Size := 9;
  AControl.Font.Color := ThemeText;

  if AControl is TPanel then
  begin
    TPanel(AControl).BevelOuter := bvNone;
    TPanel(AControl).Color := ThemeSurface;
  end
  else if AControl is TToolBar then
  begin
    TToolBar(AControl).Flat := True;
    TToolBar(AControl).ShowHint := True;
    TToolBar(AControl).EdgeBorders:=[];
    TToolBar(AControl).Color := ThemeSurface;
  end
  else if AControl is TTreeView then
  begin
    TTreeView(AControl).BorderStyle:=bsNone;
    TTreeView(AControl).Color := ThemeSurface;
    TTreeView(AControl).Font.Color := ThemeText;
  end
  else if AControl is TListView then
  begin
    TListView(AControl).BorderStyle:=bsNone;
    TListView(AControl).Color := ThemeSurface;
    TListView(AControl).Font.Color := ThemeText;
    TListView(AControl).GridLines := False;
    {$IFDEF WINDOWS}ApplyListViewTheme(TListView(AControl));{$ENDIF}
  end
  else if AControl is TStringGrid then
  begin
    TStringGrid(AControl).Color := ThemeSurface;
    TStringGrid(AControl).FixedColor := ThemeHeader;
    TStringGrid(AControl).Font.Color := ThemeText;
  end
  else if AControl is TDBGrid then
  begin
    TDBGrid(AControl).Color := ThemeSurface;
    TDBGrid(AControl).FixedColor := ThemeHeader;
    TDBGrid(AControl).Font.Color := ThemeText;
  end
  else if AControl is TCustomEdit then
    TCustomEdit(AControl).Color := clWhite
  else if AControl is TCustomComboBox then
    TCustomComboBox(AControl).Color := clWhite
  else if AControl is TMemo then
  begin
    TMemo(AControl).Color := ThemeSurface;
  end
  else if AControl is TStatusBar then
    TStatusBar(AControl).Color := ThemeHeader
  else if AControl is TSplitter then
  begin
    TSplitter(AControl).Color := ThemeLine;
  end
  else if AControl is TLabel then
    if fsBold in TLabel(AControl).Font.Style then
      TLabel(AControl).Font.Color := ThemeText
    else
      TLabel(AControl).Font.Color := ThemeMuted;

  if AControl is TWinControl then
    for I := 0 to TWinControl(AControl).ControlCount - 1 do
    begin
      C := TWinControl(AControl).Controls[I];
      StyleControl(C);
    end;
end;

procedure ApplyModernTheme(AForm: TCustomForm);
var I: Integer; Painter: TMenuThemePainter; FoundPainter: Boolean;
begin
  if AForm = nil then Exit;
  LoadThemeColors;
  {$IFDEF WINDOWS}AForm.Font.Name := 'Segoe UI';{$ENDIF}
  AForm.Font.Size := 9;
  AForm.Font.Color := ThemeText;
  AForm.Color := ThemeBackground;
  AForm.DoubleBuffered := True;
  StyleControl(AForm);
  {$IFDEF WINDOWS}
  Painter := nil;
  FoundPainter := False;
  for I := 0 to AForm.ComponentCount - 1 do
    if AForm.Components[I] is TMenuThemePainter then begin
      Painter := TMenuThemePainter(AForm.Components[I]);
      FoundPainter := True;
      Break;
    end;
  if not FoundPainter then Painter := TMenuThemePainter.Create(AForm);
  Painter.ApplyToForm(AForm);
  ApplyCaptionColor(AForm);
  {$ENDIF}
  ApplyFormPreferences(AForm);
end;

end.

