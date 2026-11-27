program PreferencesTest;
{$mode objfpc}{$H+}{$codepage utf8}
uses Interfaces,Forms,SysUtils,Graphics,ConsolePreferences,SynEdit,SynHighlighterSQL;
var Value:TConsolePreferences;E:TSynEdit;
procedure Check(OK:Boolean;const Message:string);
begin if not OK then raise Exception.Create(Message);end;
begin
 Application.Initialize;LoadPreferences;
 if ParamStr(1)='write' then begin Value:=Preferences;Value.AutoCommit:=True;Value.UpperIdentifiers:=True;Value.SQLFontName:='Courier New';Value.SQLFontSize:=12;Value.Syntax[0].Foreground:=clRed;Value.Syntax[0].DefaultForeground:=False;Value.Syntax[0].Style:=[fsBold,fsUnderline];StorePreferences(Value);StorePreferences(Value);end
 else begin Check(Preferences.AutoCommit,'AutoCommit not restored');Check(Preferences.UpperIdentifiers,'Uppercase not restored');Check(Preferences.SQLFontSize=12,'SQL font size not restored');Check(Preferences.Syntax[0].Foreground=clRed,'Color not restored');Check(Preferences.Syntax[0].Style=[fsBold,fsUnderline],'Style not restored');end;
 Check(UppercaseIdentifiers('select "Mixed", ''lower'' /* lower */ from employee -- lower')='SELECT "Mixed", ''lower'' /* lower */ FROM EMPLOYEE -- lower','Quoted/comment text changed');
 Check(UppercaseIdentifiers('select q''{lower ''quoted''}'' from t /* outer /* inner */ lower */')='SELECT Q''{lower ''quoted''}'' FROM T /* outer /* inner */ lower */','Alternative string or nested comment changed');
 E:=TSynEdit.Create(nil);try ApplyEditor(E,Preferences);Check(E.Highlighter is TSynSQLSyn,'Highlighter missing');Check(TSynSQLSyn(E.Highlighter).CommentAttri.Foreground=clRed,'Editor color not applied');Check(E.Font.Size=12,'Font not applied');finally E.Free;end;
 WriteLn('PASS: options persistence, repeated save, quoted identifiers/comments and editor attributes');
end.
