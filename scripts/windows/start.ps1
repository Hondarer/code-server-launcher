# code-server をこの PowerShell のフォアグラウンドで起動する。
# 終了は Ctrl+C、または別のウィンドウからの stop.ps1 で行う。

[CmdletBinding()]
param(
    [switch]$Restart
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "common.ps1")

Assert-WindowsAmd64
$config = Get-LauncherConfig

if (-not (Test-CodeServerInstalled -Config $config)) {
    throw "code-server が未導入です。先に scripts\windows\install.ps1 を実行してください。"
}
if (-not (Test-Path -LiteralPath $config.Workspace -PathType Container)) {
    throw "ワークスペースが存在しません: $($config.Workspace)"
}

foreach ($dir in @($config.UserDataDir, $config.ExtensionsDir, $config.ConfigDir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

$created = Update-LauncherCodeServerConfig -Config $config -Mode Ensure
if ($created) {
    Write-Output "設定ファイルを作成しました: $($config.ConfigFile)"
    Write-Output "ログイン パスワード: $created"
}

$running = @(Get-LauncherCodeServerProcessIds -Config $config)
if ($Restart -and $running.Count -gt 0) {
    Stop-LauncherCodeServer -Config $config | Out-Null
    $running = @()
}
if (-not $Restart -and $running.Count -gt 0) {
    Write-Output "すでに起動しています。終了する場合はこのウィンドウで Ctrl+C を押すか、別のウィンドウから stop.ps1 を実行してください。"
    Write-LauncherEndpoints -Config $config
    return
}
if (Test-LauncherPortListening -Port $config.Port) {
    throw "ポート $($config.Port) は別のプロセスが使用しています。"
}

$argumentList = Get-CodeServerArguments -Config $config
# VS Code の端末環境では、これらの環境変数が存在すると code-server が待受を開始せずに VS Code へ処理を戻す。
Remove-Item Env:VSCODE_IPC_HOOK_CLI -ErrorAction SilentlyContinue
Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue
Write-Output "このウィンドウで code-server を起動します。終了する場合は Ctrl+C を押してください。"
Write-LauncherEndpoints -Config $config
Write-Output "パスワードの確認: Select-String -Path '$($config.ConfigFile)' -Pattern '^password:'"
Push-Location $config.Workspace
try {
    & $config.NodeExe @argumentList
}
finally {
    Pop-Location
}
