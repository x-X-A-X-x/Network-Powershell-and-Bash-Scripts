# --- Reverse lookup helper with caching --------------------------------------
$DnsCache = @{}

function Resolve-IpToName {
  param([Parameter(Mandatory)][string]$Ip)

  if ($DnsCache.ContainsKey($Ip)) { return $DnsCache[$Ip] }

  $name = $null
  try {
    # Fast path for loopback
    if ($Ip -in @('127.0.0.1','::1')) {
      $name = 'localhost'
    } else {
      # Prefer PTR via Resolve-DnsName
      $ans = Resolve-DnsName -Name $Ip -Type PTR -ErrorAction Stop
      $ptr = ($ans | Where-Object { $_.Type -eq 'PTR' } | Select-Object -First 1).NameHost
      if ($ptr) { $name = $ptr.TrimEnd('.') }
    }
  } catch { }

  # Fallback to .NET if PTR failed
  if (-not $name) {
    try {
      $entry = [System.Net.Dns]::GetHostEntry($Ip)
      if ($entry.HostName) { $name = $entry.HostName }
    } catch { }
  }

  if (-not $name) { $name = $Ip }  # final fallback: keep IP

  $DnsCache[$Ip] = $name
  return $name
}

# --- Main query ---------------------------------------------------------------
Get-NetTCPConnection -State Established |
  ForEach-Object {
    # Best-effort resolve owning process; if it fails, keep the PID
    $p = $null
    try { $p = Get-Process -Id $_.OwningProcess -ErrorAction Stop } catch {}

    [pscustomobject]@{
      LocalAddress   = $_.LocalAddress
      LocalPort      = $_.LocalPort
      RemoteAddress  = $_.RemoteAddress
      RemotePort     = $_.RemotePort
      PID            = $_.OwningProcess
      Process        = if ($p) { $p.ProcessName } else { "PID:$($_.OwningProcess)" }
    }
  } |
  Group-Object RemoteAddress |
  Sort-Object Count -Descending |
  Select-Object `
    @{n='Count';e={$_.Count}},
    # Show "hostname (ip)" if a name exists; otherwise just the IP
    @{n='Remote';e={
        $ip = $_.Name
        $resolved = Resolve-IpToName -Ip $ip
        if ($resolved -ne $ip) { "$resolved ($ip)" } else { $ip }
      }},
    @{n='LocalEndpoints';e={
        ($_.Group | ForEach-Object { "$($_.LocalAddress):$($_.LocalPort)" } |
          Sort-Object | Get-Unique) -join ', '
      }},
    @{n='Processes';e={ ($_.Group.Process | Sort-Object | Get-Unique) -join ', ' }} |
  Format-Table -AutoSize
