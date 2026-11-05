"""Fetch the local-only FFmpeg wheel used for continuous-frame MP4 evidence."""
from pathlib import Path
import subprocess,sys,zipfile

tools=Path(__file__).resolve().parent/'tools';tools.mkdir(exist_ok=True)
if not list(tools.rglob('ffmpeg*.exe')):
    subprocess.run([sys.executable,'-m','pip','download','--no-deps','imageio-ffmpeg==0.8.1','--dest',str(tools)],check=True)
    destination=(tools/'ffmpeg').resolve()
    for wheel in tools.glob('imageio_ffmpeg*.whl'):
        with zipfile.ZipFile(wheel) as archive:
            for name in archive.namelist():
                if not (destination/name).resolve().is_relative_to(destination):raise ValueError('Invalid archive path')
            archive.extractall(destination)
print(next(tools.rglob('ffmpeg*.exe')))
