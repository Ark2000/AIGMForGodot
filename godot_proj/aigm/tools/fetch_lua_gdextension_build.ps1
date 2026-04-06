# Downloads lua-gdextension release and extracts prebuilt binaries into addons/lua-gdextension/build/
# Run from repo root or any cwd; script resolves paths relative to godot_proj/aigm/.
$ErrorActionPreference = "Stop"
$version = "0.8.0"
$aigmRoot = Split-Path $PSScriptRoot
$addonBuild = Join-Path $aigmRoot "addons\lua-gdextension\build"
$zipUrl = "https://github.com/gilzoide/lua-gdextension/releases/download/$version/lua-gdextension.zip"
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("lua-gdextension-" + [Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$zipPath = Join-Path $tmp "lua-gdextension.zip"
Write-Host "Downloading $zipUrl"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
Expand-Archive -Path $zipPath -DestinationPath $tmp -Force
$srcBuild = Join-Path $tmp "addons\lua-gdextension\build"
if (-not (Test-Path $srcBuild)) {
	throw "Unexpected zip layout: missing addons/lua-gdextension/build"
}
if (Test-Path $addonBuild) {
	Remove-Item -Recurse -Force $addonBuild
}
New-Item -ItemType Directory -Force -Path (Split-Path $addonBuild) | Out-Null
Copy-Item -Recurse -Force $srcBuild $addonBuild
Remove-Item -Recurse -Force $tmp
Write-Host "OK: $addonBuild"
