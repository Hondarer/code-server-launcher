# このツールの設定で起動している code-server を、別のウィンドウから強制終了する。
# 通常は起動したウィンドウで Ctrl+C を押して止める。
# 設定とユーザーデータは残す。

[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "common.ps1")

$config = Get-LauncherConfig
if (Stop-LauncherCodeServer -Config $config) {
    Write-Output "code-server を停止しました。"
}
else {
    Write-Output "起動中の code-server はありません。"
}
