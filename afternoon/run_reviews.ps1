param([ValidateSet('Preview','Water','Compare','Diagnostics','Export','Bake','Final','Perf','Motion','Smoke','Inspect','Validate','Rebuild','Deliver')][string]$Round='Preview')
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$godot='H:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe'
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
$script:logs=@()
function Invoke-Review {
    param([string[]]$Flags,[string[]]$Expected=@(),[switch]$Editor)
    $log=Join-Path $PSScriptRoot ("review_{0}_{1}_{2}.log" -f $stamp,$Round,$script:logs.Count)
    $started=[DateTime]::UtcNow
    if($Editor){
        $editorGodot='H:\Godot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe'
        & $editorGodot --path $project --editor --lsp-port 6025 --dap-port 6026 --rendering-driver d3d12 --log-file $log res://afternoon/assets/static_lighting.tscn -- @Flags
    }else{
        & $godot --path $project --log-file $log res://afternoon.tscn -- @Flags
    }
    if($LASTEXITCODE -ne 0){throw "Godot exited $LASTEXITCODE : $log"}
    $text=Get-Content -LiteralPath $log -Raw
    $checkText=$text
    if($Editor -and $text.Contains('AFTERNOON_LIGHTMAP_OK')){
        $parts=$text -split 'AFTERNOON_LIGHTMAP_OK',2
        # Only these two native editor teardown diagnostics are classified separately.
        # Any error before the successful bake marker, or any other teardown error, fails.
        $tail=$parts[1] -replace '(?m)^ERROR: Condition "p_I->data != this" is true\. Returning: false\r?$','' -replace '(?m)^ERROR: Can''t use get_node\(\) with absolute paths from outside the active scene tree\.\r?$',''
        $checkText=$parts[0]+$tail
        if($tail -ne $parts[1]){
            @{classification='Godot editor teardown only; runtime must pass independently';log=$log}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $PSScriptRoot 'editor_teardown.json') -Encoding utf8
        }
    }
    if($checkText -match 'SCRIPT ERROR|SHADER ERROR|ERROR:|Error compiling shader|RIDs? of type .* leaked'){throw "Godot errors: $log"}
    foreach($relative in $Expected){
        $file=Get-Item -LiteralPath (Join-Path $PSScriptRoot $relative) -ErrorAction Stop
        if($file.Length -eq 0 -or $file.LastWriteTimeUtc -lt $started.AddSeconds(-2)){throw "Missing or stale artifact: $relative"}
    }
    $script:logs+=$log
}
switch($Round){
    'Preview' { Invoke-Review -Flags @('--quality-top','--freeze-wind','--tag=preview') -Expected @('captures/preview_top.png','captures/preview_top.json') }
    'Water' { Invoke-Review -Flags @('--quality-top','--freeze-wind','--presentation=clear','--cut=ssil,gi,pollen,probe,lightmap','--view=water','--tag=watercheck') -Expected @('captures/watercheck_water.png') }
    'Compare' {
        Invoke-Review -Flags @('--style=baseline','--quality-top','--freeze-wind','--tag=baseline') -Expected @('captures/baseline_top.png')
        Invoke-Review -Flags @('--quality-top','--freeze-wind','--tonemap=agx','--tag=agx') -Expected @('captures/agx_top.png')
        Invoke-Review -Flags @('--quality-top','--freeze-wind','--presentation=clear','--tag=clear') -Expected @('captures/clear_top.png')
        Invoke-Review -Flags @('--quality-top','--freeze-wind','--tag=preview') -Expected @('captures/preview_top.png')
        Invoke-Review -Flags @('--quality-top','--freeze-wind','--cut=ssil,gi,pollen,probe,fog','--tag=nofog') -Expected @('captures/nofog_top.png')
        Invoke-Review -Flags @('--quality-top','--freeze-wind','--cut=ssil,gi,pollen,probe,lightmap','--tag=nolightmap') -Expected @('captures/nolightmap_top.png')
    }
    'Export' { Invoke-Review -Flags @('--export-lighting','--freeze-wind') -Expected @('assets/export.json','assets/static_lighting.tscn') }
    'Diagnostics' {
        Invoke-Review -Flags @('--quality-top','--freeze-wind','--cut=ssil,gi,pollen,probe,fog','--tag=nofog') -Expected @('captures/nofog_top.png')
        Invoke-Review -Flags @('--quality-top','--freeze-wind','--cut=ssil,gi,pollen,probe,lightmap','--tag=nolightmap') -Expected @('captures/nolightmap_top.png')
    }
    'Bake' { Invoke-Review -Editor -Flags @('--afternoon-bake') -Expected @('assets/bake.json') }
    'Final' {
        $views=@('top','left','side','low_side','water','portal','plants')
        foreach($preset in @('cinema','clear')){
            $expected=@()
            foreach($view in $views){$expected+="captures/${preset}_${view}.png";$expected+="captures/${preset}_${view}.json"}
            Invoke-Review -Flags @('--quality-batch','--freeze-wind',"--presentation=$preset","--tag=$preset") -Expected $expected
        }
    }
    'Perf' {
        foreach($i in @(1,2)){
            Invoke-Review -Flags @('--quality-benchmark',"--tag=perf_$i") -Expected @("captures/perf_${i}_benchmark.json")
            $r=Get-Content -LiteralPath (Join-Path $PSScriptRoot "captures/perf_${i}_benchmark.json") -Raw|ConvertFrom-Json
            if($r.samples -ne 600 -or $r.p95_ms -gt 33.3 -or $r.internal_scale -ne 1){throw "Frame budget failed: $($r.p95_ms) ms"}
        }
    }
    'Motion' {
        Invoke-Review -Flags @('--motion','--tag=final') -Expected @('captures/final_motion/poses.json','captures/final_motion/047.png')
        if(@(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'captures/final_motion') -Filter '*.png').Count -ne 48){throw 'Expected 48 motion frames'}
        Invoke-Review -Flags @('--motion','--presentation=clear','--tag=clear') -Expected @('captures/clear_motion/poses.json','captures/clear_motion/047.png')
        if(@(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'captures/clear_motion') -Filter '*.png').Count -ne 48){throw 'Expected 48 clear motion frames'}
    }
    'Smoke' { Invoke-Review -Flags @('--smoke','--freeze-wind') -Expected @('captures/smoke.json') }
    'Deliver' {
        foreach($phase in @('Bake','Compare','Final','Perf','Motion','Smoke')){
            & $PSCommandPath -Round $phase
            if($LASTEXITCODE -ne 0){throw "Afternoon phase failed: $phase"}
        }
    }
    'Inspect' {
        foreach($phase in @('Final','Motion','Diagnostics')){
            & $PSCommandPath -Round $phase
            if($LASTEXITCODE -ne 0){throw "Inspection phase failed: $phase"}
        }
    }
    'Rebuild' {
        foreach($phase in @('Export','Deliver','Diagnostics')){
            & $PSCommandPath -Round $phase
            if($LASTEXITCODE -ne 0){throw "Rebuild phase failed: $phase"}
        }
    }
    'Validate' {
        foreach($phase in @('Compare','Final','Perf','Motion','Smoke','Diagnostics')){
            & $PSCommandPath -Round $phase
            if($LASTEXITCODE -ne 0){throw "Validation phase failed: $phase"}
        }
    }
}
@{round=$Round;success=$true;logs=$script:logs;time=$stamp}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $PSScriptRoot "last_${Round}.json") -Encoding utf8
