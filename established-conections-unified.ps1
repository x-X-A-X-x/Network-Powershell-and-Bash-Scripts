<#
  Show all established TCP connections, grouped by remote address.
  For each remote IP, list the count, unique local endpoints, and processes.
  Also shows individual connections below (like netstat -ano).
#>

# Get all established TCP connections
$connections = Get-NetTCPConnection -State Established

# Create a detailed view with resolved process names
$processedConnections = $connections | ForEach-Object {
  $p = $null
  try { $p = Get-Process -Id $_.OwningProcess -ErrorAction Stop } catch {}

  [pscustomobject]@{
    LocalAddress    = $_.LocalAddress
    LocalPort       = $_.LocalPort
    RemoteAddress   = $_.RemoteAddress
    RemotePort      = $_.RemotePort
    LocalEndpoint   = "$($_.LocalAddress):$($_.LocalPort)"
    RemoteEndpoint  = "$($_.RemoteAddress):$($_.RemotePort)"
    PID             = $_.OwningProcess
    Process         = if ($p) { $p.ProcessName } else { "PID:$($_.OwningProcess)" }
  }
}

# Group and summarize by RemoteAddress
$grouped = $processedConnections |
  Group-Object RemoteAddress |
  Sort-Object Count -Descending |
  Select-Object `
    @{n='Count';e={$_.Count}},
    @{n='RemoteAddress';e={$_.Name}},
    @{n='LocalEndpoints';e={ ($_.Group.LocalEndpoint | Sort-Object | Get-Unique) -join ', ' }},
    @{n='Processes';e={ ($_.Group.Process | Sort-Object | Get-Unique) -join ', ' }}

# Output summarized grouped connections
"=== Grouped by Remote Address ==="
$grouped | Format-Table -AutoSize

# Output raw table of individual connections (like netstat)
"`n=== Detailed Connections ==="
$processedConnections |
  Select-Object LocalEndpoint, RemoteEndpoint, PID, Process |
  Format-Table -AutoSize
