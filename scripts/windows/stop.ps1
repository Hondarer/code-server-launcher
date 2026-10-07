# 本ツールの設定で起動している code-server を、別のウィンドウから強制終了する。
# 通常の停止操作には、起動したウィンドウでの Ctrl+C を推奨する。
# 設定とユーザー データは保持する。

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
    Write-Output "起動中の code-server は存在しません。"
}
