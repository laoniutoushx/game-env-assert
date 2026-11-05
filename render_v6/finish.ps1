$ErrorActionPreference='Stop'
foreach($stage in @('AO','Cases','PerfBaseline','Perf','Final','Motion','Smoke')){
 & (Join-Path $PSScriptRoot 'run_reviews.ps1') -Round $stage
}
python (Join-Path $PSScriptRoot 'finalize.py')
if($LASTEXITCODE -ne 0){throw 'V6 final validation failed'}
