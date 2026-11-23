unit MetadataWindow;

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Dialogs, Clipbrd;

procedure ShowMetadataWindow(AOwner: TComponent; const ATitle: string;
  AText: TStrings);

implementation

uses AppTheme;

type
  TMetadataForm = class(TForm)
  private
    FMemo: TMemo;
    procedure SaveClick(Sender: TObject);
    procedure CopyClick(Sender: TObject);
    procedure CloseClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
  public
    constructor CreateViewer(AOwner: TComponent; const ATitle: string;
      AText: TStrings);
  end;

constructor TMetadataForm.CreateViewer(AOwner: TComponent;
  const ATitle: string; AText: TStrings);
var Bar: TPanel; SaveButton, CopyButton, CloseButton: TButton;
begin
  inherited CreateNew(AOwner);
  Caption := ATitle;
  SetBounds(140, 100, 1000, 720);
  Constraints.MinWidth := 700;
  Constraints.MinHeight := 480;
  Position := poOwnerFormCenter;
  OnClose := @FormClose;
  Bar := TPanel.Create(Self);
  Bar.Parent := Self; Bar.Align := alTop; Bar.Height := 42;
  SaveButton := TButton.Create(Self);
  SaveButton.Parent := Bar; SaveButton.SetBounds(8, 7, 110, 28);
  SaveButton.Caption := 'SQL保存…'; SaveButton.OnClick := @SaveClick;
  CopyButton := TButton.Create(Self);
  CopyButton.Parent := Bar; CopyButton.SetBounds(126, 7, 110, 28);
  CopyButton.Caption := 'すべてコピー'; CopyButton.OnClick := @CopyClick;
  CloseButton := TButton.Create(Self);
  CloseButton.Parent := Bar; CloseButton.SetBounds(244, 7, 90, 28);
  CloseButton.Caption := '閉じる'; CloseButton.OnClick := @CloseClick;
  FMemo := TMemo.Create(Self);
  FMemo.Parent := Self; FMemo.Align := alClient;
  FMemo.ReadOnly := True; FMemo.ScrollBars := ssBoth; FMemo.WordWrap := False;
  FMemo.Font.Name := 'Consolas';
  FMemo.Lines.Assign(AText);
  ApplyModernTheme(Self);
end;

procedure TMetadataForm.SaveClick(Sender: TObject);
var D: TSaveDialog;
begin
  D := TSaveDialog.Create(Self);
  try
    D.Title := 'メタデータを保存';
    D.Filter := 'SQLスクリプト (*.sql)|*.sql|テキスト (*.txt)|*.txt';
    D.DefaultExt := 'sql';
    D.Options := D.Options + [ofOverwritePrompt];
    if D.Execute then FMemo.Lines.SaveToFile(D.FileName);
  finally
    D.Free;
  end;
end;

procedure TMetadataForm.CopyClick(Sender: TObject);
begin
  Clipboard.AsText := FMemo.Text;
end;

procedure TMetadataForm.CloseClick(Sender: TObject);
begin
  Close;
end;

procedure TMetadataForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  CloseAction := caFree;
end;

procedure ShowMetadataWindow(AOwner: TComponent; const ATitle: string;
  AText: TStrings);
begin
  with TMetadataForm.CreateViewer(AOwner, ATitle, AText) do begin
    Show;
    BringToFront;
  end;
end;

end.
