# code-server の配布アーカイブを packages\ へ事前に取得する。
# 取得したアーカイブがあれば、install.ps1 はネットワークに接続せずに導入する。
# -All を指定すると、Linux 版のアーカイブも取得する。

[CmdletBinding()]
param(
    [switch]$All
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "common.ps1")

$config = Get-LauncherConfig

New-Item -ItemType Directory -Force -Path $config.PackagesDir | Out-Null
Save-LauncherVerifiedFile -Url $config.AssetUrl -Destination (Join-Path $config.PackagesDir $config.AssetName) -Sha256 $config.Sha256

if ($All) {
    if ([string]::IsNullOrWhiteSpace($config.LinuxSha256)) {
        throw "version.env に CODE_SERVER_LINUX_AMD64_SHA256 が定義されていません。"
    }
    Save-LauncherVerifiedFile -Url $config.LinuxAssetUrl -Destination (Join-Path $config.PackagesDir $config.LinuxAssetName) -Sha256 $config.LinuxSha256
}

Write-Output "取得が完了しました: $($config.PackagesDir)"
Write-Output "packages\ を含むリポジトリ一式をオフライン環境へ持ち込み、install スクリプトを実行してください。"
