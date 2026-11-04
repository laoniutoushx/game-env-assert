param([ValidateSet('Slice','Bake','Benchmark','Final','Smoke','Coverage')][string]$Round='Final')
$ErrorActionPreference='Stop'
$godot='H:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe'
$project='H:\game-workflow\work\environment_ruins'
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
$script:index=0
$script:logs=@()
function Invoke-Review {
    param([string[]]$Flags)
    $script:index+=1
    $log=Join-Path $project "atmosphere/review_${stamp}_$script:index.log"
    & $godot --path $project --log-file $log res://atmosphere.tscn -- @Flags
    if ($LASTEXITCODE -ne 0) { throw "Godot exited $LASTEXITCODE" }
    if (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|SHADER ERROR|ERROR:|Error compiling shader' -Quiet) { throw "Godot errors: $log" }
    $script:logs+=$log
}
if ($Round -eq 'Slice') {
    foreach ($look in @('base','layout','surface','final')) { Invoke-Review -Flags @("--look=$look",'--quality-top','--slice','--freeze-wind',"--tag=slice_$look") }
} elseif ($Round -eq 'Bake') {
    Invoke-Review -Flags @('--bake-gi','--freeze-wind')
} elseif ($Round -eq 'Benchmark') {
    @{cut='';internal_scale=1.25;target_p95_ms=33.3;new_meshy_credits=0} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $project 'atmosphere/settings.json') -Encoding utf8
    $candidates=@('','fog','fog,ssil','fog,ssil,gi','fog,ssil,gi,ssr')
    $accepted=$false
    foreach ($cuts in $candidates) {
        $label='perf_'+$script:index
        Invoke-Review -Flags @('--quality-benchmark',"--cut=$cuts","--tag=$label")
        $result=Get-Content -LiteralPath (Join-Path $project "atmosphere/captures/${label}_benchmark.json") -Raw | ConvertFrom-Json
        if ($result.p95_ms -le 33.3) {
            @{cut=$cuts;internal_scale=1.25;target_p95_ms=33.3;new_meshy_credits=0} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $project 'atmosphere/settings.json') -Encoding utf8
            $accepted=$true;break
        }
    }
    if (-not $accepted) {
        @{cut='fog,ssil,gi,ssr';internal_scale=1.0;target_p95_ms=33.3;new_meshy_credits=0} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $project 'atmosphere/settings.json') -Encoding utf8
        Invoke-Review -Flags @('--quality-benchmark','--tag=perf_native')
        $result=Get-Content -LiteralPath (Join-Path $project 'atmosphere/captures/perf_native_benchmark.json') -Raw | ConvertFrom-Json
        if ($result.p95_ms -gt 33.3) { throw 'Native 2K performance target not met' }
        # Native 2K can regain useful effects using the measured GPU headroom.
        foreach ($restore in @('fog,ssil,gi','fog,gi')) {
            @{cut=$restore;internal_scale=1.0;target_p95_ms=33.3;new_meshy_credits=0} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $project 'atmosphere/settings.json') -Encoding utf8
            $label=if($restore -eq 'fog,ssil,gi'){'perf_native_ssr'}else{'perf_native_ssr_ssil'}
            Invoke-Review -Flags @('--quality-benchmark',"--tag=$label")
            $trial=Get-Content -LiteralPath (Join-Path $project "atmosphere/captures/${label}_benchmark.json") -Raw | ConvertFrom-Json
            if($trial.p95_ms -le 33.3){$result=$trial;$cuts=$restore}else{break}
        }
        @{cut=$result.cut;internal_scale=1.0;target_p95_ms=33.3;new_meshy_credits=0} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $project 'atmosphere/settings.json') -Encoding utf8
    }
} elseif ($Round -eq 'Smoke') {
    Invoke-Review -Flags @('--smoke','--freeze-wind','--export-assets')
    & $godot --path $project --log-file (Join-Path $project 'atmosphere/assets_gpu.log') res://atmosphere/test_assets.tscn
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath (Join-Path $project 'atmosphere/assets_gpu.log') -Pattern 'ERROR:|SCRIPT ERROR' -Quiet)) { throw 'Asset test failed' }
    $script:logs+=Join-Path $project 'atmosphere/assets_gpu.log'
} elseif ($Round -eq 'Coverage') {
    Invoke-Review -Flags @('--coverage','--freeze-wind')
    & (Join-Path $project '../../.venv/Scripts/python.exe') (Join-Path $project 'atmosphere/measure_coverage.py')
    if ($LASTEXITCODE -ne 0) { throw 'Coverage measurement failed' }
    Invoke-Review -Flags @('--quality-benchmark','--tag=density')
} else {
    Invoke-Review -Flags @('--look=base','--quality-top','--freeze-wind','--tag=baseline')
    foreach ($view in @('top','side','close')) { Invoke-Review -Flags @("--quality-$view",'--freeze-wind','--tag=final') }
    Invoke-Review -Flags @('--camera=orthographic','--quality-top','--freeze-wind','--tag=final_ortho')
    Invoke-Review -Flags @('--quality-benchmark','--tag=final')
    Invoke-Review -Flags @('--motion','--tag=final')
    Invoke-Review -Flags @('--motion','--freeze-wind','--tag=frozen')
    Invoke-Review -Flags @('--smoke','--freeze-wind')
}
@{round=$Round;logs=$script:logs;success=$true;time=$stamp} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $project "atmosphere/last_${Round}.json") -Encoding utf8
