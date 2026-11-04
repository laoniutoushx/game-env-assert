import importlib.util, os
from pathlib import Path
import bpy
root=Path(__file__).resolve().parent
os.environ['DISABLE_TELEMETRY']='true'
spec=importlib.util.spec_from_file_location('model_v3_blender_bridge',root/'mcp-for-blender/addon.py')
addon=importlib.util.module_from_spec(spec)
spec.loader.exec_module(addon)
addon.register()
bridge=addon.BlenderMCPServer(host='127.0.0.1',port=9877)
bridge.start()
bpy.app.driver_namespace['model_v3_bridge']=bridge
print('MODEL_V3_BLENDER_BRIDGE_READY',bpy.app.version_string,flush=True)
