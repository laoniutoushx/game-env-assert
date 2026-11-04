$ErrorActionPreference = 'Stop'
$root = Join-Path $PSScriptRoot 'fern_02'
New-Item -ItemType Directory -Force -Path $root | Out-Null
$manifest = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'fern_source_manifest.json') | ConvertFrom-Json
$model = $manifest.gltf.'2k'.gltf
$files = @(@{ Name = 'fern_02_2k.gltf'; Data = $model })
foreach ($entry in $model.include.PSObject.Properties) {
    $files += @{ Name = $entry.Name; Data = $entry.Value }
}
foreach ($entry in $files) {
    $destination = Join-Path $root $entry.Name
    New-Item -ItemType Directory -Force -Path (Split-Path $destination) | Out-Null
    Invoke-WebRequest -Uri $entry.Data.url -OutFile $destination -TimeoutSec 90
    $hash = (Get-FileHash -LiteralPath $destination -Algorithm MD5).Hash.ToLowerInvariant()
    if ($hash -ne $entry.Data.md5) { throw "Hash mismatch: $($entry.Name)" }
    Write-Output "Verified $($entry.Name): $hash"
}
