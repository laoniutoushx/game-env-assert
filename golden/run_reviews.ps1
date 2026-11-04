param([ValidateSet('Preview','Final','Perf','Deliver','Details')][string]$Round='Preview')
$ErrorActionPreference='Stop'
if($Round -eq 'Deliver'){
    foreach($phase in @('Final','Perf')){
        & $PSCommandPath -Round $phase
        if($LASTEXITCODE -ne 0){throw "Golden phase failed: $phase"}
    }
    exit 0
}
$godot='H:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe'
$project='H:\game-workflow\work\environment_ruins'
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
$script:index=0;$script:logs=@()
function Invoke-Review {
    param([string[]]$Flags)
    $script:index+=1
    $log=Join-Path $project "golden/review_${stamp}_$script:index.log"
    & $godot --path $project --log-file $log res://golden.tscn -- @Flags
    if($LASTEXITCODE -ne 0){throw "Godot exited $LASTEXITCODE"}
    if(Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|SHADER ERROR|ERROR:|Error compiling shader' -Quiet){throw "Godot errors: $log"}
    $script:logs+=$log
}
if($Round -eq 'Preview'){
    Invoke-Review -Flags @('--sun=baseline','--quality-top','--freeze-wind','--tag=baseline')
    Invoke-Review -Flags @('--quality-top','--freeze-wind','--tag=golden')
}elseif($Round -eq 'Details'){
    foreach($view in @('water','portal')){
        Invoke-Review -Flags @('--quality-top',"--view=$view",'--freeze-wind','--tag=final')
    }
}elseif($Round -eq 'Perf'){
    foreach($i in @(1,2)){
        Invoke-Review -Flags @('--quality-benchmark',"--tag=perf_$i")
        $result=Get-Content -LiteralPath (Join-Path $project "golden/captures/perf_${i}_benchmark.json") -Raw | ConvertFrom-Json
        if($result.p95_ms -gt 33.3){throw 'Golden sunlight exceeds frame budget'}
    }
}else{
    Invoke-Review -Flags @('--quality-batch','--freeze-wind')
    Invoke-Review -Flags @('--motion','--tag=final')
    Invoke-Review -Flags @('--smoke','--freeze-wind')
}
@{round=$Round;success=$true;logs=$script:logs;time=$stamp}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $project "golden/last_${Round}.json") -Encoding utf8
