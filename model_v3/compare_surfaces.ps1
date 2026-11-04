$ErrorActionPreference='Stop'
$engine='H:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe'
$project=Split-Path $PSScriptRoot -Parent
foreach($variant in @('off','on')){
 $log=Join-Path $PSScriptRoot "surfaces_$variant.log"
 & $engine --path $project --log-file $log res://model_v3/light_study.tscn -- --quality-top --freeze-wind --presentation=clear --lighting=physical "--surfaces=$variant" "--tag=surfaces_$variant" 2>&1 | Out-Null
 if($LASTEXITCODE -ne 0 -or (Get-Content $log -Raw) -match 'SCRIPT ERROR|SHADER ERROR|ERROR:'){throw "Surface study failed: $variant"}
}
