unit PreferencesDialog;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes,Forms,ConsolePreferences;
type TOptionsValidator=function(const Value:TConsolePreferences):Boolean of object;
procedure ShowConsoleOptions(Owner:TComponent;Validate:TOptionsValidator);
procedure ShowHighlightOptions(Owner:TComponent);
procedure CapturePreferenceDialog(Highlight:Boolean;const Path:string);
implementation
uses SysUtils,Controls,StdCtrls,ExtCtrls,ComCtrls,Buttons,Graphics,Dialogs,ColorBox,SynEdit,AppTheme;
type
 TPreferencesForm=class(TForm)
 private
  Candidate:TConsolePreferences;Validator:TOptionsValidator;IsHighlight,FLoading:Boolean;
  Automatic,Manual:TRadioButton;Upper:TCheckBox;FontLabel,Sample:TLabel;
  Elements:TListBox;ForegroundBox,BackgroundBox:TColorBox;
  BoldBox,ItalicBox,UnderlineBox,DefaultFG,DefaultBG:TCheckBox;Preview:TSynEdit;
  procedure Changed(Sender:TObject);
  procedure SelectElement(Sender:TObject);
  procedure ChooseFont(Sender:TObject);
  procedure PaletteClick(Sender:TObject);
  procedure ApplyClick(Sender:TObject);
  procedure AcceptClick(Sender:TObject);
  function Commit:Boolean;
  procedure PreviewSettings;
 public
  constructor CreateOptions(AOwner:TComponent;Highlight:Boolean);
 end;
function LabelAt(Owner:TComponent;Parent:TWinControl;const Caption:string;X,Y,W:Integer):TLabel;
begin Result:=TLabel.Create(Owner);Result.Parent:=Parent;Result.AutoSize:=False;Result.Caption:=Caption;Result.SetBounds(X,Y,W,22);end;
function CheckAt(Owner:TComponent;Parent:TWinControl;const Caption:string;X,Y,W:Integer;Handler:TNotifyEvent):TCheckBox;
begin Result:=TCheckBox.Create(Owner);Result.Parent:=Parent;Result.AutoSize:=False;Result.Caption:=Caption;Result.SetBounds(X,Y,W,24);Result.OnChange:=Handler;end;
constructor TPreferencesForm.CreateOptions(AOwner:TComponent;Highlight:Boolean);
var Pages:TPageControl;Tab:TPanel;Sheet:TTabSheet;Language:TComboBox;Group:TGroupBox;B:TButton;I:Integer;Swatch:TBitBtn;
const Palette:array[0..15]of TColor=(clBlack,clMaroon,clGreen,clOlive,clNavy,clPurple,clTeal,clSilver,clGray,clRed,clLime,clYellow,clBlue,clFuchsia,clAqua,clWhite);
begin
 inherited CreateNew(AOwner);LoadPreferences;Candidate:=Preferences;IsHighlight:=Highlight;
 Position:=poOwnerFormCenter;BorderStyle:=bsDialog;ClientWidth:=640;ClientHeight:=540;
 if not Highlight then begin
 Caption:='オプション';ClientWidth:=420;ClientHeight:=390;
 Pages:=TPageControl.Create(Self);Pages.Parent:=Self;Pages.SetBounds(10,10,400,322);
 Sheet:=TTabSheet.Create(Self);Sheet.PageControl:=Pages;Sheet.Caption:='FBConsole';
 Tab:=TPanel.Create(Self);Tab.Parent:=Sheet;Tab.Align:=alClient;Tab.BevelOuter:=bvNone;
 LabelAt(Self,Tab,'言語',16,18,60);Language:=TComboBox.Create(Self);Language.Parent:=Tab;Language.Style:=csDropDownList;Language.SetBounds(85,15,280,28);Language.Items.Add('Japanese');Language.ItemIndex:=0;
 Group:=TGroupBox.Create(Self);Group.Parent:=Tab;Group.Caption:='コミット方法';Group.SetBounds(16,57,350,104);
 Automatic:=TRadioButton.Create(Self);Automatic.Parent:=Group;Automatic.Caption:='自動コミット(&A)';Automatic.SetBounds(12,24,300,24);Automatic.Checked:=Candidate.AutoCommit;
 Manual:=TRadioButton.Create(Self);Manual.Parent:=Group;Manual.Caption:='手動コミット(&M)';Manual.SetBounds(12,59,300,24);Manual.Checked:=not Candidate.AutoCommit;
 Upper:=CheckAt(Self,Tab,'識別子を大文字にする',16,173,340,nil);Upper.Checked:=Candidate.UpperIdentifiers;
 B:=TButton.Create(Self);B.Parent:=Tab;B.Caption:='フォントの変更';B.SetBounds(16,212,130,30);B.OnClick:=@ChooseFont;
 FontLabel:=LabelAt(Self,Tab,'',160,217,205);Sample:=LabelAt(Self,Tab,'The quick brown fox jumped over the lazy dog back.',16,259,365);
 LabelAt(Self,Tab,'現在のフォント例:',16,242,350);
 end else begin
 Caption:='シンタックスエディター・オプション';
 LabelAt(Self,Self,'要素',12,10,180);Elements:=TListBox.Create(Self);Elements.Parent:=Self;Elements.SetBounds(12,33,190,180);Elements.Items.Clear;for I:=0 to SyntaxCount-1 do Elements.Items.Add(SyntaxNames[I]);Elements.ItemIndex:=0;Elements.OnClick:=@SelectElement;
 LabelAt(Self,Self,'色（前景）',217,10,130);
 for I:=0 to 15 do begin Swatch:=TBitBtn.Create(Self);Swatch.Parent:=Self;Swatch.SetBounds(216+(I mod 4)*30,35+(I div 4)*30,28,28);Swatch.Tag:=Palette[I];Swatch.Glyph.SetSize(22,22);Swatch.Glyph.Canvas.Brush.Color:=Palette[I];Swatch.Glyph.Canvas.FillRect(Rect(0,0,22,22));Swatch.Hint:=ColorToString(Palette[I]);Swatch.ShowHint:=True;Swatch.OnClick:=@PaletteClick;end;
 Group:=TGroupBox.Create(Self);Group.Parent:=Self;Group.Caption:='テキスト・スタイル';Group.SetBounds(353,25,270,105);
 BoldBox:=CheckAt(Self,Group,'太字(&B)',10,20,240,@Changed);ItalicBox:=CheckAt(Self,Group,'斜体(&I)',10,45,240,@Changed);UnderlineBox:=CheckAt(Self,Group,'下線(&U)',10,70,240,@Changed);
 DefaultFG:=CheckAt(Self,Self,'デフォルトの前景',353,140,260,@Changed);DefaultBG:=CheckAt(Self,Self,'デフォルトの背景',353,168,260,@Changed);
 ForegroundBox:=TColorBox.Create(Self);ForegroundBox.Parent:=Self;ForegroundBox.SetBounds(215,166,125,26);ForegroundBox.Style:=[cbStandardColors,cbExtendedColors,cbCustomColor];ForegroundBox.OnChange:=@Changed;
 LabelAt(Self,Self,'背景色',353,196,70);
 BackgroundBox:=TColorBox.Create(Self);BackgroundBox.Parent:=Self;BackgroundBox.SetBounds(425,196,198,26);BackgroundBox.Style:=[cbStandardColors,cbExtendedColors,cbCustomColor];BackgroundBox.OnChange:=@Changed;
 B:=TButton.Create(Self);B.Parent:=Self;B.Caption:='フォントの変更';B.SetBounds(12,228,130,30);B.OnClick:=@ChooseFont;FontLabel:=LabelAt(Self,Self,'',155,234,465);
 Preview:=TSynEdit.Create(Self);Preview.Parent:=Self;Preview.SetBounds(12,270,611,205);Preview.ReadOnly:=True;Preview.Gutter.Visible:=False;Preview.Lines.Text:='-- SQL preview'+LineEnding+'Select * from employee'+LineEnding+'where'+LineEnding+'  emp_no > 50 and name = ''Firebird'';';
 end;
 B:=TButton.Create(Self);B.Parent:=Self;B.Caption:='OK';B.SetBounds(ClientWidth-302,ClientHeight-43,90,30);B.Default:=True;B.OnClick:=@AcceptClick;
 B:=TButton.Create(Self);B.Parent:=Self;B.Caption:='キャンセル';B.SetBounds(ClientWidth-204,ClientHeight-43,90,30);B.Cancel:=True;B.ModalResult:=mrCancel;
 B:=TButton.Create(Self);B.Parent:=Self;B.Caption:='適用(&A)';B.SetBounds(ClientWidth-106,ClientHeight-43,94,30);B.OnClick:=@ApplyClick;
 ApplyModernTheme(Self);if Highlight then SelectElement(nil)else PreviewSettings;
end;
procedure TPreferencesForm.PreviewSettings;
begin
 if IsHighlight then begin ApplyEditor(Preview,Candidate);FontLabel.Caption:=Candidate.SQLFontName+' / '+IntToStr(Candidate.SQLFontSize);end
 else begin FontLabel.Caption:=Candidate.FontName+' / '+IntToStr(Candidate.FontSize);Sample.Font.Name:=Candidate.FontName;Sample.Font.Size:=Candidate.FontSize;end;
end;
procedure TPreferencesForm.SelectElement(Sender:TObject);
var I:Integer;
begin
 I:=Elements.ItemIndex;if I<0 then Exit;FLoading:=True;
 try with Candidate.Syntax[I] do begin ForegroundBox.Selected:=Foreground;BackgroundBox.Selected:=Background;DefaultFG.Checked:=DefaultForeground;DefaultBG.Checked:=DefaultBackground;BoldBox.Checked:=fsBold in Style;ItalicBox.Checked:=fsItalic in Style;UnderlineBox.Checked:=fsUnderline in Style;end;finally FLoading:=False;end;PreviewSettings;
end;
procedure TPreferencesForm.Changed(Sender:TObject);
var I:Integer;
begin
 if FLoading then Exit;I:=Elements.ItemIndex;if I<0 then Exit;
 with Candidate.Syntax[I] do begin Foreground:=ForegroundBox.Selected;Background:=BackgroundBox.Selected;DefaultForeground:=DefaultFG.Checked;DefaultBackground:=DefaultBG.Checked;Style:=[];if BoldBox.Checked then Include(Style,fsBold);if ItalicBox.Checked then Include(Style,fsItalic);if UnderlineBox.Checked then Include(Style,fsUnderline);end;PreviewSettings;
end;
procedure TPreferencesForm.PaletteClick(Sender:TObject);
begin DefaultFG.Checked:=False;ForegroundBox.Selected:=TComponent(Sender).Tag;Changed(nil);end;
procedure TPreferencesForm.ChooseFont(Sender:TObject);
var D:TFontDialog;
begin D:=TFontDialog.Create(Self);try if IsHighlight then begin D.Font.Name:=Candidate.SQLFontName;D.Font.Size:=Candidate.SQLFontSize;end else begin D.Font.Name:=Candidate.FontName;D.Font.Size:=Candidate.FontSize;end;
 if D.Execute then begin if IsHighlight then begin Candidate.SQLFontName:=D.Font.Name;Candidate.SQLFontSize:=D.Font.Size;end else begin Candidate.FontName:=D.Font.Name;Candidate.FontSize:=D.Font.Size;end;PreviewSettings;end;finally D.Free;end;
end;
function TPreferencesForm.Commit:Boolean;
begin Result:=False;if not IsHighlight then begin Candidate.AutoCommit:=Automatic.Checked;Candidate.UpperIdentifiers:=Upper.Checked;end;
 if Assigned(Validator)and not Validator(Candidate)then Exit;
 try StorePreferences(Candidate);RefreshPreferences;PreviewSettings;Result:=True;except on E:Exception do MessageDlg('オプション',E.Message,mtError,[mbOK],0);end;
end;
procedure TPreferencesForm.ApplyClick(Sender:TObject);begin Commit;end;
procedure TPreferencesForm.AcceptClick(Sender:TObject);begin if Commit then ModalResult:=mrOK;end;
procedure ShowConsoleOptions(Owner:TComponent;Validate:TOptionsValidator);
var D:TPreferencesForm;
begin D:=TPreferencesForm.CreateOptions(Owner,False);try D.Validator:=Validate;D.ShowModal;finally D.Free;end;end;
procedure ShowHighlightOptions(Owner:TComponent);
var D:TPreferencesForm;
begin D:=TPreferencesForm.CreateOptions(Owner,True);try D.ShowModal;finally D.Free;end;end;
procedure CapturePreferenceDialog(Highlight:Boolean;const Path:string);
var D:TPreferencesForm;Bitmap:TBitmap;PNG:TPortableNetworkGraphic;
begin D:=TPreferencesForm.CreateOptions(nil,Highlight);try D.Show;Application.ProcessMessages;D.Update;Bitmap:=D.GetFormImage;PNG:=TPortableNetworkGraphic.Create;try PNG.Assign(Bitmap);PNG.SaveToFile(Path);finally PNG.Free;Bitmap.Free;end;finally D.Free;end;end;
end.
