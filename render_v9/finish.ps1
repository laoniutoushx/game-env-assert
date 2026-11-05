$ErrorActionPreference='Stop'
foreach($stage in @('TemporalRest','Cases','Perf','Final')){
 & (Join-Path $PSScriptRoot 'run_reviews.ps1') -Round $stage
}
$clips=@('static','wind','pan','lod','orbit')
foreach($mode in @('baseline','combined')){
 foreach($clip in $clips){
  python (Join-Path $PSScriptRoot 'analyze.py') "${mode}_${clip}_sequence" --encode
  if($LASTEXITCODE -ne 0){throw "Video/analysis failed: $mode $clip"}
 }
}
python (Join-Path $PSScriptRoot 'validate_videos.py')
if($LASTEXITCODE -ne 0){throw 'Video decode validation failed'}
python (Join-Path $PSScriptRoot 'finalize.py')
if($LASTEXITCODE -ne 0){throw 'V9 final validation failed'}
