$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Project = Join-Path $Root "windows\KikuKegel.Windows\KikuKegel.Windows.csproj"
$Dist = Join-Path $Root "dist\windows"

Remove-Item $Dist -Recurse -Force -ErrorAction SilentlyContinue
New-Item $Dist -ItemType Directory | Out-Null

dotnet publish $Project `
  -c Release `
  -r win-x64 `
  --self-contained true `
  -p:PublishSingleFile=true `
  -p:EnableCompressionInSingleFile=true `
  -p:IncludeNativeLibrariesForSelfExtract=true `
  -o $Dist

Write-Host "Windows 版已输出到：$Dist"
Write-Host "主程序：$(Join-Path $Dist 'KikuKegel.Windows.exe')"
