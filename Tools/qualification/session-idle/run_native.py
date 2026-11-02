#!/usr/bin/env python3
"""Build/run the actual shared native component on disposable iPhone/iPad simulators.
Requires --output-root in external task storage. No physical installs or HA traffic.
"""
import argparse, json, os, signal, subprocess, time
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--output-root', type=Path, required=True)
parser.add_argument('--jose-checkout', type=Path, required=True)
parser.add_argument('--derived-data', type=Path)
parser.add_argument('--only-testing')
parser.add_argument('--device', choices=['iphone','ipad'])
parser.add_argument('--project-root', type=Path)
args = parser.parse_args()
root = args.output_root.resolve(); root.mkdir(parents=True, exist_ok=False)
repo = Path(__file__).resolve().parents[3]
(root/'tmp').mkdir(); env = os.environ.copy(); env['TMPDIR'] = str(root/'tmp')
jose = args.jose_checkout.resolve()
if not jose.is_dir(): raise SystemExit('Provide the qualified local JOSESwift checkout')
settings = {'SWIFT_VERSION':'6.0','CODE_SIGNING_ALLOWED':'NO','GENERATE_INFOPLIST_FILE':'YES','ENABLE_TESTABILITY':'YES'}
def target(kind, name, sources, dependencies):
    return {'type':kind,'platform':'iOS','sources':[{'path':str(p)} for p in sources],
            'dependencies':dependencies,'settings':{'base':dict(settings, PRODUCT_BUNDLE_IDENTIFIER='dev.djconnect.qualification.idle.'+name)}}
core = target('framework','core',[repo/'Sources/DJConnectCore'],[{'package':'JOSESwift'}]); core['settings']['base'].update(PRODUCT_NAME='DJConnectCore',PRODUCT_MODULE_NAME='DJConnectCore')
ui = target('framework','ui',[repo/'Sources/DJConnectUI'],[{'target':'IdleCore'}]); ui['settings']['base'].update(PRODUCT_NAME='DJConnectUI',PRODUCT_MODULE_NAME='DJConnectUI')
host = target('application','host',[Path(__file__).parent/'NativeSessionIdleHost.swift'],[{'target':'IdleUI'},{'target':'IdleCore'}]);host['settings']['base'].update(INFOPLIST_KEY_UILaunchScreen_Generation='YES',INFOPLIST_KEY_UIApplicationSceneManifest_Generation='YES',INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad='UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight',INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone='UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight')
test = target('bundle.ui-testing','tests',[Path(__file__).parent/'NativeSessionIdleUITests.swift'],[{'target':'NativeSessionIdleHost'}])
project = {'name':'NativeSessionIdleQualification','options':{'deploymentTarget':{'iOS':'26.0'}},'packages':{'JOSESwift':{'path':str(jose)}},'targets':{'IdleCore':core,'IdleUI':ui,'NativeSessionIdleHost':host,'NativeSessionIdleUITests':test},'schemes':{'NativeSessionIdle':{'build':{'targets':{'NativeSessionIdleHost':'all','NativeSessionIdleUITests':'all'}},'test':{'targets':['NativeSessionIdleUITests']}}}}
project_root = (args.project_root or root).resolve()
project_root.mkdir(parents=True, exist_ok=True)
(project_root/'project.json').write_text(json.dumps(project,indent=2))
subprocess.run(['xcodegen','generate','--spec',str(project_root/'project.json'),'--project',str(project_root)],check=True,env=env)
records=[]
for label, kind in [('iphone','iPhone-17-Pro'),('ipad','iPad-Pro-13-inch-M5-12GB')]:
    if args.device and label != args.device: continue
    device = subprocess.check_output(['xcrun','simctl','create','DJConnect-Idle-'+label,'com.apple.CoreSimulator.SimDeviceType.'+kind,'com.apple.CoreSimulator.SimRuntime.iOS-27-0'],text=True,env=env).strip()
    record={'label':label,'device':device}; records.append(record)
    try:
        subprocess.run(['xcrun','simctl','boot',device],check=True,env=env)
        subprocess.run(['xcrun','simctl','bootstatus',device,'-b'],check=True,env=env,stdout=subprocess.DEVNULL)
        base=['xcodebuild','-project',str(project_root/'NativeSessionIdleQualification.xcodeproj'),'-scheme','NativeSessionIdle','-destination','platform=iOS Simulator,id='+device,'-derivedDataPath',str((args.derived_data or root/'DerivedData').resolve()),'-parallel-testing-enabled','NO','-collect-test-diagnostics','never','CODE_SIGNING_ALLOWED=NO']
        with (root/(label+'-build.log')).open('w') as log: record['build_exit']=subprocess.run(base+['build-for-testing'],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=900).returncode
        if record['build_exit']!=0: raise RuntimeError('Native build failed')
        app=(args.derived_data or root/'DerivedData').resolve()/'Build/Products/Debug-iphonesimulator/NativeSessionIdleHost.app'
        subprocess.run(['xcrun','simctl','install',device,str(app)],check=True,env=env)
        video=subprocess.Popen(['xcrun','simctl','io',device,'recordVideo','--codec=h264',str(root/(label+'-idle-moment-idle.mov'))],env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        try:
            subprocess.run(['xcrun','simctl','launch',device,'dev.djconnect.qualification.idle.host','--record-cycle'],check=True,env=env)
            time.sleep(1)
            subprocess.run(['xcrun','simctl','io',device,'screenshot',str(root/(label+'-idle.png'))],check=True,env=env,stdout=subprocess.DEVNULL)
            time.sleep(2)
            subprocess.run(['xcrun','simctl','io',device,'screenshot',str(root/(label+'-moment.png'))],check=True,env=env,stdout=subprocess.DEVNULL)
            time.sleep(4)
        finally:
            video.send_signal(signal.SIGINT); video.wait(timeout=15)
            subprocess.run(['xcrun','simctl','terminate',device,'dev.djconnect.qualification.idle.host'],env=env,stdout=subprocess.DEVNULL)
        with (root/(label+'-test.log')).open('w') as log: record['test_exit']=subprocess.run(base+['test-without-building','-resultBundlePath',str(root/(label+'.xcresult'))]+(['-only-testing:NativeSessionIdleUITests/NativeSessionIdleUITests/'+args.only_testing] if args.only_testing else []),env=env,stdout=log,stderr=subprocess.STDOUT,timeout=900).returncode
    except Exception as error:
        record['error']=str(error)
    finally:
        subprocess.run(['xcrun','simctl','shutdown',device],env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        record['delete_exit']=subprocess.run(['xcrun','simctl','delete',device],env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode
        (root/'results.json').write_text(json.dumps(records,indent=2)+'\n')
    print(label,record,flush=True)
    if record.get('test_exit')!=0: raise SystemExit(1)
