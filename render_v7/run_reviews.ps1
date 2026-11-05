param([ValidateSet('Cases','Verify','Perf')][string]$Round='Cases')
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$engine='H:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe'
function Review([string]$Name,[string[]]$Flags){
 $log=Join-Path $PSScriptRoot ($Name+'.log')
 & $engine --path $project --quit-after 1800 --log-file $log 'res://render_v7.tscn' -- @Flags 2>&1 | Out-Null
 if($LASTEXITCODE -ne 0 -or (Get-Content $log -Raw) -match 'SCRIPT ERROR|SHADER ERROR|ERROR:'){throw "V7 review failed: $Name"}
 if((Get-Content $log -Raw) -notmatch 'V7_CAPTURE_OK|ATMOSPHERE_(MOTION_OK|BENCHMARK|SMOKE_OK)'){throw "No completion marker: $Name"}
 Write-Output "V7_REVIEW_OK $Name"
}
if($Round -eq 'Cases'){
 foreach($strength in @('0','0.25','0.45')){
  Review "case_$strength" @('--quality-top','--freeze-wind','--presentation=clear',"--canopy_strength=$strength","--tag=case_$strength")
  Review "slice_$strength" @('--quality-top','--slice','--freeze-wind','--presentation=clear',"--canopy_strength=$strength","--tag=slice_$strength")
 }
}else{
 Review 'perf_baseline' @('--quality-benchmark','--canopy=off','--tag=perf_baseline')
 foreach($i in @(1,2)){Review "perf_$i" @('--quality-benchmark',"--tag=perf_$i")}
 if($Round -eq 'Perf'){return}
 foreach($preset in @('clear','cinema')){
  Review "final_$preset" @('--quality-batch','--freeze-wind',"--presentation=$preset","--tag=$preset")
  Review "motion_$preset" @('--motion',"--presentation=$preset","--tag=$preset")
 }
 Review 'smoke' @('--smoke','--freeze-wind')
}
