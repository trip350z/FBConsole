unit BlobViewer;

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses Classes, DB, Forms;

procedure OpenBlobViewer(AOwner: TComponent; AField: TField);

implementation

uses SysUtils, Controls, StdCtrls, Dialogs;

type
  TBlobViewerForm = class(TForm)
  private
    FField: TField;
    FMemo: TMemo;
    procedure SaveClick(Sender: TObject);
  public
    constructor CreateViewer(AOwner: TComponent; AField: TField);
  end;

constructor TBlobViewerForm.CreateViewer(AOwner: TComponent; AField: TField);
var L: TLabel; B: TButton;
begin
  inherited CreateNew(AOwner);
  FField:=AField;
  Caption:='BLOBビューア - '+AField.FieldName;
  SetBounds(100,100,760,520);
  Position:=poOwnerFormCenter;
  L:=TLabel.Create(Self);L.Parent:=Self;L.Align:=alTop;
  L.Caption:=Format('列: %s    サイズ: %d バイト',[AField.FieldName,AField.DataSize]);
  FMemo:=TMemo.Create(Self);FMemo.Parent:=Self;FMemo.Align:=alClient;
  FMemo.ReadOnly:=True;FMemo.ScrollBars:=ssBoth;FMemo.WordWrap:=False;
  FMemo.Font.Name:='Consolas';
  try FMemo.Lines.Text:=AField.AsString
  except on E:Exception do FMemo.Lines.Text:='テキストとして表示できません: '+E.Message;end;
  B:=TButton.Create(Self);B.Parent:=Self;B.Align:=alBottom;B.Height:=34;
  B.Caption:='ファイルへ保存…';B.OnClick:=@SaveClick;
end;

procedure TBlobViewerForm.SaveClick(Sender:TObject);
var D:TSaveDialog; S:TMemoryStream;
begin
  D:=TSaveDialog.Create(Self);S:=TMemoryStream.Create;
  try
    D.Title:='BLOBをファイルへ保存';
    D.FileName:=FField.FieldName+'.bin';
    if not D.Execute then Exit;
    TBlobField(FField).SaveToStream(S);
    S.SaveToFile(D.FileName);
  finally S.Free;D.Free;end;
end;

procedure OpenBlobViewer(AOwner:TComponent;AField:TField);
var D:TBlobViewerForm;
begin
  if not Assigned(AField) or AField.IsNull then Exit;
  if not (AField is TBlobField) then Exit;
  D:=TBlobViewerForm.CreateViewer(AOwner,AField);
  try D.ShowModal;finally D.Free;end;
end;

end.
