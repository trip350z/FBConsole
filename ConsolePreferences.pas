unit ConsolePreferences;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes,SysUtils,Graphics,Forms,Controls,SynEdit,SynHighlighterSQL,SynEditHighlighter;
const SyntaxCount=14;
      SyntaxNames:array[0..SyntaxCount-1]of string=('Comment','Data Type','Default Packages','Exception','Function','Identifier','Number','PL/SQL Reserved Word','Reserved Word','Space','String','Symbol','Table Name','Variable');
type
  TSyntaxPreference=record Foreground,Background:TColor;DefaultForeground,DefaultBackground:Boolean;Style:TFontStyles;end;
  TConsolePreferences=record AutoCommit,UpperIdentifiers:Boolean;FontName,SQLFontName:string;FontSize,SQLFontSize:Integer;Syntax:array[0..SyntaxCount-1]of TSyntaxPreference;end;
var Preferences:TConsolePreferences;
procedure Defaults(out Value:TConsolePreferences);
procedure LoadPreferences;
procedure StorePreferences(const Value:TConsolePreferences);
procedure ApplyEditor(Editor:TSynEdit;const Value:TConsolePreferences);
procedure ApplyFormPreferences(Form:TCustomForm);
procedure RefreshPreferences;
function Attribute(H:TSynSQLSyn;Index:Integer):TSynHighlighterAttributes;
function UppercaseIdentifiers(const SQL:string):string;
implementation
uses IniFiles,StdCtrls;
var Loaded:Boolean=False;
function FileName:string;
begin Result:=ExtractFilePath(ParamStr(0))+'config'+PathDelim+'options.ini';end;
procedure Defaults(out Value:TConsolePreferences);
var I:Integer;
begin
  Value.AutoCommit:=False;Value.UpperIdentifiers:=False;
  {$IFDEF WINDOWS}Value.FontName:='Segoe UI';Value.SQLFontName:='Consolas';{$ELSE}Value.FontName:='Sans';Value.SQLFontName:='Monospace';{$ENDIF}
  Value.FontSize:=9;Value.SQLFontSize:=10;
  for I:=0 to SyntaxCount-1 do begin Value.Syntax[I].Foreground:=clBlack;Value.Syntax[I].Background:=clWhite;Value.Syntax[I].DefaultForeground:=True;Value.Syntax[I].DefaultBackground:=True;Value.Syntax[I].Style:=[];end;
  Value.Syntax[0].Foreground:=clGray;Value.Syntax[0].DefaultForeground:=False;Value.Syntax[0].Style:=[fsItalic];
  Value.Syntax[6].Foreground:=clGreen;Value.Syntax[6].DefaultForeground:=False;
  Value.Syntax[8].Style:=[fsBold];Value.Syntax[10].Foreground:=clBlue;Value.Syntax[10].DefaultForeground:=False;
end;
procedure LoadPreferences;
var Ini:TIniFile;I:Integer;S:string;
begin
 if Loaded then Exit;Loaded:=True;Defaults(Preferences);Ini:=TIniFile.Create(FileName);
 try
 Preferences.AutoCommit:=Ini.ReadBool('Console','AutoCommit',False);Preferences.UpperIdentifiers:=Ini.ReadBool('Console','UpperIdentifiers',False);
 Preferences.FontName:=Ini.ReadString('Console','FontName',Preferences.FontName);Preferences.FontSize:=Ini.ReadInteger('Console','FontSize',9);
 Preferences.SQLFontName:=Ini.ReadString('Editor','FontName',Preferences.SQLFontName);Preferences.SQLFontSize:=Ini.ReadInteger('Editor','FontSize',10);
 if (Preferences.FontSize<6)or(Preferences.FontSize>40)then Preferences.FontSize:=9;
 if (Preferences.SQLFontSize<6)or(Preferences.SQLFontSize>40)then Preferences.SQLFontSize:=10;
 for I:=0 to SyntaxCount-1 do begin S:='Syntax'+IntToStr(I);with Preferences.Syntax[I] do begin
 Foreground:=Ini.ReadInteger(S,'Foreground',Foreground);Background:=Ini.ReadInteger(S,'Background',Background);DefaultForeground:=Ini.ReadBool(S,'DefaultForeground',DefaultForeground);DefaultBackground:=Ini.ReadBool(S,'DefaultBackground',DefaultBackground);
 Style:=[];if Ini.ReadBool(S,'Bold',I=8)then Include(Style,fsBold);if Ini.ReadBool(S,'Italic',I=0)then Include(Style,fsItalic);if Ini.ReadBool(S,'Underline',False)then Include(Style,fsUnderline);
 end;end;
 finally Ini.Free;end;
end;
procedure StorePreferences(const Value:TConsolePreferences);
var Ini:TIniFile;I:Integer;S,Temp,Backup:string;
begin
 if not ForceDirectories(ExtractFileDir(FileName)) then raise Exception.Create('設定フォルダーを作成できません');
 Temp:=FileName+'.tmp';Ini:=TIniFile.Create(Temp);
 try
 Ini.WriteBool('Console','AutoCommit',Value.AutoCommit);Ini.WriteBool('Console','UpperIdentifiers',Value.UpperIdentifiers);Ini.WriteString('Console','FontName',Value.FontName);Ini.WriteInteger('Console','FontSize',Value.FontSize);
 Ini.WriteString('Editor','FontName',Value.SQLFontName);Ini.WriteInteger('Editor','FontSize',Value.SQLFontSize);
 for I:=0 to SyntaxCount-1 do begin S:='Syntax'+IntToStr(I);with Value.Syntax[I] do begin Ini.WriteInteger(S,'Foreground',Foreground);Ini.WriteInteger(S,'Background',Background);Ini.WriteBool(S,'DefaultForeground',DefaultForeground);Ini.WriteBool(S,'DefaultBackground',DefaultBackground);Ini.WriteBool(S,'Bold',fsBold in Style);Ini.WriteBool(S,'Italic',fsItalic in Style);Ini.WriteBool(S,'Underline',fsUnderline in Style);end;end;Ini.UpdateFile;
 finally Ini.Free;end;
 Backup:=FileName+'.previous';
 if FileExists(Backup)and not DeleteFile(Backup)then raise Exception.Create('設定のバックアップを更新できません');
 if FileExists(FileName)and not RenameFile(FileName,Backup)then raise Exception.Create('設定を更新できません');
 if not RenameFile(Temp,FileName)then begin if FileExists(Backup)then RenameFile(Backup,FileName);raise Exception.Create('設定を保存できません');end;
 if FileExists(Backup)then DeleteFile(Backup);
 Preferences:=Value;Loaded:=True;
end;
function Attribute(H:TSynSQLSyn;Index:Integer):TSynHighlighterAttributes;
begin
 case Index of 0:Result:=H.CommentAttri;1:Result:=H.DataTypeAttri;2:Result:=H.DefaultPackageAttri;3:Result:=H.ExceptionAttri;4:Result:=H.FunctionAttri;5:Result:=H.IdentifierAttri;6:Result:=H.NumberAttri;7:Result:=H.PLSQLAttri;8:Result:=H.KeyAttri;9:Result:=H.SpaceAttri;10:Result:=H.StringAttri;11:Result:=H.SymbolAttri;12:Result:=H.TableNameAttri;else Result:=H.VariableAttri;end;
end;
procedure ApplyEditor(Editor:TSynEdit;const Value:TConsolePreferences);
var H:TSynSQLSyn;I:Integer;A:TSynHighlighterAttributes;
begin
 Editor.Font.Name:=Value.SQLFontName;Editor.Font.Size:=Value.SQLFontSize;Editor.Color:=clWhite;Editor.Font.Color:=clBlack;
 if not (Editor.Highlighter is TSynSQLSyn)then begin H:=TSynSQLSyn.Create(Editor);H.SQLDialect:=sqlFirebird40;Editor.Highlighter:=H;end else H:=TSynSQLSyn(Editor.Highlighter);
 for I:=0 to SyntaxCount-1 do begin A:=Attribute(H,I);with Value.Syntax[I] do begin if DefaultForeground then A.Foreground:=clNone else A.Foreground:=Foreground;if DefaultBackground then A.Background:=clNone else A.Background:=Background;A.Style:=Style;end;end;
 Editor.Invalidate;
end;
procedure ApplyControl(C:TControl);
var I:Integer;
begin
 if C is TSynEdit then begin ApplyEditor(TSynEdit(C),Preferences);Exit;end;
 if not (SameText(C.Font.Name,'Consolas')or SameText(C.Font.Name,'Monospace'))then begin C.Font.Name:=Preferences.FontName;if C.Font.Size<=12 then C.Font.Size:=Preferences.FontSize;end;
 if C is TWinControl then for I:=0 to TWinControl(C).ControlCount-1 do ApplyControl(TWinControl(C).Controls[I]);
end;
procedure ApplyFormPreferences(Form:TCustomForm);
begin LoadPreferences;ApplyControl(Form);end;
procedure RefreshPreferences;
var I:Integer;
begin for I:=0 to Screen.FormCount-1 do ApplyFormPreferences(Screen.Forms[I]);end;
function UppercaseIdentifiers(const SQL:string):string;
var I,Depth:Integer;Quote,QEnd:Char;LineComment:Boolean;C:Char;
begin
 Result:=SQL;I:=1;Depth:=0;Quote:=#0;QEnd:=#0;LineComment:=False;
 while I<=Length(SQL)do begin C:=SQL[I];
 if LineComment then begin if C in [#10,#13]then LineComment:=False;end
 else if Depth>0 then begin if(C='/')and(I<Length(SQL))and(SQL[I+1]='*')then begin Inc(Depth);Inc(I);end else if(C='*')and(I<Length(SQL))and(SQL[I+1]='/')then begin Dec(Depth);Inc(I);end;end
 else if QEnd<>#0 then begin if(C=QEnd)and(I<Length(SQL))and(SQL[I+1]=#39)then begin QEnd:=#0;Inc(I);end;end
 else if Quote<>#0 then begin if C=Quote then begin if(I<Length(SQL))and(SQL[I+1]=Quote)then Inc(I)else Quote:=#0;end;end
 else if(C in ['q','Q'])and(I+2<=Length(SQL))and(SQL[I+1]=#39)then begin
 Result[I]:='Q';QEnd:=SQL[I+2];case QEnd of '[':QEnd:=']';'{':QEnd:='}';'(':QEnd:=')';'<':QEnd:='>';end;Inc(I,2);
 end
 else if C in [#39,'"']then Quote:=C
 else if(C='-')and(I<Length(SQL))and(SQL[I+1]='-')then begin LineComment:=True;Inc(I);end
 else if(C='/')and(I<Length(SQL))and(SQL[I+1]='*')then begin Depth:=1;Inc(I);end
 else if C in ['a'..'z']then Result[I]:=UpCase(C);
 Inc(I);end;
end;
end.
