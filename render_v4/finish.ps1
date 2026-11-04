$ErrorActionPreference='Stop'
foreach($phase in @('Export','Bake','Final','Motion','Perf','Smoke')){
 & (Join-Path $PSScriptRoot 'run_reviews.ps1') -Round $phase
 if($LASTEXITCODE -ne 0){throw "V4 failed: $phase"}
 Write-Output "V4_PHASE_OK $phase"
}
