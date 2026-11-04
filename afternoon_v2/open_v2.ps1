$project=Split-Path $PSScriptRoot -Parent
$engine='H:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe'
# Visible because this is the interactive camera inspection requested by the user.
Start-Process -FilePath $engine -ArgumentList @('--path',$project,'--log-file',(Join-Path $PSScriptRoot 'live.log'),'res://afternoon_v2.tscn') -WindowStyle Normal
