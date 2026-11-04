$ErrorActionPreference='Stop'
foreach($phase in @('Perf','Final','Motion','Smoke')){
 & (Join-Path $PSScriptRoot 'run_reviews.ps1') -Round $phase
 if($LASTEXITCODE -ne 0){throw "V5 failed: $phase"}
 Write-Output "V5_PHASE_OK $phase"
}
