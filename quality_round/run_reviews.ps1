param([switch]$Assets, [switch]$SceneOnly, [switch]$UVOnly, [switch]$Probes, [switch]$AssetTests)
$ErrorActionPreference = 'Stop'
$godot = 'H:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe'
$project = 'H:\game-workflow\work\environment_ruins'
$runStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$script:reviewIndex = 0
function Invoke-Review {
    param([string]$Scene, [string[]]$ReviewArgs)
    $script:reviewIndex += 1
    $log = Join-Path $project "quality_round/reviews_${runStamp}_$script:reviewIndex.log"
    & $godot --path $project --log-file $log $Scene -- @ReviewArgs
    if ($LASTEXITCODE -ne 0) { throw "Godot failed: $Scene" }
    if (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|SHADER ERROR|Shader compilation failed|ERROR:|Error compiling shader' -Quiet) {
        throw "Godot logged a script or shader error: $log"
    }
}
if ($AssetTests) { Invoke-Review -Scene 'res://quality_round/asset_test.tscn' -ReviewArgs @(); exit 0 }
function Invoke-UVReview {
    $argsUV = @('--capture','--checker','--prefix=stone_uv','--tree=res://meshy_assets/stone_plain.glb','--shrub=res://quality_assets/stone_plain_reuv.glb','--slab=res://meshy_assets/pilot_slab_v2.glb')
    Invoke-Review -Scene 'res://quality_asset_review.tscn' -ReviewArgs $argsUV
}
if ($UVOnly) { Invoke-UVReview; exit 0 }
if ($Probes) {
    Invoke-Review -Scene 'res://quality_round.tscn' -ReviewArgs @('--quality-top','--probe=shadowsoff','--no-shadows')
    Invoke-Review -Scene 'res://quality_round.tscn' -ReviewArgs @('--quality-top','--probe=normalsoff','--no-legacy-normal')
    Invoke-Review -Scene 'res://quality_round.tscn' -ReviewArgs @('--quality-top','--probe=greyold','--grey-old')
    exit 0
}
if ($Assets) {
    foreach ($asset in @('fern','shrub')) {
        $folder = if ($asset -eq 'fern') { 'fern/01a190a5-3f89-77c2-a12f-512d70b45526' } else { 'pilot_shrub/01a19080-9f31-765f-bef5-29843cbe99b8' }
        $current = if ($asset -eq 'fern') { 'fern_lod2' } else { 'shrub_lod2' }
        $assetArgs = @("--tree=H:/game-workflow/work/environment_ruins/meshy_plan_b/assets/$folder/asset_model_url.glb", "--shrub=res://meshy_assets/$current.glb", "--slab=res://quality_assets/${asset}_repaired.glb")
        Invoke-Review -Scene 'res://quality_asset_review.tscn' -ReviewArgs (@('--capture','--side','--grey',"--prefix=${asset}_low_grey") + $assetArgs)
        Invoke-Review -Scene 'res://quality_asset_review.tscn' -ReviewArgs (@('--capture','--side',"--prefix=${asset}_low_textured") + $assetArgs)
    }
    Invoke-UVReview
} else {
    if (-not $SceneOnly) {
        foreach ($feature in @('lighting','materials','layout','assets','render')) {
            Invoke-Review -Scene 'res://quality_round.tscn' -ReviewArgs @('--quality-top',"--diagnostic=$feature")
        }
    }
    foreach ($view in @('top','side','close')) {
        Invoke-Review -Scene 'res://quality_round.tscn' -ReviewArgs @("--quality-$view")
    }
    Invoke-Review -Scene 'res://quality_round.tscn' -ReviewArgs @('--quality-benchmark')
    Invoke-UVReview
    Invoke-Review -Scene 'res://quality_round/asset_test.tscn' -ReviewArgs @()
}
