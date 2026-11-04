$ErrorActionPreference='Stop'
$perf=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'last_Perf.json') -Raw|ConvertFrom-Json
if(-not $perf.success){throw 'Two valid performance runs required'}
foreach($phase in @('Coverage','Final','Motion','Compare','Diagnostics','Smoke')){
    & (Join-Path $PSScriptRoot 'run_reviews.ps1') -Round $phase
    if($LASTEXITCODE -ne 0){throw "Phase failed: $phase"}
    if($phase -eq 'Coverage'){
        & python (Join-Path $PSScriptRoot 'check_coverage.py')
        if($LASTEXITCODE -ne 0){throw 'Foliage occlusion gate failed'}
    }
}
$projectFile=Join-Path (Split-Path $PSScriptRoot -Parent) 'project.godot'
$oldProject=Get-Content -LiteralPath $projectFile -Raw
try{
    Set-Content -LiteralPath $projectFile -Value $oldProject.Replace('run/main_scene="res://afternoon.tscn"','run/main_scene="res://afternoon_v2.tscn"') -Encoding utf8
    & python (Join-Path $PSScriptRoot 'build_review.py')
    if($LASTEXITCODE -ne 0){throw 'Artifact validation failed'}
}catch{
    Set-Content -LiteralPath $projectFile -Value $oldProject -Encoding utf8
    throw
}
