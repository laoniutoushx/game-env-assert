"""Isolated environment-asset Meshy ledger. Never repeat an uncertain POST."""
import argparse
import datetime as dt
import hashlib
import json
import re
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from pipeline import meshy

BASE = Path(__file__).resolve().parent / 'meshy_plan_b'
DB = BASE / 'ledger.sqlite3'
ENDPOINT = '/openapi/v1/image-to-3d'
PRICE = 30
LIMIT = 800

def now():
    return dt.datetime.now(dt.timezone.utc).isoformat()

def connect():
    BASE.mkdir(exist_ok=True)
    db = sqlite3.connect(DB, timeout=30)
    db.execute('PRAGMA journal_mode=WAL')
    db.execute('CREATE TABLE IF NOT EXISTS tasks (id INTEGER PRIMARY KEY, asset TEXT NOT NULL, image TEXT NOT NULL, image_sha256 TEXT NOT NULL, parameters TEXT NOT NULL, created TEXT NOT NULL, status TEXT NOT NULL, remote_id TEXT, reserved INTEGER NOT NULL, actual INTEGER, result TEXT)')
    db.commit()
    return db

def submit(asset, image):
    if not re.fullmatch(r'[a-z][a-z0-9_]{0,63}', asset):
        raise ValueError('Asset name must be a simple lowercase identifier')
    if asset not in {'pilot_tree','pilot_shrub','pilot_slab'}:
        gate = BASE / 'pilot_review.json'
        if not gate.is_file() or json.loads(gate.read_text(encoding='utf-8')).get('all_passed') is not True:
            raise RuntimeError('Later assets are blocked until all three pilots pass visual and Godot camera review')
    image = Path(image).absolute()
    data = meshy.data_uri(image)
    digest = hashlib.sha256(image.read_bytes()).hexdigest()
    params = {'ai_model':'meshy-7.1','geometry_resolution':'standard','image_enhancement':False,'remove_lighting':True,'should_texture':True,'enable_pbr':True,'texture_resolution':'4k','should_remesh':False,'target_formats':['glb']}
    db = connect()
    db.execute('BEGIN IMMEDIATE')
    spent = db.execute("SELECT COALESCE(SUM(CASE WHEN status='REJECTED' THEN COALESCE(actual,0) ELSE MAX(COALESCE(actual,0),reserved) END),0) FROM tasks").fetchone()[0]
    attempts = db.execute("SELECT COUNT(*) FROM tasks WHERE asset=? AND status != 'REJECTED'", (asset,)).fetchone()[0]
    unresolved = db.execute("SELECT COUNT(*) FROM tasks WHERE status IN ('SUBMITTING','UNCERTAIN')").fetchone()[0]
    if unresolved or spent + PRICE > LIMIT or attempts >= 3:
        db.rollback()
        raise RuntimeError(f'Submission blocked: unresolved={unresolved}, committed={spent}, attempts={attempts}')
    cur = db.execute('INSERT INTO tasks(asset,image,image_sha256,parameters,created,status,reserved) VALUES(?,?,?,?,?,?,?)', (asset,str(image),digest,json.dumps(params),now(),'SUBMITTING',PRICE))
    rowid = cur.lastrowid
    db.commit()
    try:
        payload = dict(params, image_url=data)
        response = meshy.request('POST', ENDPOINT, payload)
        task_id = response['result']
    except meshy.MeshyHTTPError as exc:
        status = 'REJECTED' if exc.status in (400,401,402,403,404,413,422,429) else 'UNCERTAIN'
        db.execute('UPDATE tasks SET status=?,actual=? WHERE id=?', (status,0 if status == 'REJECTED' else None,rowid))
        db.commit()
        raise
    except Exception:
        db.execute("UPDATE tasks SET status='UNCERTAIN' WHERE id=?",(rowid,))
        db.commit()
        raise
    db.execute("UPDATE tasks SET status='PENDING',remote_id=? WHERE id=?",(task_id,rowid))
    db.commit()
    print(json.dumps({'asset':asset,'task_id':task_id,'reserved':PRICE}))

def poll():
    db=connect()
    for rowid,asset,remote_id in db.execute("SELECT id,asset,remote_id FROM tasks WHERE remote_id IS NOT NULL AND status NOT IN ('ARCHIVED','REJECTED')").fetchall():
        response=meshy.request('GET',ENDPOINT+'/'+remote_id)
        status=response.get('status','UNKNOWN')
        actual=response.get('consumed_credits')
        if not isinstance(actual,(int,float)): actual=None
        db.execute('UPDATE tasks SET status=?,actual=?,result=? WHERE id=?',(status,actual,json.dumps(response),rowid))
        db.commit()
        if status == 'SUCCEEDED':
            folder=BASE/'assets'/asset/remote_id
            folder.mkdir(parents=True,exist_ok=True)
            saved=[]
            downloaded_urls={}
            for name,suffix,url in meshy.urls(response):
                if url in downloaded_urls:
                    continue
                dest=folder/(name+suffix)
                if dest.exists():
                    saved.append({'file':str(dest),'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'bytes':dest.stat().st_size})
                else:
                    saved.append(meshy.download(url,dest))
                downloaded_urls[url] = dest
            (folder/'archive.json').write_text(json.dumps({'task_id':remote_id,'saved':saved},indent=2),encoding='utf-8')
            if not any(x['file'].endswith('.glb') for x in saved): raise RuntimeError('Successful task has no downloaded GLB')
            db.execute("UPDATE tasks SET status='ARCHIVED' WHERE id=?",(rowid,))
            db.commit()
            status='ARCHIVED'
        print(json.dumps({'asset':asset,'task_id':remote_id,'status':status,'actual':actual}))

def status():
    db=connect()
    rows=db.execute('SELECT asset,status,remote_id,reserved,actual FROM tasks').fetchall()
    print(json.dumps({'limit':LIMIT,'committed':sum((r[4] or 0) if r[1] == 'REJECTED' else max(r[4] or 0,r[3]) for r in rows),'tasks':rows},ensure_ascii=False,indent=2))

if __name__ == '__main__':
    p=argparse.ArgumentParser()
    p.add_argument('action',choices=['submit','poll','status'])
    p.add_argument('--asset')
    p.add_argument('--image')
    args=p.parse_args()
    if args.action == 'submit':
        if not args.asset or not args.image: p.error('submit requires --asset and --image')
        submit(args.asset,args.image)
    elif args.action == 'poll': poll()
    else: status()
