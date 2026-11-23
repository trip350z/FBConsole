unit AboutDialog;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses Classes;

procedure ShowAboutDialog(AOwner: TComponent);

implementation

uses Forms, Controls, Graphics, ExtCtrls, StdCtrls, AppTheme;

{$R assets/AboutLogo.res}

procedure ShowAboutDialog(AOwner: TComponent);
var
  D: TForm;
  Banner, Footer: TPanel;
  Logo: TImage;
  LogoStream: TResourceStream;
  TitleLabel, SubtitleLabel, VersionLabel, ProductLabel, AuthorLabel,
    CodexLabel, RuntimeLabel, NoteLabel: TLabel;
  Button: TButton;
begin
  D := TForm.CreateNew(AOwner);
  try
    D.Caption := 'FBConsoleについて';
    D.BorderStyle := bsDialog;
    D.BorderIcons := [biSystemMenu];
    D.Position := poOwnerFormCenter;
    D.ClientWidth := 500;
    D.ClientHeight := 400;
    D.Constraints.MinWidth := 500;
    D.Constraints.MaxWidth := 500;
    D.Constraints.MinHeight := 400;
    D.Constraints.MaxHeight := 400;
    D.Icon.Assign(Application.Icon);

    Banner := TPanel.Create(D);
    Banner.Parent := D;
    Banner.SetBounds(0, 0, 500, 128);
    Banner.Align := alTop;
    Banner.BevelOuter := bvNone;

    Logo := TImage.Create(D);
    Logo.Parent := Banner;
    Logo.SetBounds(16, 14, 98, 98);
    Logo.Stretch := True;
    Logo.Proportional := True;
    Logo.Center := True;
    LogoStream := TResourceStream.Create(HInstance, 'ABOUT_LOGO', PChar(10));
    try
      Logo.Picture.PNG.LoadFromStream(LogoStream);
    finally
      LogoStream.Free;
    end;

    TitleLabel := TLabel.Create(D);
    TitleLabel.Parent := Banner;
    TitleLabel.SetBounds(132, 30, 340, 42);
    TitleLabel.Caption := 'FBConsole';
    TitleLabel.Font.Size := 25;
    TitleLabel.Font.Style := [fsBold];
    TitleLabel.Font.Color := RGBToColor(29, 91, 164);

    SubtitleLabel := TLabel.Create(D);
    SubtitleLabel.Parent := Banner;
    SubtitleLabel.SetBounds(136, 77, 340, 26);
    SubtitleLabel.Caption := 'Firebird 5 データベース管理ツール';

    VersionLabel := TLabel.Create(D);
    VersionLabel.Parent := D;
    VersionLabel.SetBounds(18, 146, 460, 24);
    VersionLabel.Caption := 'バージョン: 0.3.79';
    VersionLabel.Font.Style := [fsBold];

    ProductLabel := TLabel.Create(D);
    ProductLabel.Parent := D;
    ProductLabel.SetBounds(18, 177, 460, 22);
    ProductLabel.Caption := 'Firebird 5 向けのサーバー／データベース管理コンソール';

    AuthorLabel := TLabel.Create(D);
    AuthorLabel.Parent := D;
    AuthorLabel.SetBounds(18, 216, 460, 22);
    AuthorLabel.Caption := '作成者: 164SYSTEMS';

    CodexLabel := TLabel.Create(D);
    CodexLabel.Parent := D;
    CodexLabel.SetBounds(18, 245, 460, 22);
    CodexLabel.Caption := '開発支援: OpenAI Codex を使用';

    RuntimeLabel := TLabel.Create(D);
    RuntimeLabel.Parent := D;
    RuntimeLabel.SetBounds(18, 274, 460, 22);
    RuntimeLabel.Caption := '開発環境: Lazarus / Free Pascal';

    NoteLabel := TLabel.Create(D);
    NoteLabel.Parent := D;
    NoteLabel.SetBounds(18, 309, 460, 22);
    NoteLabel.Caption := 'IBConsole オープンソース版を参考に開発しています。';

    Footer := TPanel.Create(D);
    Footer.Parent := D;
    Footer.Align := alBottom;
    Footer.Height := 54;
    Footer.BevelOuter := bvNone;

    Button := TButton.Create(D);
    Button.Parent := Footer;
    Button.Caption := 'OK';
    Button.ModalResult := mrOk;
    Button.Default := True;
    Button.SetBounds(398, 11, 86, 30);

    ApplyModernTheme(D);
    TitleLabel.Font.Size := 25;
    TitleLabel.Font.Style := [fsBold];
    TitleLabel.Font.Color := RGBToColor(29, 91, 164);
    VersionLabel.Font.Style := [fsBold];
    Button.SetBounds(398, 11, 86, 30);
    D.ShowModal;
  finally
    D.Free;
  end;
end;

end.
