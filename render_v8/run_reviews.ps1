param([ValidateSet('Cases','Fine','Verify','Perf')][string]$Round='Cases')
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$engine='H:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe'
function Review([string]$Name,[string[]]$Flags){
 $log=Join-Path $PSScriptRoot ($Name+'.log')
 & $engine --path $project --quit-after 1800 --log-file $log 'res://render_v8.tscn' -- @Flags 2>&1 | Out-Null
 if($LASTEXITCODE -ne 0 -or (Get-Content $log -Raw) -match 'SCRIPT ERROR|SHADER ERROR|ERROR:'){throw "V8 review failed: $Name"}
 if((Get-Content $log -Raw) -notmatch 'V8_CAPTURE_OK|ATMOSPHERE_(MOTION_OK|BENCHMARK|SMOKE_OK)'){throw "No completion marker: $Name"}
 Write-Output "V8_REVIEW_OK $Name"
}
if($Round -in @('Cases','Fine')){
 $profiles=if($Round -eq 'Fine'){@('fine')}else{@('baseline','contact','fine')}
 foreach($profile in $profiles){
  Review "case_$profile" @('--quality-top','--freeze-wind','--presentation=clear',"--shadow_profile=$profile","--tag=case_$profile")
  Review "close_$profile" @('--quality-top','--quality-close','--freeze-wind','--presentation=clear',"--shadow_profile=$profile","--tag=close_$profile")
  Review "slice_$profile" @('--quality-top','--slice','--freeze-wind','--presentation=clear',"--shadow_profile=$profile","--tag=slice_$profile")
 }
}else{
 Review 'perf_baseline' @('--quality-benchmark','--shadow_profile=baseline','--tag=perf_baseline')
 foreach($i in @(1,2)){Review "perf_$i" @('--quality-benchmark',"--tag=perf_$i")}
 if($Round -eq 'Perf'){return}
 foreach($preset in @('clear','cinema')){
  Review "final_$preset" @('--quality-batch','--freeze-wind',"--presentation=$preset","--tag=$preset")
  Review "motion_$preset" @('--motion',"--presentation=$preset","--tag=$preset")
 }
 Review 'smoke' @('--smoke','--freeze-wind')
}
