$ErrorActionPreference='Stop'
$engine='H:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe'
$project=Split-Path $PSScriptRoot -Parent
foreach($variant in @('control','physical')){
 $log=Join-Path $PSScriptRoot "light_$variant.log"
 & $engine --path $project --log-file $log res://model_v3/light_study.tscn -- --quality-top --freeze-wind --presentation=clear "--lighting=$variant" "--tag=light_$variant" 2>&1 | Out-Null
 if($LASTEXITCODE -ne 0 -or (Get-Content $log -Raw) -match 'SCRIPT ERROR|SHADER ERROR|ERROR:'){throw "Light study failed: $variant"}
}
$log=Join-Path $PSScriptRoot 'light_unshadowed.log'
& $engine --path $project --log-file $log res://model_v3/light_study.tscn -- --quality-top --freeze-wind --presentation=clear --lighting=physical --volume_shadow=off --tag=light_unshadowed 2>&1 | Out-Null
if($LASTEXITCODE -ne 0 -or (Get-Content $log -Raw) -match 'SCRIPT ERROR|SHADER ERROR|ERROR:'){throw 'Unshadowed comparison failed'}
