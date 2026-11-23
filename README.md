# FBConsole

Firebird 5のWindows / Linux向けデータベース管理ツールです。Lazarus / Free Pascalで開発しています。

**0.3.79 開発版** — 作成 164SYSTEMS / 開発支援 OpenAI Codex

## ダウンロード

[Releases](https://github.com/trip350z/FBConsole/releases)から取得してください。

| 配布ファイル | 内容 |
| --- | --- |
| FBConsole-0.3.79-win64-SetupBuilder.exe | Windows 64ビット版の日本語セットアップ。本体とガイドを同梱 |
| FBConsole-0.3.79-linux-x86_64-qt6.tar.gz | Linux x86_64 / Qt6版。本体、アイコン、ガイドを同梱 |
| FBConsole_UsersGuide_ja_0.3.79.pdf | 実画面と操作説明を掲載した日本語ガイド |
| SHA256SUMS.txt | 配布ファイルのハッシュ |

## 主な機能

- ローカル・リモートのサーバー登録と接続
- 複数DBへの同時接続と、ツリーによる操作対象の切り替え
- テーブル、ビュー、ルーチン、シーケンス、トリガー、権限などの参照
- 対話型SQL、履歴、クエリビルダー、実行計画、CSV出力
- 複数文SQLとSET TERMの実行
- 主キーを持つ通常テーブルの編集とBLOB内容の参照
- DB作成・削除、バックアップ・リストア、スイープ、検証
- ユーザー管理、サーバーログ、各種プロパティ表示

## Windowsで使う

セットアップEXEを実行し、ウィザードでインストール先を選びます。スタートメニューから起動し、接続設定でFirebird 5の64ビット版 **fbclient.dll** を指定してください。Firebirdクライアントは別途用意します。

セットアップは、ワークスペースのSetupBuilder（Inno Setupを利用）で作成しています。

## Linuxで使う

公開バイナリはUbuntu 26.04 / x86_64 / Qt6でビルドしています。Qt6、LazarusのQt6バインディング **libQt6Pas.so.6** とFirebird 5クライアントが必要です。

```sh
tar -xzf FBConsole-0.3.79-linux-x86_64-qt6.tar.gz
cd FBConsole-0.3.79-linux-x86_64-qt6
./FBConsole-0.3.79
```

接続設定で **libfbclient.so** のパスを指定してください。WSL 2ではWSLgなどのGUI環境が必要です。WSLg上では、明示指定がない場合にX11バックエンドを使用します。

依存関係は `ldd ./FBConsole-0.3.79` で確認できます。別のディストリビューションや古い環境で起動できない場合は、その環境でソースからビルドしてください。

## 接続設定と操作ガイド

初回起動時の接続先は空です。設定は実行ファイルの隣の **config/connections.ini** に保存するため、実行フォルダーに書き込み権限が必要です。パスワードは保存しません。リモートDBのパスはサーバー上のパスを指定します。

[日本語ユーザーズガイド](docs/FBConsole_UsersGuide_ja_0.3.79.pdf)に、画面と操作手順を掲載しています。

## ソースからビルド

Lazarus / Free Pascal、LCL、SynEdit、Printer4Lazarusを使用します。

WindowsではLazarusで **FBConsole.lpi** を開いてビルドします。**build-windows.ps1** のツールパスを環境に合わせて実行する方法もあります。

LinuxではLCLのQt6ユニットとバインディングを用意して、次を実行します。

```sh
sh build-linux.sh qt6
```

生成先は **bin/** です。GTK2向けは `sh build-linux.sh gtk2` でビルドできます。

## 現在の制限

- SQL実行中のキャンセルとバックグラウンド実行は未対応です。
- SQL結果の初期取得は最大1,000行です。全件取得にはデータ量に応じた時間とメモリを使います。
- 配列型の専用表示・編集とLimboトランザクション回復は未対応です。
- 一部のFirebird 5型は文字列で取得し、編集や型としての集計に制限があります。
- メタデータ抽出は全属性と依存順を再現する復元用DDLではありません。
- テーブル画面の編集トランザクションは対話型SQLと独立しています。
- Windowsセットアップを最後まで操作する確認と、各Linuxディストリビューションでの動作確認は未実施です。

## 参考資料

画面と操作の参考にIBConsole / IBOConsoleを使用しています。[参照元と機能対応](IBCONSOLE-REFERENCE.md)も参照してください。
