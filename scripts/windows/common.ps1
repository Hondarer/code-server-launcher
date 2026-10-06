# study-code-server の Windows スクリプト共通処理。
# 各スクリプトからドットソースする。直接の起動は想定しない。

Set-StrictMode -Version 2.0

function Get-StudyConfig {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
    $versionFile = Join-Path $repoRoot "version.env"
    if (-not (Test-Path -LiteralPath $versionFile)) {
        throw "version.env が見つかりません: $versionFile"
    }

    $values = @{}
    foreach ($raw in Get-Content -LiteralPath $versionFile -Encoding UTF8) {
        $line = $raw.Trim()
        if ($line.Length -eq 0 -or $line.StartsWith("#")) {
            continue
        }
        $idx = $line.IndexOf("=")
        if ($idx -lt 1) {
            continue
        }
        $values[$line.Substring(0, $idx)] = $line.Substring($idx + 1)
    }

    foreach ($name in @(
            "CODE_SERVER_VERSION",
            "CODE_SERVER_PORT",
            "CODE_SERVER_BIND_HOST",
            "CODE_SERVER_WINDOWS_AMD64_SHA256"
        )) {
        if (-not $values.Contains($name) -or [string]::IsNullOrWhiteSpace($values[$name])) {
            throw "version.env に $name がありません。"
        }
    }

    if ($env:CODE_SERVER_PORT) {
        $values["CODE_SERVER_PORT"] = $env:CODE_SERVER_PORT
    }
    if ($env:CODE_SERVER_BIND_HOST) {
        $values["CODE_SERVER_BIND_HOST"] = $env:CODE_SERVER_BIND_HOST
    }

    $workspace = $repoRoot
    if ($env:CODE_SERVER_WORKSPACE) {
        $workspace = $env:CODE_SERVER_WORKSPACE
    }

    $version = $values["CODE_SERVER_VERSION"]
    $port = $values["CODE_SERVER_PORT"]
    $bindHost = $values["CODE_SERVER_BIND_HOST"]
    $base = Join-Path $env:LOCALAPPDATA "study-code-server"
    $installDir = Join-Path $base ("code-server-" + $version)
    $stateDir = Join-Path $base "state"
    $configDir = Join-Path $env:USERPROFILE ".config\study-code-server"

    return [pscustomobject]@{
        RepoRoot       = $repoRoot
        Version        = $version
        Port           = [int]$port
        BindHost       = $bindHost
        BindAddr       = "${bindHost}:${port}"
        Workspace      = $workspace
        AssetName      = "code-server-$version-windows-amd64.tar.gz"
        AssetUrl       = "https://github.com/coder/code-server/releases/download/v$version/code-server-$version-windows-amd64.tar.gz"
        Sha256         = $values["CODE_SERVER_WINDOWS_AMD64_SHA256"].ToLowerInvariant()
        BaseDir        = $base
        InstallDir     = $installDir
        NodeExe        = Join-Path $installDir "lib\node.exe"
        AppDir         = $installDir
        ConfigDir      = $configDir
        ConfigFile     = Join-Path $configDir "config.yaml"
        UserDataDir    = Join-Path $base "user-data"
        ExtensionsDir  = Join-Path $base "extensions"
        StateDir       = $stateDir
        CacheDir       = Join-Path $base "cache"
        TaskName       = "study-code-server"
    }
}

function Assert-WindowsAmd64 {
    $arch = $env:PROCESSOR_ARCHITECTURE
    if ($env:PROCESSOR_ARCHITEW6432) {
        $arch = $env:PROCESSOR_ARCHITEW6432
    }
    if ($arch -ne "AMD64") {
        throw "このサンプルが検証している Windows アーキテクチャは amd64 です (現在: $arch)。"
    }
}

function New-StudyPassword {
    $bytes = New-Object byte[] 24
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $rng.GetBytes($bytes)
    }
    finally {
        $rng.Dispose()
    }
    $builder = New-Object System.Text.StringBuilder
    foreach ($byte in $bytes) {
        [void]$builder.Append($byte.ToString("x2"))
    }
    return $builder.ToString()
}

function Protect-StudyConfigFile {
    param([string]$Path)
    $acl = New-Object System.Security.AccessControl.FileSecurity
    $acl.SetAccessRuleProtection($true, $false)
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $identity,
        "FullControl",
        "Allow"
    )
    $acl.AddAccessRule($rule)
    [System.IO.File]::SetAccessControl($Path, $acl)
}

function Write-StudyTextFile {
    param(
        [string]$Path,
        [string]$Content
    )
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Update-StudyCodeServerConfig {
    param(
        $Config,
        [ValidateSet("Ensure", "Reset")]
        [string]$Mode
    )

    New-Item -ItemType Directory -Force -Path $Config.ConfigDir | Out-Null
    $exists = Test-Path -LiteralPath $Config.ConfigFile
    $password = $null

    if (-not $exists) {
        $password = New-StudyPassword
        $content = @(
            "bind-addr: $($Config.BindAddr)"
            "auth: password"
            "password: $password"
            "cert: false"
            "disable-telemetry: true"
            "disable-update-check: true"
        ) -join "`r`n"
        Write-StudyTextFile -Path $Config.ConfigFile -Content ($content + "`r`n")
        Protect-StudyConfigFile -Path $Config.ConfigFile
        return $password
    }

    $lines = @(Get-Content -LiteralPath $Config.ConfigFile -Encoding UTF8)
    $out = New-Object System.Collections.Generic.List[string]
    $sawBind = $false

    if ($Mode -eq "Reset") {
        $password = New-StudyPassword
        $rendered = @{
            "bind-addr"             = "bind-addr: $($Config.BindAddr)"
            "auth"                  = "auth: password"
            "password"              = "password: $password"
            "cert"                  = "cert: false"
            "disable-telemetry"     = "disable-telemetry: true"
            "disable-update-check"  = "disable-update-check: true"
        }
        $seen = @{}
        foreach ($line in $lines) {
            $key = ""
            if ($line -match "^([^:#][^:]*):") {
                $key = $Matches[1].Trim()
            }
            if ($key -eq "hashed-password") {
                continue
            }
            if ($rendered.ContainsKey($key)) {
                $out.Add($rendered[$key])
                $seen[$key] = $true
            }
            else {
                $out.Add($line)
            }
        }
        foreach ($key in @(
                "bind-addr",
                "auth",
                "password",
                "cert",
                "disable-telemetry",
                "disable-update-check"
            )) {
            if (-not $seen.ContainsKey($key)) {
                $out.Add($rendered[$key])
            }
        }
    }
    else {
        foreach ($line in $lines) {
            if ($line -match "^bind-addr:") {
                $out.Add("bind-addr: $($Config.BindAddr)")
                $sawBind = $true
            }
            else {
                $out.Add($line)
            }
        }
        if (-not $sawBind) {
            $out.Insert(0, "bind-addr: $($Config.BindAddr)")
        }
    }

    $text = ($out -join "`r`n") + "`r`n"
    Write-StudyTextFile -Path $Config.ConfigFile -Content $text
    Protect-StudyConfigFile -Path $Config.ConfigFile
    return $password
}

function Get-CodeServerArguments {
    param($Config)
    return @(
        $Config.AppDir,
        "--config", $Config.ConfigFile,
        "--bind-addr", $Config.BindAddr,
        "--auth", "password",
        "--user-data-dir", $Config.UserDataDir,
        "--extensions-dir", $Config.ExtensionsDir,
        $Config.Workspace
    )
}

function Test-CodeServerInstalled {
    param($Config)
    return (Test-Path -LiteralPath $Config.NodeExe) -and (Test-Path -LiteralPath (Join-Path $Config.AppDir "package.json"))
}

function Get-StudyCodeServerProcessIds {
    param($Config)
    $marker = [string]$Config.ConfigFile
    $found = @()
    $processes = @(Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" -ErrorAction SilentlyContinue)
    if ($processes.Count -eq 1 -and $null -eq $processes[0]) {
        return @()
    }
    foreach ($process in $processes) {
        if ($null -eq $process) {
            continue
        }
        $command = [string]$process.CommandLine
        if ($command -and $command.Contains($marker)) {
            $found += [int]$process.ProcessId
        }
    }
    return @($found)
}

function Test-StudyPortListening {
    param([int]$Port)
    $pattern = "[:.]$Port\s"
    $lines = netstat.exe -ano | Select-String -Pattern "LISTENING" | Select-String -Pattern $pattern
    return $null -ne $lines
}

function Get-StudyHttpStatus {
    param([int]$Port)
    try {
        $request = [System.Net.HttpWebRequest]::Create("http://127.0.0.1:$Port/")
        $request.Method = "GET"
        $request.AllowAutoRedirect = $false
        $request.Timeout = 3000
        $response = $request.GetResponse()
        try {
            return [int]$response.StatusCode
        }
        finally {
            $response.Close()
        }
    }
    catch [System.Net.WebException] {
        $webResponse = $_.Exception.Response
        if ($webResponse -ne $null) {
            try {
                return [int]$webResponse.StatusCode
            }
            finally {
                $webResponse.Close()
            }
        }
        return 0
    }
    catch {
        return 0
    }
}

function Stop-StudyCodeServer {
    param($Config)
    $ids = @(Get-StudyCodeServerProcessIds -Config $Config)
    if ($ids.Count -eq 0) {
        return $false
    }
    foreach ($processId in $ids) {
        & taskkill.exe /PID $processId /T /F | Out-Null
    }
    Start-Sleep -Seconds 1
    return $true
}

function Write-StudyEndpoints {
    param($Config)
    Write-Output "接続先: http://127.0.0.1:$($Config.Port)/"
    Write-Output "同じ Windows 上のブラウザからは http://localhost:$($Config.Port)/ で接続します。"
    Write-Output "設定: $($Config.ConfigFile)"
    Write-Output "ワークスペース: $($Config.Workspace)"
}
