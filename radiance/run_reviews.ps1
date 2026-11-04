param([ValidateSet('Quick','Stages','Perf','Tune','Final','Coverage','Assets','Deliver','Reflection')][string]$Round='Quick')
$ErrorActionPreference='Stop'
if($Round -eq 'Deliver') {
    foreach($phase in @('Stages','Coverage','Final','Assets','Perf')) {
        & $PSCommandPath -Round $phase
        if($LASTEXITCODE -ne 0){throw "Delivery phase failed: $phase"}
        if($phase -eq 'Coverage'){
            & 'H:\game-workflow\.venv\Scripts\python.exe' 'H:\game-workflow\work\environment_ruins\radiance\measure.py' --gate
            if($LASTEXITCODE -ne 0){throw 'Visual measurements did not pass'}
        }
    }
    exit 0
}
$godot='H:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe'
$project='H:\game-workflow\work\environment_ruins'
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
$script:index=0
$script:logs=@()
$script:performance=@()
function Invoke-Review {
    param([string[]]$Flags)
    $script:index+=1
    $log=Join-Path $project "radiance/review_${stamp}_$script:index.log"
    & $godot --path $project --log-file $log res://radiance.tscn -- @Flags
    if ($LASTEXITCODE -ne 0) { throw "Godot exited $LASTEXITCODE" }
    if (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|SHADER ERROR|ERROR:|Error compiling shader' -Quiet) { throw "Godot errors: $log" }
    $script:logs+=$log
}
if ($Round -eq 'Reflection') {
    Invoke-Review -Flags @('--bake-reflection','--freeze-wind')
} elseif ($Round -eq 'Quick') {
    Invoke-Review -Flags @('--quality-top','--freeze-wind','--tag=quick')
} elseif ($Round -eq 'Stages') {
    Invoke-Review -Flags @('--quality-stages','--freeze-wind')
} elseif ($Round -eq 'Perf') {
    foreach($i in @(1,2)) {
        Invoke-Review -Flags @('--quality-benchmark',"--tag=perf_$i")
        $report=Get-Content -LiteralPath (Join-Path $project "radiance/captures/perf_${i}_benchmark.json") -Raw | ConvertFrom-Json
        $script:performance+=$report
        if($report.p95_ms -gt 33.3){break}
    }
} elseif ($Round -eq 'Tune') {
    $settingPath=Join-Path $project 'radiance/settings.json'
    $accepted=$false
    foreach($cuts in @('fog,ssil,gi,pollen','fog,ssil,gi,pollen,probe')) {
        $settings=Get-Content -LiteralPath $settingPath -Raw | ConvertFrom-Json
        $settings.cut=$cuts;$settings.ssr_steps=24
        $settings | ConvertTo-Json | Set-Content -LiteralPath $settingPath -Encoding utf8
        $pair=@()
        foreach($i in @(1,2)) {
            $tag="tune_$script:index"
            Invoke-Review -Flags @('--quality-benchmark',"--tag=$tag")
            $resultPath=Join-Path $project "radiance/captures/${tag}_benchmark.json"
            $report=Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
            $script:performance+=$report
            if($report.p95_ms -gt 33.3){break}
            $pair+=$resultPath
        }
        if($pair.Count -eq 2) {
            for($i=0;$i -lt 2;$i++){Copy-Item -LiteralPath $pair[$i] -Destination (Join-Path $project "radiance/captures/perf_$($i+1)_benchmark.json")}
            $accepted=$true;break
        }
    }
    if(-not $accepted){throw 'Final performance budget not met'}
} elseif ($Round -eq 'Coverage') {
    Invoke-Review -Flags @('--quality-coverage','--freeze-wind')
} elseif ($Round -eq 'Assets') {
    Invoke-Review -Flags @('--smoke','--freeze-wind','--export-assets')
    $log=Join-Path $project "radiance/assets_${stamp}.log"
    & $godot --path $project --log-file $log res://radiance/test_assets.tscn
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern 'ERROR:|SCRIPT ERROR' -Quiet)) { throw 'Asset test failed' }
    $script:logs+=$log
} else {
    Invoke-Review -Flags @('--quality-batch','--freeze-wind')
    Invoke-Review -Flags @('--motion','--tag=final')
    Invoke-Review -Flags @('--motion','--freeze-wind','--tag=frozen')
    Invoke-Review -Flags @('--smoke','--freeze-wind')
}
@{round=$Round;logs=$script:logs;success=$true;time=$stamp;performance=$script:performance} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $project "radiance/last_${Round}.json") -Encoding utf8
