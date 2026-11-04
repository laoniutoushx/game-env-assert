import asyncio,json,os,sys
from pathlib import Path
from datetime import timedelta
from mcp import ClientSession,StdioServerParameters
from mcp.client.stdio import stdio_client

async def run():
    root=Path(__file__).resolve().parent
    env=dict(os.environ,BLENDER_HOST='127.0.0.1',BLENDER_PORT='9877',DISABLE_TELEMETRY='true')
    params=StdioServerParameters(command=str(root/'venv/Scripts/mcp-for-blender.exe'),env=env)
    async with stdio_client(params) as (read,write):
        async with ClientSession(read,write,read_timeout_seconds=timedelta(seconds=600)) as session:
            await session.initialize()
            if len(sys.argv)>1:
                code=Path(sys.argv[1]).read_text(encoding='utf-8-sig')
                result=await session.call_tool('execute_blender_code',{'code':code,'user_prompt':'Implement the plan.'})
            else:
                listing=await session.list_tools()
                print('MCP_TOOLS',','.join(t.name for t in listing.tools))
                result=await session.call_tool('get_scene_info',{})
            print(result.model_dump_json(),flush=True)
            response=result.model_dump_json()
            if result.isError or 'Error executing code:' in response or 'Rejected by safe mode' in response:
                raise RuntimeError('Blender MCP operation failed')
asyncio.run(run())
