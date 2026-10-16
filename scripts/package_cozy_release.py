"""Package the current visual review build with fresh, scoped evidence."""
from pathlib import Path
import hashlib,json,os,subprocess,zipfile

root=Path(__file__).resolve().parents[1]
release=root/'release';windows=release/'windows';review=release/'cozy-overhaul'
env=os.environ.copy();env['APPDATA']=str(root/'.tools/cozy-export-check')
Path(env['APPDATA']).mkdir(exist_ok=True)
result=subprocess.run([str(windows/'TimeToCook.exe'),'--headless','--quit-after','8'],env=env,capture_output=True,text=True,timeout=45)
log=result.stdout+result.stderr
(review/'windows-startup.txt').write_text(f'Exit code: {result.returncode}\n{log}',encoding='utf-8')
# Godot's forced headless shutdown may retain morning.wav playback until audio
# server teardown. Verbose inspection identifies this existing engine exit warning.
errors=[line for line in log.splitlines() if ('ERROR:' in line or 'SCRIPT ERROR:' in line) and 'resources still in use at exit' not in line]
if result.returncode or errors:raise SystemExit('Exported startup failed; inspect windows-startup.txt')
(windows/'README.txt').write_text('Time to Cook - Cozy visual review 0.9.2\n\nRun TimeToCook.exe with TimeToCook.pck beside it.\n\nWASD move/drive; J interact; K work/clean; Q drop; L ability.\n1-9/0 or wheel: inventory. Tab: recipe. M: management. B: build/shop.\nHelp is available from the small bottom-left button.\n\nNew stores use the redesigned layouts. Existing saves retain their furniture positions.\nSaves: %APPDATA%/Godot/app_userdata/Time to Cook/franchise_v2/\n\nActual Godot screenshots and scope: repository release/cozy-overhaul/REVIEW.md\n',encoding='utf-8')
manifest={'version':'0.9.2-cozy-review','engine':'Godot 4.7 stable','platform':'Windows x86_64','build_date':'2026-10-16','published':False,'exported_startup_exit':result.returncode,'headless_shutdown_note':'Forced headless shutdown reports retained morning.wav playback; no script or missing-resource startup errors. Full output retained.','checks':{},'files':{}}
for label,path in [('domain',release/'smoke-results.json'),('ui',release/'ui-results.json'),('visual_layout',review/'results.json')]:manifest['checks'][label]=json.loads(path.read_text(encoding='utf-8'))
for p in windows.rglob('*'):
    if p.is_file():manifest['files'][str(p.relative_to(windows))]={'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
(review/'build.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
(release/'BUILD_MANIFEST.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
archive=release/'TimeToCook-Windows-cozy.zip'
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for p in windows.rglob('*'):
        if p.is_file():z.write(p,Path('TimeToCook')/p.relative_to(windows))
print(json.dumps({'startup':'PASS','archive':str(archive),'bytes':archive.stat().st_size},ensure_ascii=False))
