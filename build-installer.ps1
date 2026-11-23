param([string]$Version = '0.3.79')
$ErrorActionPreference = 'Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Use a three-part product version.' }
$exe = Get-Item -LiteralPath (Join-Path $PSScriptRoot "bin/FBConsole-$Version.exe")
$guide = Get-Item -LiteralPath (Join-Path $PSScriptRoot "output/pdf/FBConsole_UsersGuide_ja_$Version.pdf")
$out = Join-Path $PSScriptRoot 'output/installer'
[void][IO.Directory]::CreateDirectory($out)
$temp = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
[void][IO.Directory]::CreateDirectory($temp)
$msi = Join-Path $temp 'package.msi'
Push-Location $temp
try {
  Copy-Item -LiteralPath $exe.FullName -Destination 'FBConsoleFile'
  Copy-Item -LiteralPath $guide.FullName -Destination 'GuideFile'
  @'
.Set CabinetNameTemplate=payload.cab
.Set DiskDirectoryTemplate=.
.Set MaxDiskSize=0
.Set MaxCabinetSize=0
.Set Cabinet=ON
.Set Compress=ON
.Set CompressionType=LZX
FBConsoleFile
GuideFile
'@ | Set-Content -LiteralPath payload.ddf -Encoding ascii
  & makecab.exe /F payload.ddf | Out-Null
  if ($LASTEXITCODE) { throw 'CAB creation failed' }
  $installer = New-Object -ComObject WindowsInstaller.Installer
  $db = $installer.OpenDatabase($msi,3)
  [IO.File]::WriteAllText((Join-Path $temp 'codepage.idt'), "`r`n`r`n932`t_ForceCodepage`r`n", [Text.Encoding]::ASCII)
  $db.Import($temp,'codepage.idt')
  function Sql($statement) {
    $view = $db.OpenView($statement)
    $view.Execute()
    $view.Close()
  }
  function Row($table, [array]$values) {
    $view = $db.OpenView(('SELECT * FROM `{0}`' -f $table))
    $view.Execute()
    $rec = $installer.CreateRecord($values.Count)
    for ($j=0; $j -lt $values.Count; $j++) {
      if ($null -eq $values[$j]) { continue }
      if ($values[$j] -is [string]) { $rec.StringData($j+1)=$values[$j] }
      else { $rec.IntegerData($j+1)=[int]$values[$j] }
    }
    $view.Modify(1,$rec)
    $view.Close()
  }
  Sql 'CREATE TABLE `Property` (`Property` CHAR(72) NOT NULL, `Value` CHAR(0) NOT NULL LOCALIZABLE PRIMARY KEY `Property`)'
  Sql 'CREATE TABLE `Directory` (`Directory` CHAR(72) NOT NULL, `Directory_Parent` CHAR(72), `DefaultDir` CHAR(255) NOT NULL LOCALIZABLE PRIMARY KEY `Directory`)'
  Sql 'CREATE TABLE `Component` (`Component` CHAR(72) NOT NULL, `ComponentId` CHAR(38), `Directory_` CHAR(72) NOT NULL, `Attributes` SHORT NOT NULL, `Condition` CHAR(255), `KeyPath` CHAR(72) PRIMARY KEY `Component`)'
  Sql 'CREATE TABLE `Feature` (`Feature` CHAR(38) NOT NULL, `Feature_Parent` CHAR(38), `Title` CHAR(64) LOCALIZABLE, `Description` CHAR(255) LOCALIZABLE, `Display` SHORT, `Level` SHORT NOT NULL, `Directory_` CHAR(72), `Attributes` SHORT NOT NULL PRIMARY KEY `Feature`)'
  Sql 'CREATE TABLE `FeatureComponents` (`Feature_` CHAR(38) NOT NULL, `Component_` CHAR(72) NOT NULL PRIMARY KEY `Feature_`, `Component_`)'
  Sql 'CREATE TABLE `File` (`File` CHAR(72) NOT NULL, `Component_` CHAR(72) NOT NULL, `FileName` CHAR(255) NOT NULL LOCALIZABLE, `FileSize` LONG NOT NULL, `Version` CHAR(72), `Language` CHAR(20), `Attributes` SHORT, `Sequence` SHORT NOT NULL PRIMARY KEY `File`)'
  Sql 'CREATE TABLE `Media` (`DiskId` SHORT NOT NULL, `LastSequence` LONG NOT NULL, `DiskPrompt` CHAR(64) LOCALIZABLE, `Cabinet` CHAR(255), `VolumeLabel` CHAR(32), `Source` CHAR(72) PRIMARY KEY `DiskId`)'
  Sql 'CREATE TABLE `Shortcut` (`Shortcut` CHAR(72) NOT NULL, `Directory_` CHAR(72) NOT NULL, `Name` CHAR(128) NOT NULL LOCALIZABLE, `Component_` CHAR(72) NOT NULL, `Target` CHAR(72) NOT NULL, `Arguments` CHAR(255), `Description` CHAR(255) LOCALIZABLE, `Hotkey` SHORT, `Icon_` CHAR(72), `IconIndex` SHORT, `ShowCmd` SHORT, `WkDir` CHAR(72) PRIMARY KEY `Shortcut`)'
  Sql 'CREATE TABLE `InstallExecuteSequence` (`Action` CHAR(72) NOT NULL, `Condition` CHAR(255), `Sequence` SHORT PRIMARY KEY `Action`)'
  Row Property @('ProductName','FBConsole')
  Row Property @('ProductVersion',$Version)
  Row Property @('Manufacturer','164SYSTEMS')
  Row Property @('ProductLanguage','1041')
  Row Property @('SecureCustomProperties','INSTALLDIR;PREVIOUSVERSIONS')
  Row Property @('ProductCode','{4B780E91-4194-4442-ACBC-C91206B97344}')
  Row Property @('UpgradeCode','{11D71BD6-AD6C-4415-A2C7-C379D4E2154C}')
  Sql 'CREATE TABLE `Upgrade` (`UpgradeCode` CHAR(38) NOT NULL, `VersionMin` CHAR(20), `VersionMax` CHAR(20), `Language` CHAR(255), `Attributes` LONG NOT NULL, `Remove` CHAR(255), `ActionProperty` CHAR(72) NOT NULL PRIMARY KEY `UpgradeCode`, `VersionMin`, `VersionMax`, `Language`, `Attributes`)'
  Row Upgrade @('{11D71BD6-AD6C-4415-A2C7-C379D4E2154C}',$null,$Version,$null,512,$null,'PREVIOUSVERSIONS')
  Row Directory @('TARGETDIR',$null,'SourceDir')
  Row Directory @('LocalAppDataFolder','TARGETDIR','.')
  Row Directory @('Programs','LocalAppDataFolder','Programs')
  Row Directory @('INSTALLDIR','Programs','FBConsole')
  Row Directory @('ProgramMenuFolder','TARGETDIR','.')
  Sql 'CREATE TABLE `Dialog` (`Dialog` CHAR(72) NOT NULL, `HCentering` SHORT NOT NULL, `VCentering` SHORT NOT NULL, `Width` SHORT NOT NULL, `Height` SHORT NOT NULL, `Attributes` LONG, `Title` CHAR(128) LOCALIZABLE, `Control_First` CHAR(50) NOT NULL, `Control_Default` CHAR(50), `Control_Cancel` CHAR(50) PRIMARY KEY `Dialog`)'
  Sql 'CREATE TABLE `Control` (`Dialog_` CHAR(72) NOT NULL, `Control` CHAR(50) NOT NULL, `Type` CHAR(20) NOT NULL, `X` SHORT NOT NULL, `Y` SHORT NOT NULL, `Width` SHORT NOT NULL, `Height` SHORT NOT NULL, `Attributes` LONG, `Property` CHAR(72), `Text` CHAR(0) LOCALIZABLE, `Control_Next` CHAR(50), `Help` CHAR(50) LOCALIZABLE PRIMARY KEY `Dialog_`, `Control`)'
  Sql 'CREATE TABLE `ControlEvent` (`Dialog_` CHAR(72) NOT NULL, `Control_` CHAR(50) NOT NULL, `Event` CHAR(50) NOT NULL, `Argument` CHAR(255) NOT NULL, `Condition` CHAR(255), `Ordering` SHORT PRIMARY KEY `Dialog_`, `Control_`, `Event`, `Argument`, `Condition`)'
  Sql 'CREATE TABLE `InstallUISequence` (`Action` CHAR(72) NOT NULL, `Condition` CHAR(255), `Sequence` SHORT PRIMARY KEY `Action`)'
  Sql 'CREATE TABLE `EventMapping` (`Dialog_` CHAR(72) NOT NULL, `Control_` CHAR(50) NOT NULL, `Event` CHAR(50) NOT NULL, `Attribute` CHAR(50) NOT NULL PRIMARY KEY `Dialog_`, `Control_`, `Event`)'
  function WizardPage($name,$heading,$body,$primary,$primaryText,$previous) {
    $cancel = if ($name -eq 'Complete') { $primary } else { 'Cancel' }
    Row Dialog @($name,50,50,350,190,3,'FBConsole セットアップ',$primary,$primary,$cancel)
    Row Control @($name,'Heading','Text',12,12,326,18,3,$null,$heading,$null,$null)
    Row Control @($name,'Body','Text',12,38,326,98,3,$null,$body,$null,$null)
    $next = if ($name -eq 'Complete') { $primary } else { 'Cancel' }
    Row Control @($name,$primary,'PushButton',163,158,85,21,3,$null,$primaryText,$next,$null)
    if ($name -ne 'Complete') {
      $cancelNext = if ($previous) { 'Back' } else { $primary }
      Row Control @($name,'Cancel','PushButton',254,158,84,21,3,$null,'キャンセル',$cancelNext,$null)
      Row ControlEvent @($name,'Cancel','EndDialog','Exit','1',1)
    }
    if ($previous) {
      Row Control @($name,'Back','PushButton',72,158,85,21,3,$null,'戻る',$primary,$null)
      Row ControlEvent @($name,'Back','NewDialog',$previous,'1',1)
    }
  }
  WizardPage 'Welcome' 'FBConsole セットアップへようこそ' "FBConsole $Version（Windows 64ビット版）と日本語ユーザーズガイドをインストールします。次へをクリックしてください。" 'Next' '次へ' $null
  Row ControlEvent @('Welcome','Next','NewDialog','Destination','1',1)
  Row Dialog @('Destination',50,50,350,224,3,'FBConsole セットアップ','Drives','Install','Cancel')
  Row Control @('Destination','Label','Text',12,12,326,18,3,$null,'ドライブを選び、フォルダーをダブルクリックして開きます。',$null,$null)
  Row Control @('Destination','Drives','DirectoryCombo',12,34,151,80,655363,'INSTALLDIR',$null,'Up',$null)
  Row Control @('Destination','Up','PushButton',169,34,72,18,3,$null,'上の階層','NewFolder',$null)
  Row Control @('Destination','NewFolder','PushButton',247,34,91,18,3,$null,'新しいフォルダー','Folders',$null)
  Row Control @('Destination','Folders','DirectoryList',12,59,326,96,3,'INSTALLDIR',$null,'Path',$null)
  Row Control @('Destination','Path','PathEdit',12,162,326,18,3,'INSTALLDIR',$null,'Install',$null)
  Row Control @('Destination','Install','PushButton',163,193,85,21,3,$null,'次へ','Cancel',$null)
  Row Control @('Destination','Cancel','PushButton',254,193,84,21,3,$null,'キャンセル','Back',$null)
  Row Control @('Destination','Back','PushButton',72,193,85,21,3,$null,'戻る','Drives',$null)
  Row ControlEvent @('Destination','Up','DirectoryListUp','0','1',1)
  Row ControlEvent @('Destination','NewFolder','DirectoryListNew','0','1',1)
  Row ControlEvent @('Destination','Install','SetTargetPath','INSTALLDIR','1',1)
  Row ControlEvent @('Destination','Install','NewDialog','Ready','1',2)
  Row ControlEvent @('Destination','Cancel','EndDialog','Exit','1',1)
  Row ControlEvent @('Destination','Back','NewDialog','Welcome','1',1)
  WizardPage 'Ready' 'インストールの準備ができました' "インストール先： [INSTALLDIR]`r`n`r`nFBConsole本体と日本語ユーザーズガイドを配置し、スタートメニューに追加します。" 'Install' 'インストール' 'Destination'
  Row ControlEvent @('Ready','Install','EndDialog','Return','1',1)
  Row Dialog @('Progress',50,50,350,115,1,'FBConsole セットアップ','Bar',$null,$null)
  Row Control @('Progress','Label','Text',12,14,326,20,3,$null,'FBConsoleをインストールしています。',$null,$null)
  Row Control @('Progress','Bar','ProgressBar',12,53,326,14,65537,$null,$null,$null,$null)
  Row EventMapping @('Progress','Bar','SetProgress','Progress')
  WizardPage 'Complete' 'インストールが完了しました' 'スタートメニューからFBConsoleと日本語ユーザーズガイドを開けます。' 'Finish' '完了' $null
  Row ControlEvent @('Complete','Finish','EndDialog','Return','1',1)
  Row InstallUISequence @('CostInitialize',$null,100)
  Row InstallUISequence @('FindRelatedProducts',$null,50)
  Row InstallExecuteSequence @('FindRelatedProducts',$null,50)
  Row InstallExecuteSequence @('RemoveExistingProducts','PREVIOUSVERSIONS',550)
  Row InstallUISequence @('FileCost',$null,200)
  Row InstallUISequence @('CostFinalize',$null,300)
  Row InstallUISequence @('Welcome','NOT Installed',400)
  Row InstallUISequence @('Progress','NOT Installed',450)
  Row InstallUISequence @('ExecuteAction',$null,500)
  Row InstallUISequence @('Complete','NOT Installed',-1)
  Row Component @('App','{B90566C3-1E35-44B8-BEBB-118A5CFEF52C}','INSTALLDIR',256,$null,'FBConsoleFile')
  Row Component @('Guide','{597771D9-AE25-4AC9-BA05-7DA70B2D7D5B}','INSTALLDIR',0,$null,'GuideFile')
  Row Feature @('Main',$null,'FBConsole',$null,1,1,'INSTALLDIR',0)
  Row FeatureComponents @('Main','App')
  Row FeatureComponents @('Main','Guide')
  Row File @('FBConsoleFile','App','FBConsole.exe',$exe.Length,$null,$null,16384,1)
  Row File @('GuideFile','Guide','FBGUIDE.PDF|FBConsole_UsersGuide_ja.pdf',$guide.Length,$null,$null,16384,2)
  Row Media @(1,2,$null,'#payload.cab',$null,$null)
  Row Shortcut @('StartMenu','ProgramMenuFolder','FBConsole','App','[#FBConsoleFile]',$null,'Firebird 5 console',$null,$null,$null,1,'INSTALLDIR')
  Row Shortcut @('GuideMenu','ProgramMenuFolder','FBConsole ユーザーズガイド','Guide','[#GuideFile]',$null,'日本語ユーザーズガイド',$null,$null,$null,1,'INSTALLDIR')
  $n=100
  foreach ($action in ('CostInitialize','FileCost','CostFinalize','InstallValidate','InstallInitialize','ProcessComponents','UnpublishFeatures','RemoveShortcuts','RemoveFiles','InstallFiles','CreateShortcuts','RegisterUser','RegisterProduct','PublishFeatures','PublishProduct','InstallFinalize')) {
    Row InstallExecuteSequence @($action,$null,$n); $n+=100
  }
  $view=$db.OpenView('INSERT INTO `_Streams` (`Name`,`Data`) VALUES (?, ?)')
  $record=$installer.CreateRecord(2)
  $record.StringData(1)='payload.cab'
  $record.SetStream(2,(Join-Path $temp 'payload.cab'))
  $view.Execute($record); $view.Close()
  $summary=$db.SummaryInformation(10)
  $summary.Property(2)='FBConsole Installer'
  $summary.Property(7)='x64;1041'
  $summary.Property(9)=[guid]::NewGuid().ToString('B').ToUpperInvariant()
  $summary.Property(14)=200
  $summary.Property(15)=2
  $summary.Persist()
  $db.Commit()
  foreach ($comObject in @($summary,$view,$record,$db)) {
    [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($comObject)
  }
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
  Copy-Item -LiteralPath $msi -Destination (Join-Path $out "FBConsole-$Version-win64-setup.msi") -Force
} finally {
  Pop-Location
}
