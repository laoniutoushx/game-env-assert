from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
out=root/'render_v4'
out.mkdir(exist_ok=True)
(out/'assets').mkdir(exist_ok=True)
(out/'captures').mkdir(exist_ok=True)
(out/'captures'/'.gdignore').touch()
settings=json.loads((root/'model_v3/settings.json').read_text(encoding='utf-8-sig'))
settings.update(sun_color='ffdfb7',sun_energy=1.95,fog_length=60)
(out/'settings.json').write_text(json.dumps(settings,indent=2),encoding='utf-8')
text=(root/'model_v3/export_lighting.gd').read_text(encoding='utf-8-sig').replace('res://model_v3/assets/','res://render_v4/assets/')
(out/'export_lighting.gd').write_text(text,encoding='utf-8')
text=(root/'model_v3/audit.gd').read_text(encoding='utf-8-sig').replace('res://model_v3/captures/','res://render_v4/captures/')
(out/'audit.gd').write_text(text,encoding='utf-8')
plugin=root/'addons/render_v4_bake';plugin.mkdir(exist_ok=True)
for file in ['plugin.gd','plugin.cfg']:
    text=(root/'addons/model_v3_bake'/file).read_text(encoding='utf-8-sig').replace('model_v3','render_v4').replace('--model-v3-bake','--render-v4-bake').replace('"look_version":3','"look_version":4')
    (plugin/file).write_text(text,encoding='utf-8')
print('V4_SCAFFOLD_READY')
