<#
.SYNOPSIS
  Network Isolation Compliance Scanner (ICMP + TCP).

.DESCRIPTION
  - Input: hosts.xlsx (columns: Host, Boundary, Location, Description)
  - Ports: ports.txt (one port per line)
  - Preserves spreadsheet order (dedupes by first occurrence)
  - If ANY test (ICMP or any TCP port) succeeds => Not Compliant
  - Output: timestamped XLSX under "Results" subfolder

.REQUIREMENTS
  - Windows PowerShell 5.1
  - ImportExcel module (Install-Module ImportExcel -Scope CurrentUser -Force)

.VERSION
  2.5
#>

# ===================== CONFIG =====================
$TcpTimeoutMs   = 1200   # per-port TCP timeout (ms)
$Retries        = 0      # extra attempts beyond first
$DoIcmp         = $true  # set $false if ping is blocked
$OutputPrefix   = "results"
# ==================================================

$scriptStart = Get-Date

# -------- Resolve paths --------
$ScriptDir  = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }

$HostsFile  = Join-Path $ScriptDir "hosts.xlsx"
$PortsFile  = Join-Path $ScriptDir "ports.txt"

$ResultsDir = Join-Path $ScriptDir "Results"   # CHANGED from results → Results
if (-not (Test-Path $ResultsDir)) { New-Item -Path $ResultsDir -ItemType Directory | Out-Null }

$Timestamp  = Get-Date -Format "yyyyMMdd-HHmmss"
$OutputFile = Join-Path $ResultsDir "$OutputPrefix-$Timestamp.xlsx"

# -------- Ensure ImportExcel --------
if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    Write-Error "Missing module: ImportExcel. Install with: Install-Module ImportExcel -Scope CurrentUser -Force"
    exit 1
}
Import-Module ImportExcel -Force

# ===================== INPUT LOADING =====================
if (-not (Test-Path $HostsFile)) {
    Write-Error "hosts.xlsx not found at: $HostsFile"
    exit 1
}
try { $HostsData = Import-Excel -Path $HostsFile } catch { Write-Error "Failed to read $HostsFile. $_"; exit 1 }

# Map headers (case-insensitive)
$colMap = @{}
$columns = ($HostsData | Get-Member -MemberType NoteProperty).Name
foreach ($c in $columns) { $colMap[$c.Trim().ToLower()] = $c }

if (-not $colMap.ContainsKey("host")) {
    $found = ($columns -join ', ')
    Write-Error "Input must contain a 'Host' column. Found: $found"
    exit 1
}

$HostCol        = $colMap["host"]
$BoundaryCol    = if ($colMap.ContainsKey("boundary"))    { $colMap["boundary"] }    else { $null }
$LocationCol    = if ($colMap.ContainsKey("location"))    { $colMap["location"] }    else { $null }
$DescriptionCol = if ($colMap.ContainsKey("description")) { $colMap["description"] } else { $null }

# Preserve spreadsheet order; dedupe by first occurrence
$seen  = @{}
$Hosts = @()
foreach ($Row in $HostsData) {
    $h = ([string]$Row.$HostCol).Trim()
    if (-not [string]::IsNullOrWhiteSpace($h)) {
        if (-not $seen.ContainsKey($h)) {
            $seen[$h] = $true
            $Hosts += [PSCustomObject]@{
                Host        = $h
                Boundary    = if ($BoundaryCol)    { ([string]$Row.$BoundaryCol).Trim() }    else { "" }
                Location    = if ($LocationCol)    { ([string]$Row.$LocationCol).Trim() }    else { "" }
                Description = if ($DescriptionCol) { ([string]$Row.$DescriptionCol).Trim() } else { "" }
            }
        }
    }
}

if (-not $Hosts -or $Hosts.Count -eq 0) { Write-Error "No hosts found in $HostsFile."; exit 1 }

# Load ports.txt
if (-not (Test-Path $PortsFile)) { Write-Error "ports.txt not found at: $PortsFile"; exit 1 }
try {
    $Ports = Get-Content -Path $PortsFile | ForEach-Object { $_.Trim() } |
             Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
} catch { Write-Error "Failed to read $PortsFile. $_"; exit 1 }
if (-not $Ports -or $Ports.Count -eq 0) { Write-Error "No valid ports found in $PortsFile."; exit 1 }

# ===================== HELPERS =====================
function Resolve-TargetIP {
    param([string]$Target)
    try {
        $dns = [System.Net.Dns]::GetHostAddresses($Target) | Where-Object { $_.AddressFamily -eq 'InterNetwork' }
        if ($dns -and $dns.Count -gt 0) { return $dns[0].ToString() }
        return $null
    } catch { return $null }
}

function Test-TcpPort {
    param([string]$ComputerName, [int]$Port, [int]$TimeoutMs = 1200)
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $iar = $client.BeginConnect($ComputerName, $Port, $null, $null)
        $ok = $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        if (-not $ok) { $client.Close(); return "Timeout" }
        $client.EndConnect($iar)
        $client.Close()
        return "Open"
    } catch { return "Closed" }
}

function Invoke-WithRetry {
    param([scriptblock]$Action, [int]$Retries = 0)
    $attempt = 0; $last = $null
    do {
        $attempt++; $last = & $Action
        if ($last -is [bool])       { if ($last) { return $last } }
        elseif ($last -is [string]) { if ($last -eq "Open") { return $last } }
        Start-Sleep -Milliseconds 80
    } while ($attempt -le $Retries)
    return $last
}

# ===================== SCAN =====================
$Results = @()
$tested = 0; $compliant = 0; $noncompliant = 0

Write-Host "Testing $($Hosts.Count) host(s) across $($Ports.Count) port(s)..." -ForegroundColor Yellow

foreach ($h in $Hosts) {
    $targetHost  = $h.Host
    $boundary    = $h.Boundary
    $location    = $h.Location
    $desc        = $h.Description
    $tested++

    Write-Host "Checking $targetHost ($boundary / $location) - $desc" -ForegroundColor Cyan

    $resolvedIp = Resolve-TargetIP -Target $targetHost
    $isCompliant = $true

    $row = [ordered]@{
        Host        = $targetHost
        Boundary    = $boundary
        Location    = $location
        Description = $desc
        ResolvedIP  = $(if ($resolvedIp) { $resolvedIp } else { "" })
    }

    # ICMP
    if ($DoIcmp) {
        $icmp = Invoke-WithRetry -Retries $Retries -Action {
            try {
                $p = New-Object System.Net.NetworkInformation.Ping
                $reply = $p.Send($targetHost, 1000)
                ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success)
            } catch { $false }
        }
        if ($icmp) { $row["ICMP"] = "Responded"; $isCompliant = $false } else { $row["ICMP"] = "Blocked" }
    } else {
        $row["ICMP"] = "Skipped"
    }

    # TCP ports
    foreach ($p in $Ports) {
        $tcp = Invoke-WithRetry -Retries $Retries -Action {
            Test-TcpPort -ComputerName $targetHost -Port $p -TimeoutMs $TcpTimeoutMs
        }
        $row["Port $p"] = $tcp
        if ($tcp -eq "Open") { $isCompliant = $false }
    }

    $row["Status"]    = if ($isCompliant) { "Compliant" } else { "Not Compliant" }
    $row["CheckedOn"] = (Get-Date)

    if ($isCompliant) { $compliant++ } else { $noncompliant++ }

    $Results += New-Object PSObject -Property $row
}

# ===================== EXPORT =====================
$Results | Export-Excel -Path $OutputFile -WorksheetName "Results" -AutoSize -FreezeTopRow `
    -TableName "NetworkCompliance" -TableStyle "Medium2" -ClearSheet

Write-Host ""
Write-Host "Results written to $OutputFile" -ForegroundColor Green
Write-Host ("Summary: Tested={0}  Compliant={1}  NotCompliant={2}" -f $Results.Count, $compliant, $noncompliant)
