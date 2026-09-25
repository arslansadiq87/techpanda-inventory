$ErrorActionPreference = "Stop"

$appName = "Tech Panda Inventory"
$installRoot = Join-Path $env:LOCALAPPDATA "Programs\Tech Panda Inventory"
$zipPath = Join-Path $PSScriptRoot "TechPandaInventory.zip"
$exePath = Join-Path $installRoot "tech_panda_inventory.exe"

if (Test-Path $installRoot) {
  Remove-Item -LiteralPath $installRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
Expand-Archive -LiteralPath $zipPath -DestinationPath $installRoot -Force

$shell = New-Object -ComObject WScript.Shell

$desktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "$appName.lnk"
$shortcut = $shell.CreateShortcut($desktopShortcut)
$shortcut.TargetPath = $exePath
$shortcut.WorkingDirectory = $installRoot
$shortcut.IconLocation = "$exePath,0"
$shortcut.Save()

$startMenuDir = Join-Path ([Environment]::GetFolderPath("Programs")) $appName
New-Item -ItemType Directory -Path $startMenuDir -Force | Out-Null
$startMenuShortcut = Join-Path $startMenuDir "$appName.lnk"
$shortcut = $shell.CreateShortcut($startMenuShortcut)
$shortcut.TargetPath = $exePath
$shortcut.WorkingDirectory = $installRoot
$shortcut.IconLocation = "$exePath,0"
$shortcut.Save()

Start-Process -FilePath $exePath
