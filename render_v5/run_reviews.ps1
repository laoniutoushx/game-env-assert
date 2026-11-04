param([ValidateSet('Cases','Focus','Final','Motion','PerfBaseline','Perf','Smoke')][string]$Round='Cases')
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$engine='H:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe'
function Review([string]$Name,[string[]]$Flags){
 $log=Join-Path $PSScriptRoot ($Name+'.log')
 $start=[DateTime]::UtcNow
 & $engine --path $project --quit-after 1800 --log-file $log res://render_v5.tscn -- @Flags 2>&1 | Out-Null
 if($LASTEXITCODE -ne 0 -or (Get-Content $log -Raw) -match 'SCRIPT ERROR|SHADER ERROR|ERROR:'){throw "V5 review failed: $Name"}
 if(-not ((Get-Content $log -Raw) -match 'V5_CAPTURE_OK|ATMOSPHERE_(MOTION_OK|BENCHMARK|SMOKE_OK)')){throw "No completion marker: $Name"}
 Write-Output "V5_REVIEW_OK $Name"
}
switch($Round){
 'Cases' {
  foreach($variant in @('baseline','leaf','contact','air','all')){Review "case_$variant" @('--quality-top','--freeze-wind','--presentation=clear',"--variant=$variant","--tag=case_$variant")}
 }
 'Focus' {
  foreach($variant in @('baseline','all')){
   Review "slice_$variant" @('--quality-top','--slice','--freeze-wind','--presentation=clear',"--variant=$variant","--tag=slice_$variant")
  }
 }
 'Final' {
  foreach($preset in @('clear','cinema')){Review "final_$preset" @('--quality-batch','--freeze-wind',"--presentation=$preset",'--variant=all',"--tag=$preset")}
 }
 'Motion' {
  foreach($preset in @('clear','cinema')){Review "motion_$preset" @('--motion',"--presentation=$preset",'--variant=all',"--tag=$preset")}
 }
 'PerfBaseline' {Review 'perf_baseline' @('--quality-benchmark','--variant=baseline','--tag=perf_baseline')}
 'Perf' {
  foreach($i in @(1,2)){
   Review "perf_$i" @('--quality-benchmark','--variant=all',"--tag=perf_$i")
   $report=Get-Content -LiteralPath (Join-Path $PSScriptRoot "captures/perf_${i}_benchmark.json") -Raw|ConvertFrom-Json
   if($report.samples -ne 600 -or $report.p95_ms -gt 33.3 -or $report.internal_scale -ne 1){throw "Frame budget failed: $($report.p95_ms)"}
  }
 }
 'Smoke' {Review 'smoke' @('--smoke','--freeze-wind','--variant=all')}
}
