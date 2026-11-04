from pathlib import Path
import json,html
p=Path(__file__).resolve().parent
assets=json.loads((p/'assets/catalog.json').read_text())['adopted_scenes']
gallery=''.join(f'<figure><a href="assets/{a}"><img loading="lazy" src="captures/assets/{a}.png"></a><figcaption>{a}</figcaption></figure>' for a in assets)
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>森林场景 · Godot 独立验收</title>
<style>body{background:#111713;color:#e0e7df;font:16px system-ui;margin:24px}a{color:#b2dca3}button,select,input{margin:6px;padding:6px;background:#25352a;color:white;border:1px solid #627763}h1{font-size:25px}p{max-width:1100px;line-height:1.6}.viewport{overflow:auto;max-height:82vh;border:1px solid #52634f}.canvas{position:relative;width:2560px;height:1440px;transform-origin:top left}.canvas img{position:absolute;width:2560px;height:1440px;max-width:none}.before{clip-path:inset(0 50% 0 0)}.line{position:absolute;left:50%;height:100%;border-left:2px solid white}.gallery{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:16px}figure{margin:0}figure img{width:100%;background:#24322c}figcaption{padding:8px;overflow-wrap:anywhere}#plain{display:none;width:2560px;max-width:none}small{color:#b3c2b2}</style>
<h1>森林场景 · 本轮实现与验收</h1><p>真实 Godot Forward+ 渲染。默认透视 35° / 俯角 55°，原生 2K + 4×MSAA。P95 33.097 ms（RTX 3060，600 帧），性能余量有限。<b>尚未认定达到 90% 还原度。</b></p>
<p><a href="report.md">根源、实施与剩余差距</a> · <a href="../../../reference_pic/Gemini_Generated_Image_vu1s3vu1s3vu1s3v.jpg">原始概念图</a> · <a href="captures/final_benchmark.json">性能</a> · <a href="captures/coverage.json">覆盖率</a> · <a href="validation.json">交付检查</a> · <a href="source_catalog.json">来源</a></p>
<label>视图 <select id="view"><option value="compare">同机位前后拖动对比（左基线 / 右最终）</option><option value="final_top.png">最终主视角</option><option value="final_side.png">侧俯视</option><option value="final_close.png">局部近景</option><option value="final_ortho_top.png">正交对照</option><option value="slice_base_top.png">局部 1 · 原资产</option><option value="slice_layout_top.png">局部 2 · 地形与植被</option><option value="slice_surface_top.png">局部 3 · 材质</option><option value="slice_final_top.png">局部 4 · 最终</option><option value="motion">移动相机 · 风动开</option><option value="frozen">移动相机 · 风动关</option></select></label>
<button id="native">100% 像素</button><button id="fit">适应窗口</button><label>对比 <input id="wipe" type="range" min="0" max="100" value="50"></label><label>相机帧 <input id="frame" type="range" min="0" max="47" value="0"></label><button id="play">播放 / 暂停</button><span id="status"></span>
<div class="viewport" id="viewport"><div class="canvas" id="canvas"><div id="comparison"><img src="captures/final_top.png"><img class="before" id="before" src="captures/baseline_top.png"><div class="line" id="line"></div></div><img id="plain"></div></div>
<p><small>100% 按设备像素比校准；适应窗口会缩小图片。48 帧相机序列用于观察空间、遮挡和 LOD，不代表运行帧率。实际运行：右键旋转、WASD 平移、滚轮缩放、R 复位、F1/F2 画质、F3 投影、F4 侧面检查、F5 风动。</small></p>
<h2>新增可复用资产 · 12 项独立渲染</h2><p>点击预览链接到对应 Godot 场景文件。刻字为高度视差 / 法线细节；树木三档均为空间几何。</p><div class="gallery">GALLERY</div>
<script>
const $=id=>document.getElementById(id);let fit=true,timer=null;
function scale(){let s=fit?($('viewport').clientWidth/2560):(1/devicePixelRatio);$('canvas').style.transform=`scale(${s})`;$('viewport').style.height=Math.min(1440*s,innerHeight*.82)+'px';$('canvas').style.marginBottom=(1440*(s-1))+'px'}
function render(){let v=$('view').value,m=v==='motion'||v==='frozen';$('comparison').style.display=v==='compare'?'block':'none';$('plain').style.display=v==='compare'?'none':'block';if(v!=='compare')$('plain').src=m?`captures/${v==='motion'?'final':'frozen'}_motion/${String($('frame').value).padStart(3,'0')}.png`:'captures/'+v;$('status').textContent=m?`${Number($('frame').value)+1}/48`:''}
$('view').onchange=render;$('frame').oninput=render;$('wipe').oninput=()=>{let x=$('wipe').value;$('before').style.clipPath=`inset(0 ${100-x}% 0 0)`;$('line').style.left=x+'%'};$('native').onclick=()=>{fit=false;scale()};$('fit').onclick=()=>{fit=true;scale()};$('play').onclick=()=>{if(timer){clearInterval(timer);timer=null}else{if(!['motion','frozen'].includes($('view').value))$('view').value='motion';timer=setInterval(()=>{$('frame').value=(Number($('frame').value)+1)%48;render()},180)}};onresize=scale;scale();render();
</script></html>'''
page=page.replace('GALLERY',gallery)
perf=json.loads((p/'captures/final_benchmark.json').read_text())
page=page.replace('33.097',f"{perf['p95_ms']:.3f}")
for stage in ('base','layout','surface','final'):
    page=page.replace(f'slice_{stage}_top.png',f'slice_{stage}_slice.png')
(p/'review.html').write_text(page,encoding='utf-8')
print('REVIEW_BUILT',len(assets))
