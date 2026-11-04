$ErrorActionPreference = 'Stop'
foreach ($assetId in @('tree_small_02', 'shrub_02')) {
    $root = Join-Path $PSScriptRoot $assetId
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    $manifestPath = Join-Path $root 'source_manifest.json'
    Invoke-WebRequest -Uri "https://api.polyhaven.com/files/$assetId" -OutFile $manifestPath -TimeoutSec 60
    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    $model = $manifest.gltf.'1k'.gltf
    $files = @(@{ Name = "${assetId}_1k.gltf"; Data = $model })
    foreach ($entry in $model.include.PSObject.Properties) {
        $files += @{ Name = $entry.Name; Data = $entry.Value }
    }
    foreach ($entry in $manifest.PSObject.Properties) {
        if ($entry.Name -match '(?i)alpha' -and $entry.Value.'1k'.png) {
            $alpha = $entry.Value.'1k'.png
            $files += @{ Name = "textures/$($entry.Name)_alpha_source.png"; Data = $alpha }
        }
    }
    foreach ($entry in $files) {
        $destination = Join-Path $root $entry.Name
        New-Item -ItemType Directory -Force -Path (Split-Path $destination) | Out-Null
        Invoke-WebRequest -Uri $entry.Data.url -OutFile $destination -TimeoutSec 120
        $hash = (Get-FileHash -LiteralPath $destination -Algorithm MD5).Hash.ToLowerInvariant()
        if ($hash -ne $entry.Data.md5) { throw "Hash mismatch: $assetId/$($entry.Name)" }
        Write-Output "Verified $assetId/$($entry.Name): $hash"
    }
}
