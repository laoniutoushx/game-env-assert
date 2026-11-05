"""Decode every accepted MP4 and check that all consecutive native frames survived encoding."""
from pathlib import Path
import json,re,subprocess
from PIL import Image

root=Path(__file__).resolve().parent;captures=root/'captures'
ffmpeg=next((root/'tools').rglob('ffmpeg*.exe'));results={}
for mode in ['baseline','combined']:
    for clip in ['static','wind','pan','lod','orbit']:
        stem=f'{mode}_{clip}_sequence';folder=captures/stem
        expected=300 if clip in ['static','wind'] else 600
        with Image.open(folder/'0000.jpg') as image:assert image.size==(2560,1440)
        run=subprocess.run([str(ffmpeg),'-hide_banner','-v','error','-threads','2','-i',str(captures/(stem+'.mp4')),'-map','0:v:0','-an','-nostats','-progress','pipe:1','-f','null','-'],capture_output=True,text=True,check=True)
        assert not run.stderr.strip(),run.stderr
        frames=max(map(int,re.findall(r'^frame=(\d+)\s*$',run.stdout,re.M)))
        duration=max(map(int,re.findall(r'^out_time_us=(\d+)\s*$',run.stdout,re.M)))/1e6
        assert frames==expected,(stem,frames,expected)
        assert abs(duration-expected/30)<.1,(stem,duration)
        results[stem]={'decoded_frames':frames,'duration_seconds':duration,'first_native_frame':[2560,1440],'decode_errors':0}
        print(stem,frames,flush=True)
(root/'video_validation.json').write_text(json.dumps({'videos':results,'decoded_frames':sum(x['decoded_frames'] for x in results.values())},indent=2),encoding='utf-8')
