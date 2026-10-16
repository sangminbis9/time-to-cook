from pathlib import Path
from PIL import Image, ImageOps
import json,hashlib,shutil,zipfile,subprocess,os
root=Path(__file__).resolve().parents[1]
release=root/'release'; windows=release/'windows'
screens=release/'screenshots'
sizes={}
for p in screens.glob('*.png'):
    with Image.open(p) as source:
        sizes[p.name]=list(source.size)
        # Preserve pixel-art content; standardize the Steam delivery canvas.
        if source.size!=(1920,1080):
            result=ImageOps.pad(source,(1920,1080),method=Image.Resampling.NEAREST,color='#f7efd9')
            result.save(p)
(screens/'provenance.json').write_text(json.dumps({'source':'Godot 4.7 OpenGL engine viewport, scripted gameplay capture','raw_dimensions':sizes,'delivery_dimensions':[1920,1080],'processing':'nearest-neighbor fit with minimal padding; no gameplay elements added or removed','title_is_not_gameplay':True},indent=2),encoding='utf-8')
shutil.copytree(release/'LICENSES',windows/'LICENSES',dirs_exist_ok=True)
(windows/'README.txt').write_text('Time to Cook - Windows review build\n\nRun TimeToCook.exe with TimeToCook.pck beside it.\n\nWASD: move/drive. J: interact. K: work/clean. Q: drop.\n1-9,0 or wheel: inventory. Tab: recipe. L: ability. M: management.\nB: construction, or grocery shopping inside the grocery store.\n\nNew game -> buy chicken, flour and containers -> Ready.\nUse the in-game Korean tutorial and help from Management / Records.\nCo-op uses direct IP over UDP 7777; host owns the save.\n\nSaves: %APPDATA%/Godot/app_userdata/Time to Cook/franchise_v2/\n\nThis is a human-review build. Long-term balance, WAN behavior and\nall supported PCs have not been certified. Nothing was uploaded to Steam.\nSee the repository release notes for known simplifications.\n',encoding='utf-8')
env=os.environ.copy();env['APPDATA']=str(root/'.tools/release-verify-user')
(root/'.tools/release-verify-user').mkdir(exist_ok=True)
result=subprocess.run([str(windows/'TimeToCook.exe'),'--headless','--quit-after','8'],env=env,capture_output=True,text=True,timeout=30)
(release/'windows-startup.txt').write_text(f'Exit code: {result.returncode}\n{result.stdout}\n{result.stderr}',encoding='utf-8')
errors=[line for line in (result.stdout+result.stderr).splitlines() if 'ERROR:' in line and 'resources still in use at exit' not in line]
if result.returncode or errors:raise SystemExit('Exported Windows startup failed: '+str(errors))
manifest={'version':'0.9.1-art-review','engine':'4.7.stable.official.5b4e0cb0f','platform':'Windows x86_64','build_date':'2026-10-16','published':False,'visual_results':json.loads((release/'visual-refresh/results.json').read_text(encoding='utf-8')),'files':{}}
for p in windows.rglob('*'):
    if p.is_file():manifest['files'][str(p.relative_to(windows))]={'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
for name in ['smoke-results','ui-results','ai-results','network-host','network-guest']:
    manifest[name]=json.loads((release/(name+'.json')).read_text(encoding='utf-8'))
(release/'BUILD_MANIFEST.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
archive=release/'TimeToCook-Windows-review.zip'
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for p in windows.rglob('*'):
        if p.is_file():z.write(p,Path('TimeToCook')/p.relative_to(windows))
print(json.dumps({'windows_startup_exit':result.returncode,'zip':str(archive),'zip_bytes':archive.stat().st_size,'screenshots':len(sizes)},ensure_ascii=False))
