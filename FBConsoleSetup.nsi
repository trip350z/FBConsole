Unicode true
!include "MUI2.nsh"

!ifndef VERSION
  !define VERSION "0.3.79"
!endif
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\FBConsole.Setup"

Name "FBConsole ${VERSION}"
Caption "FBConsole セットアップ"
OutFile "output/installer/FBConsole-${VERSION}-win64-setup.exe"
InstallDir "$LOCALAPPDATA\Programs\FBConsole Setup"
InstallDirRegKey HKCU "${UNINSTALL_KEY}" "InstallLocation"
RequestExecutionLevel user
SetCompressor /SOLID lzma
ShowInstDetails show

!define MUI_ICON "assets/FBConsole.ico"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_RIGHT
!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE "FBConsole セットアップ ウィザードへようこそ"
!define MUI_WELCOMEPAGE_TEXT "このウィザードでは、FBConsole ${VERSION} Windows 64ビット版と日本語ユーザーズガイドをインストールします。$\r$\n$\r$\n続けるには［次へ］をクリックしてください。"
!define MUI_DIRECTORYPAGE_TEXT_TOP "FBConsoleをインストールするフォルダーを選んでください。［参照］からドライブやフォルダーを選択できます。"
!define MUI_FINISHPAGE_TITLE "FBConsole セットアップ ウィザードは完了しました"
!define MUI_FINISHPAGE_TEXT "FBConsoleと日本語ユーザーズガイドをインストールしました。スタートメニューの「FBConsole セットアップ版」から開けます。"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "Japanese"

Section "FBConsole"
  SetShellVarContext current
  IfFileExists "$INSTDIR\FBConsole.exe" 0 write_files
  IfFileExists "$INSTDIR\Uninstall-FBConsole.exe" write_files
  MessageBox MB_OK|MB_ICONSTOP "選択先には別のFBConsoleが入っています。別のフォルダーを指定してください。" /SD IDOK
  SetErrorLevel 1
  Abort

write_files:
  ClearErrors
  SetOutPath "$INSTDIR"
  File /oname=FBConsole.exe "bin/FBConsole-${VERSION}.exe"
  File /oname=FBConsole_UsersGuide_ja.pdf "output/pdf/FBConsole_UsersGuide_ja_${VERSION}.pdf"
  WriteUninstaller "$INSTDIR\Uninstall-FBConsole.exe"
  CreateDirectory "$SMPROGRAMS\FBConsole セットアップ版"
  CreateShortCut "$SMPROGRAMS\FBConsole セットアップ版\FBConsole.lnk" "$INSTDIR\FBConsole.exe"
  CreateShortCut "$SMPROGRAMS\FBConsole セットアップ版\日本語ユーザーズガイド.lnk" "$INSTDIR\FBConsole_UsersGuide_ja.pdf"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "FBConsole（セットアップ版）"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "Publisher" "164SYSTEMS"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\Uninstall-FBConsole.exe"'
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1
  IfErrors 0 done
  MessageBox MB_OK|MB_ICONSTOP "インストール先に書き込めませんでした。書き込み可能なフォルダーを選んで再実行してください。" /SD IDOK
  SetErrorLevel 1
  Abort
done:
SectionEnd

Section "Uninstall"
  SetShellVarContext current
  Delete "$SMPROGRAMS\FBConsole セットアップ版\FBConsole.lnk"
  Delete "$SMPROGRAMS\FBConsole セットアップ版\日本語ユーザーズガイド.lnk"
  RMDir "$SMPROGRAMS\FBConsole セットアップ版"
  Delete "$INSTDIR\FBConsole.exe"
  Delete "$INSTDIR\FBConsole_UsersGuide_ja.pdf"
  Delete "$INSTDIR\Uninstall-FBConsole.exe"
  RMDir "$INSTDIR"
  DeleteRegKey HKCU "${UNINSTALL_KEY}"
SectionEnd
