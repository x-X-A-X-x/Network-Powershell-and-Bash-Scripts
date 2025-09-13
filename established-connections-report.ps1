# --- Reverse lookup helper with caching --------------------------------------
$DnsCache = @{}

function Resolve-IpToName {
  param([Parameter(Mandatory)][string]$Ip)

  if ($DnsCache.ContainsKey($Ip)) { return $DnsCache[$Ip] }

  $name = $null
  try {
    if ($Ip -in @('127.0.0.1','::1')) {
      $name = 'localhost'
    } else {
      # Prefer PTR record
      $ans = Resolve-DnsName -Name $Ip -Type PTR -ErrorAction Stop
      $ptr = ($ans | Where-Object { $_.Type -eq 'PTR' } | Select-Object -First 1).NameHost
      if ($ptr) { $name = $ptr.TrimEnd('.') }
    }
  } catch { }

  # Fallback to .NET if PTR fails
  if (-not $name) {
    try {
      $entry = [System.Net.Dns]::GetHostEntry($Ip)
      if ($entry.HostName) { $name = $entry.HostName }
    } catch { }
  }

  if (-not $name) { $name = $Ip }   # final fallback
  $DnsCache[$Ip] = $name
  return $name
}

# --- Main query ---------------------------------------------------------------
Get-NetTCPConnection -State Established |
  ForEach-Object {
    $p = $null
    try { $p = Get-Process -Id $_.OwningProcess -ErrorAction Stop } catch {}

    [pscustomobject]@{
      LocalAddress  = $_.LocalAddress
      LocalPort     = $_.LocalPort
      RemoteAddress = $_.RemoteAddress
      RemotePort    = $_.RemotePort
      PID           = $_.OwningProcess
      Process       = if ($p) { $p.ProcessName } else { "PID:$($_.OwningProcess)" }
    }
  } |
  Group-Object RemoteAddress |
  Sort-Object Count -Descending |
  Select-Object @(
    @{ Name = 'Count';  Expression = { $_.Count } }
    @{ Name = 'Remote'; Expression = {
         $ip = $_.Name
         $resolved = Resolve-IpToName -Ip $ip
         if ($resolved -ne $ip) { "$resolved ($ip)" } else { $ip }
       }
    }
    @{ Name = 'RemotePorts'; Expression = {
         ($_.Group.RemotePort | Sort-Object | Get-Unique) -join ', '
       }
    }
    @{ Name = 'LocalEndpoints'; Expression = {
         ($_.Group | ForEach-Object { "$($_.LocalAddress):$($_.LocalPort)" } |
           Sort-Object | Get-Unique) -join ', '
       }
    }
    @{ Name = 'Processes'; Expression = {
         ($_.Group.Process | Sort-Object | Get-Unique) -join ', '
       }
    }
  ) | Format-Table -AutoSize
