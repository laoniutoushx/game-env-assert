$ErrorActionPreference='Stop'
$engine='H:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe'
$project=Split-Path $PSScriptRoot -Parent
foreach($test in @('single','bias')){
 $log=Join-Path $PSScriptRoot "shadow_$test.log"
 & $engine --path $project --log-file $log res://render_v4/shadow_compare.tscn -- --quality-top --freeze-wind --presentation=clear "--shadow_test=$test" "--tag=shadow_$test" 2>&1 | Out-Null
 if($LASTEXITCODE -ne 0 -or (Get-Content $log -Raw) -match 'SCRIPT ERROR|SHADER ERROR|ERROR:'){throw "Shadow comparison failed: $test"}
}
