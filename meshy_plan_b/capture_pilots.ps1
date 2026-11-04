param([switch]$SceneOnly)
$ErrorActionPreference = 'Stop'
$godot = 'H:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe'
$project = 'H:\game-workflow\work\environment_ruins'
$assetArgs = @('--tree=res://meshy_assets/pilot_tree.glb', '--shrub=res://meshy_assets/pilot_shrub.glb', '--slab=res://meshy_assets/pilot_slab_v2.glb')
if (-not $SceneOnly) {
foreach ($view in @('top', 'side')) {
    $side = @()
    if ($view -eq 'side') { $side = @('--side') }
    & $godot --path $project res://meshy_pilot_review.tscn -- --capture @side @assetArgs
    if ($LASTEXITCODE -ne 0) { throw "Godot overview capture failed: $view" }
    foreach ($focus in @('tree', 'shrub', 'slab')) {
        & $godot --path $project res://meshy_pilot_review.tscn -- --capture @side "--focus-$focus" @assetArgs
        if ($LASTEXITCODE -ne 0) { throw "Godot focused capture failed: $view $focus" }
    }
}
& $godot --path $project res://meshy_pilot_review.tscn -- --capture --side --back @assetArgs
if ($LASTEXITCODE -ne 0) { throw 'Godot back capture failed' }
}
foreach ($view in @('top', 'side')) {
    & $godot --path $project res://meshy_trial.tscn -- "--meshy-$view"
    if ($LASTEXITCODE -ne 0) { throw "Godot scene capture failed: $view" }
}
& $godot --path $project res://meshy_trial.tscn -- --meshy-benchmark
if ($LASTEXITCODE -ne 0) { throw 'Godot orbit benchmark failed' }
if (-not $SceneOnly) {
$otherArgs = @('--tree=res://meshy_assets/broadleaf_tree.glb', '--shrub=res://meshy_assets/fern_lod1.glb', '--slab=res://meshy_assets/flowers_lod1.glb', '--prefix=other')
foreach ($view in @('--side', '--back')) {
    & $godot --path $project res://meshy_pilot_review.tscn -- --capture $view @otherArgs
    if ($LASTEXITCODE -ne 0) { throw "Additional asset view failed: $view" }
}
$grassArgs = @('--tree=res://meshy_assets/broadleaf_tree.glb', '--shrub=res://meshy_assets/grass_lod2.glb', '--slab=res://meshy_assets/flowers_lod2.glb', '--prefix=grass')
& $godot --path $project res://meshy_pilot_review.tscn -- --capture --side --back @grassArgs
if ($LASTEXITCODE -ne 0) { throw 'Grass back view failed' }
}
