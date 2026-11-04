$engine='H:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe'
$project=Split-Path $PSScriptRoot -Parent
Start-Process -FilePath $engine -ArgumentList @('--path',('"'+$project+'"'),'--log-file',('"'+(Join-Path $PSScriptRoot 'live.log')+'"'),'res://render_v5.tscn') -WindowStyle Normal -PassThru | Select-Object Id
