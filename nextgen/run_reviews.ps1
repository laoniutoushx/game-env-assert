param([ValidateSet('Sampling','Probes','Final','Assets','Quick')][string]$Round = 'Final')
$ErrorActionPreference = 'Stop'
$godot = 'H:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe'
$project = 'H:\game-workflow\work\environment_ruins'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$script:index = 0
function Invoke-Review {
    param([string[]]$Flags)
    $script:index += 1
    $log = Join-Path $project "nextgen/review_${stamp}_$script:index.log"
    & $godot --path $project --log-file $log res://nextgen.tscn -- @Flags
    if ($LASTEXITCODE -ne 0) { throw "Godot exited $LASTEXITCODE" }
    if (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|SHADER ERROR|ERROR:|Error compiling shader' -Quiet) { throw "Godot errors: $log" }
}
if ($Round -eq 'Quick') {
    Invoke-Review -Flags @('--quality-close','--tag=integration_check')
} elseif ($Round -eq 'Sampling') {
    foreach ($aa in @('msaa','fsr2','ssaa')) {
        $flags = @('--stage=sampling',"--aa=$aa","--tag=sampling_$aa")
        Invoke-Review -Flags ($flags + '--quality-close')
        Invoke-Review -Flags ($flags + '--quality-benchmark')
        Invoke-Review -Flags ($flags + '--motion')
    }
} elseif ($Round -eq 'Probes') {
    foreach ($probe in @('color','normals','ao','shadows')) {
        Invoke-Review -Flags @('--stage=sampling','--aa=msaa',"--isolate=$probe","--tag=probe_$probe",'--quality-close')
    }
    Invoke-Review -Flags @('--stage=sampling','--aa=msaa','--coverage=off','--tag=probe_no_coverage','--quality-close')
    Invoke-Review -Flags @('--quality-close','--tag=integration_check')
} elseif ($Round -eq 'Assets') {
    Invoke-Review -Flags @('--motion','--orbit','--tag=final_orbit')
    Invoke-Review -Flags @('--smoke','--tag=smoke')
    & $godot --path $project --log-file (Join-Path $project 'nextgen/assets_gpu.log') res://nextgen/test_assets.tscn
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath (Join-Path $project 'nextgen/assets_gpu.log') -Pattern 'ERROR:|SCRIPT ERROR' -Quiet)) { throw 'Asset test failed' }
} else {
    if (-not (Test-Path -LiteralPath (Join-Path $project 'nextgen/baseline_2k_top.png'))) {
        Invoke-Review -Flags @('--stage=sampling','--aa=msaa','--quality-top','--tag=baseline_2k')
    }
    foreach ($view in @('top','side','close')) { Invoke-Review -Flags @("--quality-$view",'--tag=final') }
    Invoke-Review -Flags @('--quality-benchmark','--tag=final')
    Invoke-Review -Flags @('--motion','--tag=final')
    Invoke-Review -Flags @('--profile=preview','--quality-top','--tag=preview')
}
