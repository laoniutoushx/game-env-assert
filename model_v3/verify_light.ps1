$ErrorActionPreference='Stop'
$engine='H:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe'
$project=Split-Path $PSScriptRoot -Parent
$cases=@(
 @{tag='balanced';flags=@()},
 @{tag='fog_geometry_shadow';flags=@('--fog_debug=on')},
 @{tag='fog_no_shadow';flags=@('--fog_debug=on','--volume_shadow=off')}
)
foreach($case in $cases){
 $log=Join-Path $PSScriptRoot ($case.tag+'.log')
 & $engine --path $project --log-file $log res://model_v3/light_study.tscn -- --quality-top --freeze-wind --presentation=clear --lighting=physical --lookstudy=balanced --shadow_range=fit "--tag=$($case.tag)" @($case.flags) 2>&1 | Out-Null
 if($LASTEXITCODE -ne 0 -or (Get-Content $log -Raw) -match 'SCRIPT ERROR|SHADER ERROR|ERROR:'){throw "Light validation failed: $($case.tag)"}
}
