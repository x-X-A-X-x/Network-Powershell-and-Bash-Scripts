Get-NetTCPConnection -State Established |
  ForEach-Object {
    # Best-effort resolve of process info; if the process exits or access is denied,
    # fall back to a PID placeholder so we keep the record.
    $p = $null
    try { $p = Get-Process -Id $_.OwningProcess -ErrorAction Stop } catch {}
    [pscustomobject]@{
      RemoteAddress = $_.RemoteAddress
      PID           = $_.OwningProcess
      Process       = if ($p) { $p.ProcessName } else { "PID:$($_.OwningProcess)" }
    }
  } |
  Group-Object RemoteAddress |
  Sort-Object Count -Descending |
  Select-Object @{n='Count';e={$_.Count}},
                @{n='RemoteAddress';e={$_.Name}},
                @{n='Processes';e={ ($_.Group.Process | Sort-Object | Get-Unique) -join ', ' }} |
  Format-Table -AutoSize
