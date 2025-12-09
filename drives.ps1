# ==========================
#  FONCTION: Taille sécurisée
# ==========================
function Get-SafeSize {
    param(
        [string]$Path,
        [int]$TimeoutSeconds = 4
    )

    $job = Start-Job -ScriptBlock {
        param($P)
        try {
            if ((Get-Item $P -ErrorAction Stop).PSIsContainer) {
                $sum = Get-ChildItem -Path $P -Recurse -File -Force -ErrorAction SilentlyContinue |
                       Measure-Object -Property Length -Sum
                return $sum.Sum
            } else {
                return (Get-Item $P -ErrorAction Stop).Length
            }
        } catch {
            return 0
        }
    } -ArgumentList $Path

    if (Wait-Job $job -Timeout $TimeoutSeconds) {
        $result = Receive-Job $job
    } else {
        Stop-Job $job | Out-Null
        $result = 0   # Timeout → on évite de bloquer
    }

    Remove-Job $job -Force | Out-Null
    return [int64]$result
}

# ==========================
#  Liste des disques
# ==========================
$drives = Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    $used = $_.Used
    $free = $_.Free
    $total = $used + $free
    $perc  = if ($total -gt 0) { [math]::Round(($used / $total) * 100) } else { 0 }

    [PSCustomObject]@{
        Name        = $_.Name
        Root        = $_.Root
        TotalGB     = "{0:N2}" -f ($total / 1GB)
        UsedGB      = "{0:N2}" -f ($used / 1GB)
        FreeGB      = "{0:N2}" -f ($free / 1GB)
        PercentUsed = $perc
    }
}

# ==========================
#  Affichage tableau
# ==========================
Write-Host "`n=== Etat des disques ===" -ForegroundColor Cyan

$drives | Format-Table -AutoSize

# ==========================
#  Barres
# ==========================
Write-Host "`n=== Barres d'utilisation ===" -ForegroundColor Yellow

foreach ($d in $drives) {
    $len = 30
    $filled = [math]::Round(($d.PercentUsed / 100) * $len)
    $bar = ("█" * $filled) + ("░" * ($len - $filled))
    Write-Host "$($d.Name) : $bar  $($d.PercentUsed)%"
}

# ==========================
#  TOP 3 éléments
# ==========================
Write-Host "`n=== Top 3 éléments les plus lourds (sans Program*) ===" -ForegroundColor Green

$exclude = @("Windows","Program Files","Program Files (x86)","ProgramData","$env:USERNAME\AppData")

foreach ($d in $drives) {
    Write-Host "`n--- Disque $($d.Name) ($($d.Root)) ---" -ForegroundColor Cyan
    
    try {
        $items = Get-ChildItem -LiteralPath $d.Root -Force -ErrorAction SilentlyContinue |
                 Where-Object { $exclude -notcontains $_.Name }

        $list = foreach ($i in $items) {
            $size = Get-SafeSize -Path $i.FullName
            [PSCustomObject]@{
                Name = $i.Name
                FullName = $i.FullName
                SizeGB = "{0:N2}" -f ($size / 1GB)
                Bytes = $size
                Type = if ($i.PSIsContainer) { "Dir" } else { "File" }
            }
        }

        $list | Sort-Object Bytes -Descending | Select-Object -First 3 |
            Format-Table Name,SizeGB,Type -AutoSize

    } catch {
        Write-Host "Erreur: $($_.Exception.Message)" -ForegroundColor Red
    }
}
