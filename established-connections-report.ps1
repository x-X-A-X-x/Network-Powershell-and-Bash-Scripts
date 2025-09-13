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
    @{n='RemoteAddress';e={$_.Name}},
    @{n='LocalEndpoints';e={
        ($_.Group | ForEach-Object { "$($_.LocalAddress):$($_.LocalPort)" } |
          Sort-Object | Get-Unique) -join ', '
      }},
    @{n='Processes';e={ ($_.Group.Process | Sort-Object | Get-Unique) -join ', ' }} |
  Format-Table -AutoSize