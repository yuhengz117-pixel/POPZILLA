#!/usr/bin/env python3
"""Build POPZILLA. --install replaces the installed app; --zip creates a sharing ZIP."""
from pathlib import Path
import argparse, os, shutil, subprocess, signal
root = Path(__file__).resolve().parent.parent
source = root / 'source'
cache = Path.home() / 'Library/Caches/POPZILLA-Build'
parser = argparse.ArgumentParser()
parser.add_argument('--install', action='store_true', help='Close POPZILLA and install; submit any input draft first.')
parser.add_argument('--zip', action='store_true', help='Create a fresh friend-testing ZIP.')
args = parser.parse_args()
def run(*command): subprocess.run(command, check=True)
env = dict(os.environ, DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer')
subprocess.run(['xcodebuild','-project',str(source/'PopDay.xcodeproj'),'-scheme','PopDay','-configuration','Release','-derivedDataPath',str(cache/'DerivedData'),'CODE_SIGNING_ALLOWED=NO','build'],env=env,check=True)
app = cache / 'POPZILLA.app'
if app.exists(): shutil.rmtree(app)
run('ditto',str(cache/'DerivedData/Build/Products/Release/PopDay.app'),str(app))
run('ditto',str(source/'PopDay/Planet'),str(app/'Contents/Resources/Planet'))
for file in app.rglob('*.dylib'): run('codesign','--force','--sign','-',str(file))
for widget in app.glob('Contents/PlugIns/*.appex'):
    run('codesign','--force','--sign','-','--entitlements',str(source/'PopDayWidget/PopDayWidget.entitlements'),str(widget))
run('codesign','--force','--sign','-','--entitlements',str(source/'PopDay/PopDay.entitlements'),str(app))
run('codesign','--verify','--deep','--strict',str(app))
if args.zip:
    package = cache/'share'
    if package.exists(): shutil.rmtree(package)
    package.mkdir()
    run('ditto',str(app),str(package/'POPZILLA.app'))
    shutil.copy2(root/'outputs/朋友安装说明.md',package/'安装说明.md')
    run('ditto','-c','-k','--sequesterRsrc','--keepParent',str(package),str(root/'outputs/POPZILLA-朋友测试版.zip'))
if args.install:
    result = subprocess.run(['pgrep','-x','PopDay'],capture_output=True,text=True)
    for pid in result.stdout.split(): os.kill(int(pid),signal.SIGTERM)
    import time
    time.sleep(1)
    target = Path('/Applications/POPZILLA.app')
    stage = Path('/Applications/.POPZILLA-updating.app')
    backup = cache/'previous.app'
    if stage.exists(): shutil.rmtree(stage)
    run('ditto',str(app),str(stage))
    run('codesign','--verify','--deep','--strict',str(stage))
    if backup.exists(): shutil.rmtree(backup)
    if target.exists(): shutil.move(str(target),str(backup))
    try:
        stage.rename(target)
        run('codesign','--verify','--deep','--strict',str(target))
    except Exception:
        if target.exists(): shutil.rmtree(target)
        if backup.exists(): shutil.move(str(backup),str(target))
        raise
    if backup.exists(): shutil.rmtree(backup)
    print('Installed /Applications/POPZILLA.app. Open it from Finder.')
else: print('Built:',app)
