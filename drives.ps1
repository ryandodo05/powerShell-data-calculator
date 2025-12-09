$drives = Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    $used = $_.Used
    $free = $_.Free
    $total = $used + $free
    [PSCustomObject]@{
        Name  = $_.Name
        TotalGB = "{0:N2} GB" -f ($total / 1GB)
        UséeGB  = "{0:N2} GB" -f ($used / 1GB)
        libreGB  = "{0:N2} GB" -f ($free / 1GB)
    }
}
$drives | Sort-Object UsedGB -Descending | Format-Table