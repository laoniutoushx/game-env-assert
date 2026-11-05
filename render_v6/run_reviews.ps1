param([ValidateSet('Probe','Fixture','Cases','AO','Final','Motion','PerfBaseline','Perf','Smoke')][string]$Round='Probe')
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$engine='H:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe'
function Review([string]$Name,[string[]]$Flags,[string]$Scene='res://render_v6.tscn'){
 $log=Join-Path $PSScriptRoot ($Name+'.log')
 & $engine --path $project --quit-after 1800 --log-file $log $Scene -- @Flags 2>&1 | Out-Null
 if($LASTEXITCODE -ne 0 -or (Get-Content $log -Raw) -match 'SCRIPT ERROR|SHADER ERROR|ERROR:'){throw "V6 review failed: $Name"}
 if((Get-Content $log -Raw) -notmatch 'V6_CAPTURE_OK|V6_FIXTURE_OK|ATMOSPHERE_(MOTION_OK|BENCHMARK|SMOKE_OK)'){throw "No completion marker: $Name"}
 Write-Output "V6_REVIEW_OK $Name"
}
switch($Round){
 'Probe' {
  & $engine --headless --path $project --log-file (Join-Path $PSScriptRoot 'probe.log') --script res://render_v6/probe.gd
  if($LASTEXITCODE -ne 0){throw 'Probe failed'}
 }
 'Fixture' {Review 'fixture' @() 'res://render_v6/normal_fixture.tscn'}
 'Cases' {
  foreach($repair in @('baseline','normal','shadow','combined')){Review "case_$repair" @('--quality-top','--freeze-wind','--presentation=clear',"--repair=$repair","--tag=case_$repair")}
  foreach($strength in @('0.2','0.35')){Review "normal_$strength" @('--quality-top','--quality-close','--freeze-wind','--presentation=clear','--repair=normal',"--normal_strength=$strength","--tag=normal_$strength")}
 }
 'AO' {
  foreach($mode in @('baseline','off_material_ao','off_ssao','off_ssil','off_shadows')){Review "diagnostic_$mode" @('--quality-top','--quality-close','--freeze-wind','--presentation=clear',"--repair=$mode","--tag=diagnostic_$mode")}
 }
 'Final' {foreach($preset in @('clear','cinema')){Review "final_$preset" @('--quality-batch','--freeze-wind',"--presentation=$preset",'--repair=combined',"--tag=$preset")}}
 'Motion' {foreach($preset in @('clear','cinema')){Review "motion_$preset" @('--motion',"--presentation=$preset",'--repair=combined',"--tag=$preset")}}
 'PerfBaseline' {Review 'perf_baseline' @('--quality-benchmark','--repair=baseline','--tag=perf_baseline')}
 'Perf' {
  foreach($i in @(1,2)){
   Review "perf_$i" @('--quality-benchmark','--repair=combined',"--tag=perf_$i")
   $report=Get-Content (Join-Path $PSScriptRoot "captures/perf_${i}_benchmark.json") -Raw|ConvertFrom-Json
   if($report.samples -ne 600 -or $report.p95_ms -gt 33.3 -or $report.internal_scale -ne 1){throw "Frame budget failed: $($report.p95_ms)"}
  }
 }
 'Smoke' {Review 'smoke' @('--smoke','--freeze-wind','--repair=combined')}
}
