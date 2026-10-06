# code-server をこの PowerShell のフォアグラウンドで起動する。
# 終了は Ctrl+C、または別のウィンドウからの stop.ps1。

[CmdletBinding()]
param(
    [switch]$Restart
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "common.ps1")

Assert-WindowsAmd64
$config = Get-StudyConfig

if (-not (Test-CodeServerInstalled -Config $config)) {
    throw "code-server が未導入です。先に scripts\windows\install.ps1 を実行してください。"
}
if (-not (Test-Path -LiteralPath $config.Workspace)) {
    throw "ワークスペースがありません: $($config.Workspace)"
}

foreach ($dir in @($config.UserDataDir, $config.ExtensionsDir, $config.ConfigDir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

$created = Update-StudyCodeServerConfig -Config $config -Mode Ensure
if ($created) {
    Write-Output "設定ファイルを作成しました: $($config.ConfigFile)"
    Write-Output "ログインパスワード: $created"
}

$running = @(Get-StudyCodeServerProcessIds -Config $config)
if ($Restart -and $running.Count -gt 0) {
    Stop-StudyCodeServer -Config $config | Out-Null
    $running = @()
}
if (-not $Restart -and $running.Count -gt 0) {
    Write-Output "既に起動しています。終了はそのウィンドウで Ctrl+C か、別のウィンドウから stop.ps1 です。"
    Write-StudyEndpoints -Config $config
    return
}
if (Test-StudyPortListening -Port $config.Port) {
    throw "ポート $($config.Port) は別のプロセスが使用しています。"
}

$argumentList = Get-CodeServerArguments -Config $config
# VS Code の端末では、この変数があると code-server が待受を始めずに VS Code へ戻る。
Remove-Item Env:VSCODE_IPC_HOOK_CLI -ErrorAction SilentlyContinue
Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue
Write-Output "このウィンドウで code-server を起動します。終了は Ctrl+C です。"
Write-StudyEndpoints -Config $config
Write-Output "パスワードの確認: Select-String -Path '$($config.ConfigFile)' -Pattern '^password:'"
Push-Location $config.Workspace
try {
    & $config.NodeExe @argumentList
}
finally {
    Pop-Location
}
