# deploy_to_linux.ps1
# Run from PowerShell on Windows: .\deploy_to_linux.ps1
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir
python deploy_remote.py

