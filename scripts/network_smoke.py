from pathlib import Path
import subprocess, os, time, json
root=Path(__file__).resolve().parents[1]
env=os.environ.copy(); env['APPDATA']=str(root/'.tools/rebuild-user')
exe=root/'.tools/godot/Godot_v4.7-stable_win64.exe'
procs=[]
for role in ['host','guest']:
    log=(root/f'.tools/network-{role}.log').open('w',encoding='utf-8')
    p=subprocess.Popen([str(exe),'--headless','--path',str(root/'game'),'--script','res://rebuild/network_smoke.gd','--','--'+role],env=env,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
    procs.append((role,p,log))
    if role=='host':time.sleep(1)
for role,p,log in procs:
    try:p.wait(timeout=40)
    except subprocess.TimeoutExpired:p.kill();p.wait()
    log.close()
    print(role, 'exit',p.returncode)
    print((root/f'.tools/network-{role}.log').read_text(encoding='utf-8')[-3000:])
