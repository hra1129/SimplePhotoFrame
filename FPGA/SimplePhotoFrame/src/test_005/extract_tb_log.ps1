param(
    [string]$InputLog = 'log.txt',
    [string]$OutputLog = 'tb_only.log'
)

$ErrorActionPreference = 'Stop'

if( -not (Test-Path $InputLog) ) {
    Write-Error "Input log not found: $InputLog"
}

$patterns = @(
    '^#\s*\[TB\]',
    '^\[TB\]',
    'FATAL',
    'ERROR',
    '\*\*\s*(Error|Fatal)'
)

$regex = ($patterns -join '|')
$matches = Select-String -Path $InputLog -Pattern $regex -CaseSensitive:$false

$lines = @()
foreach( $m in $matches ) {
    $line = $m.Line
    if( $line -match '^#\s*(.*)$' ) {
        $line = $Matches[1]
    }
    $lines += $line
}

Set-Content -Path $OutputLog -Value $lines

$summary = $lines | Where-Object { $_ -match '^\[TB\] Summary:' } | Select-Object -Last 1
if( $summary ) {
    Write-Host $summary
}
else {
    Write-Host '[TB] Summary line not found in filtered log.'
}

Write-Host "Filtered log written to $OutputLog"
