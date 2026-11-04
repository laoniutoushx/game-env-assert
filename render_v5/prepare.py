from pathlib import Path
root=Path(__file__).resolve().parents[1];out=root/'render_v5'
(out/'captures').mkdir(exist_ok=True);(out/'captures/.gdignore').touch()
text=(root/'model_v3/model_foliage.gdshader').read_text(encoding='utf-8-sig').replace('BACKLIGHT=ALBEDO*0.22*leaf','BACKLIGHT=ALBEDO*0.36*leaf')
(out/'model_foliage.gdshader').write_text(text,encoding='utf-8')
text=(root/'model_v3/study_foliage.gdshader').read_text(encoding='utf-8-sig').replace('BACKLIGHT = ALBEDO*leaf*0.30','BACKLIGHT = ALBEDO*leaf*0.42').replace('AO = mix(1.0,source_ao,0.65)','AO = mix(1.0,source_ao,0.50)')
(out/'foliage.gdshader').write_text(text,encoding='utf-8')
text=(root/'render_v4/audit.gd').read_text(encoding='utf-8-sig').replace('res://render_v4/captures/','res://render_v5/captures/')
(out/'audit.gd').write_text(text,encoding='utf-8')
print('V5_PREPARED_WITHOUT_EDITING_V4')
