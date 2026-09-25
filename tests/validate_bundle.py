#!/usr/bin/env python3
"""Static validation only: not macOS runtime, Developer ID, or notarization."""
from pathlib import Path
import hashlib, json, plistlib, struct, sys, math
ROOT=Path(__file__).resolve().parents[1]
APP=Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/'dist/Pulse Monitor.app'
BIN=APP/'Contents/MacOS/PulseMonitor'
results=[]
def check(name,ok):
    if not ok: raise AssertionError(name)
    results.append({'test':name,'result':'PASS'})
data=BIN.read_bytes()
check('Executable has execute permission',bool(BIN.stat().st_mode&0o111))
magic,n=struct.unpack_from('>II',data)
check('Universal Mach-O container has two slices',magic==0xcafebabe and n==2)
archs=[];slice_reports=[]
for i in range(n):
    cpu,sub,offset,size,align=struct.unpack_from('>IIIII',data,8+i*20)
    arch={0x0100000c:'arm64',0x01000007:'x86_64'}.get(cpu,'unknown')
    archs.append(arch)
    check(f'{arch}: slice within file and aligned',offset+size<=len(data) and offset%(1<<align)==0)
    b=data[offset:offset+size]
    m,c,s,kind,ncmds,cmdbytes,flags,res=struct.unpack_from('<8I',b)
    check(f'{arch}: 64-bit executable header',m==0xfeedfacf and c==cpu and kind==2)
    pos=32;deps=[];minos=None;entry=False;sig=None
    for j in range(ncmds):
        cmd,length=struct.unpack_from('<II',b,pos)
        check(f'{arch}: load command {j+1} bounds',length>=8 and pos+length<=32+cmdbytes)
        if cmd==0x32:
            platform,minos,sdk,tools=struct.unpack_from('<IIII',b,pos+8)
            check(f'{arch}: macOS platform and 13.0 minimum',platform==1 and minos==0x000d0000)
        if cmd==0x80000028:
            entryoff,stack=struct.unpack_from('<QQ',b,pos+8);entry=0<entryoff<len(b)
        if cmd in (0xc,0x18|0x80000000,0x1f|0x80000000):
            no=struct.unpack_from('<I',b,pos+8)[0]
            deps.append(b[pos+no:pos+length].split(b'\0',1)[0].decode())
        if cmd==0x1d: sig=struct.unpack_from('<II',b,pos+8)
        pos+=length
    check(f'{arch}: commands exactly fit header',pos==32+cmdbytes)
    check(f'{arch}: executable entry point present',entry)
    check(f'{arch}: no non-system dylib dependencies',bool(deps) and all(d.startswith(('/usr/lib/','/System/Library/Frameworks/')) for d in deps))
    check(f'{arch}: essential frameworks explicitly loaded',all(any(x in d for d in deps) for x in ['AppKit.framework','WebKit.framework','IOKit.framework','ServiceManagement.framework','Metal.framework','UserNotifications.framework']))
    check(f'{arch}: ad-hoc code signature present',sig is not None)
    start,sz=sig;blob=b[start:start+sz]
    sm,sl,sc=struct.unpack_from('>III',blob)
    check(f'{arch}: signature superblob bounds',sm==0xfade0cc0 and sl<=sz)
    cd=None
    for k in range(sc):
        typ,bo=struct.unpack_from('>II',blob,12+k*8)
        if typ==0:cd=blob[bo:]
    check(f'{arch}: CodeDirectory exists',cd is not None)
    cm,cl,ver,fl,ho,ident,ns,nc,limit=struct.unpack_from('>9I',cd)
    hs,ht,platform,ps=struct.unpack_from('>4B',cd,36)
    check(f'{arch}: SHA-256 ad-hoc CodeDirectory',cm==0xfade0c02 and fl&2 and ht==2 and hs==32)
    page_size=1<<ps
    check(f'{arch}: signature code page count',nc==math.ceil(limit/page_size) and limit<=len(b))
    valid=all(hashlib.sha256(b[k*page_size:min((k+1)*page_size,limit)]).digest()==cd[ho+k*hs:ho+(k+1)*hs] for k in range(nc))
    check(f'{arch}: all code-page hashes match',valid)
    slice_reports.append({'architecture':arch,'minimum_macos':'13.0','size_bytes':size,'signed_pages':nc,'framework_dependencies':deps})
check('Both Apple Silicon and Intel slices present',set(archs)=={'arm64','x86_64'})
info=plistlib.loads((APP/'Contents/Info.plist').read_bytes())
check('Info.plist has macOS 13.0 minimum',info['LSMinimumSystemVersion']=='13.0')
check('Bundle executable and identifier match',info['CFBundleExecutable']=='PulseMonitor' and info['CFBundleIdentifier']=='local.pulse.monitor')
for f in ['ui/index.html','ui/app.js','ui/styles.css','AppIcon.icns']:
    check(f'Bundled resource: {f}',(APP/'Contents/Resources'/f).is_file())
check('Demo fixture not shipped inside app',not (APP/'Contents/Resources/ui/demo.js').exists())
html=(APP/'Contents/Resources/ui/index.html').read_text()
check('Production CSP blocks connections and objects',"connect-src 'none'" in html and "object-src 'none'" in html)
report={'passed':len(results),'failed':0,'scope':'Static binary/bundle validation only; this report does not validate native runtime or GUI behavior. It is not Developer ID signing or notarization. Only executable CodeDirectory hashes are checked here; codesign --verify is run separately. See QA_REPORT.md for native diagnostic results.','sha256_executable':hashlib.sha256(data).hexdigest(),'slices':slice_reports,'tests':results}
(ROOT/'tests/binary-test-report.json').write_text(json.dumps(report,indent=2))
print(json.dumps({'passed':len(results),'failed':0,'architectures':archs,'minimum_macos':'13.0','sha256_executable':report['sha256_executable']},indent=2))
