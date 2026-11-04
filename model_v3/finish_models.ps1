$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$engine='H:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe'
& $engine --headless --editor --lsp-port 6035 --dap-port 6036 --path $project --import --quit *> (Join-Path $PSScriptRoot 'import.log')
if($LASTEXITCODE -ne 0){throw 'Import failed'}
& $engine --headless --path $project --log-file (Join-Path $PSScriptRoot 'package.log') --script res://model_v3/package_assets.gd
if($LASTEXITCODE -ne 0){throw 'Asset packaging failed'}
foreach($phase in @('Export','Bake','Final','Motion','Perf','Smoke')){
    & (Join-Path $PSScriptRoot 'run_reviews.ps1') -Round $phase
    if($LASTEXITCODE -ne 0){throw "Failed phase: $phase"}
    Write-Output "MODEL_PHASE_OK $phase"
}
