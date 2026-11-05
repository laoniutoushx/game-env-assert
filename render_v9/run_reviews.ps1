param([ValidateSet('Probe','Cases','Diagnose','Tune','Tune2','Temporal','TemporalCandidate','TemporalRest','PanTrial','Verify','Perf','Smoke','Final')][string]$Round='Probe')
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$engine='H:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe'
function Review([string]$Name,[string[]]$Flags,[bool]$Continuous=$false){
 $log=Join-Path $PSScriptRoot ($Name+'.log')
 $options=@('--path',$project,'--quit-after','5000','--log-file',$log)
 if($Continuous){$options+=@('--fixed-fps','30','--disable-vsync')}
 & $engine @options 'res://render_v9.tscn' -- @Flags 2>&1 | Out-Null
 if($LASTEXITCODE -ne 0 -or (Get-Content $log -Raw) -match 'SCRIPT ERROR|SHADER ERROR|ERROR:'){throw "V9 review failed: $Name"}
 if((Get-Content $log -Raw) -notmatch 'V9_CAPTURE_OK|V9_CONTINUOUS_OK|ATMOSPHERE_(MOTION_OK|BENCHMARK|SMOKE_OK)'){throw "No completion marker: $Name"}
 Write-Output "V9_REVIEW_OK $Name"
}
switch($Round){
 'Probe' {Review 'probe' @('--quality-top','--quality-close','--freeze-wind','--presentation=clear','--tag=probe')}
 'Cases' {
  foreach($mode in @('baseline','surface','shadow','lod','combined')){Review "case_$mode" @('--quality-top','--freeze-wind','--presentation=clear',"--foliage_mode=$mode","--tag=case_$mode")}
  foreach($mode in @('baseline','combined')){Review "close_$mode" @('--quality-top','--quality-close','--freeze-wind','--presentation=clear',"--foliage_mode=$mode","--tag=close_$mode")}
  foreach($floor in @('0.55','0.60','0.65')){Review "floor_$floor" @('--quality-top','--quality-close','--freeze-wind','--presentation=clear','--foliage_mode=surface',"--leaf_floor=$floor","--tag=floor_$floor")}
 }
 'Diagnose' {
  foreach($mode in @('baseline','no_plant_shadow','no_specular','no_normals','no_screen_indirect','lock_lod','surface','shadow','combined')){
   Review "diag_$mode" @('--continuous','--clip=pan','--frames=180','--freeze-wind','--presentation=clear',"--foliage_mode=$mode","--tag=diag_$mode") $true
  }
 }
 'Tune' {
  foreach($filter in @('medium','high')){
   foreach($angle in @('0.6','0.9','1.2')){Review "angle_${filter}_$angle" @('--continuous','--clip=pan','--frames=180','--freeze-wind','--presentation=clear','--foliage_mode=shadow',"--sun_angle=$angle","--shadow_filter=$filter","--tag=angle_${filter}_$angle") $true}
  }
 }
 'Tune2' {
  foreach($trial in @(@('0.45','medium','4096'),@('0.3','medium','4096'),@('0.0','medium','4096'),@('0.3','high','4096'),@('0.6','medium','8192'))){
   $angle=$trial[0];$filter=$trial[1];$atlas=$trial[2];$name="angle_${filter}_${angle}_$atlas"
   Review $name @('--continuous','--clip=pan','--frames=180','--freeze-wind','--presentation=clear','--foliage_mode=shadow',"--sun_angle=$angle","--shadow_filter=$filter","--shadow_atlas=$atlas","--tag=$name") $true
  }
 }
 'PanTrial' {Review 'trial_03_pan' @('--continuous','--clip=pan','--frames=600','--freeze-wind','--presentation=clear','--foliage_mode=combined','--sun_angle=0.3','--tag=trial_03_pan') $true}
 {$_ -in @('Temporal','TemporalCandidate','TemporalRest')} {
  $modes=if($Round -in @('TemporalCandidate','TemporalRest')){@('combined')}else{@('baseline','combined')}
  foreach($mode in $modes){
   $clips=if($Round -eq 'TemporalRest'){@('static','wind','lod','orbit')}else{@('static','wind','pan','lod','orbit')}
   foreach($clip in $clips){
    $count=if($clip -in @('static','wind')){'300'}else{'600'}
    Review "${mode}_$clip" @('--continuous',"--clip=$clip","--frames=$count",'--freeze-wind','--presentation=clear',"--foliage_mode=$mode","--tag=${mode}_$clip") $true
   }
  }
 }
 'Smoke' {Review 'smoke' @('--smoke','--freeze-wind')}
 'Final' {
  foreach($preset in @('clear','cinema')){
   Review "final_$preset" @('--quality-batch','--freeze-wind',"--presentation=$preset","--tag=$preset")
   Review "motion_$preset" @('--motion',"--presentation=$preset","--tag=$preset")
  }
  Review 'smoke' @('--smoke','--freeze-wind')
 }
 {$_ -in @('Verify','Perf')} {
  Review 'perf_baseline' @('--quality-benchmark','--foliage_mode=baseline','--tag=perf_baseline')
  foreach($i in @(1,2)){Review "perf_$i" @('--quality-benchmark',"--tag=perf_$i")}
  if($Round -eq 'Perf'){break}
  foreach($preset in @('clear','cinema')){
   Review "final_$preset" @('--quality-batch','--freeze-wind',"--presentation=$preset","--tag=$preset")
   Review "motion_$preset" @('--motion',"--presentation=$preset","--tag=$preset")
  }
  Review 'smoke' @('--smoke','--freeze-wind')
 }
}
