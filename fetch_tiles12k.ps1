$ErrorActionPreference = 'Stop'
$folder = Join-Path $PSScriptRoot 'nextgen/source'
New-Item -ItemType Directory -Path $folder -Force | Out-Null
$archive = Join-Path $folder 'Tiles130_12K-PNG.zip'
if (-not (Test-Path -LiteralPath $archive)) {
    Invoke-WebRequest -Uri 'https://ambientcg.com/get?file=Tiles130_12K-PNG.zip' -OutFile ($archive + '.partial') -TimeoutSec 1800
    Move-Item -LiteralPath ($archive + '.partial') -Destination $archive
}
$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
Write-Output "SOURCE_SHA256 $hash"
Expand-Archive -LiteralPath $archive -DestinationPath $folder -Force
Write-Output 'TILES12K_READY'
