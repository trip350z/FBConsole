param(
  [string]$Python = 'E:\Program Files\Python314\python.exe',
  [string]$WindresDir = 'E:\Program Files\lazarus\fpc\3.2.2\bin\x86_64-win64',
  [string]$Lazbuild = 'E:\Program Files\lazarus\lazbuild.exe'
)

$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
  & $Python 'assets\build_icon.py'
  if ($LASTEXITCODE -ne 0) { throw 'ICOの生成に失敗しました。' }

  $env:PATH = $WindresDir + ';' + $env:PATH
  & (Join-Path $WindresDir 'windres.exe') --preprocessor=cpp --input-format=rc --output-format=res -i FBConsole.rc -o FBConsole.res
  if ($LASTEXITCODE -ne 0) { throw 'Windowsリソースの生成に失敗しました。' }

  & $Lazbuild --build-all FBConsole.lpi
  if ($LASTEXITCODE -ne 0) { throw 'Lazarusのビルドに失敗しました。' }
} finally {
  Pop-Location
}
