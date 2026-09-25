#!/usr/bin/env python3
"""Build universal Mach-O using Clang/LLD; no Apple SDK is redistributed.
The local linker stubs merely name system framework dependencies. Undefined
imports use dyld lookup across these explicitly loaded frameworks. Rebuild on
macOS with build-mac.sh to use normal SDK headers and two-level linking.
"""
from pathlib import Path
import subprocess,struct,os,sys
ROOT=Path(__file__).resolve().parents[1]
OUT=Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/'dist'
OUT.mkdir(parents=True,exist_ok=True)
CLANG='/usr/local/swift/usr/bin/clang';LD=os.environ.get('PULSE_LD','/usr/local/swift/usr/bin/ld64.lld')
frameworks={
 'System':'/usr/lib/libSystem.B.dylib',
 'objc':'/usr/lib/libobjc.A.dylib',
 'Foundation':'/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation',
 'CoreFoundation':'/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation',
 'AppKit':'/System/Library/Frameworks/AppKit.framework/Versions/C/AppKit',
 'WebKit':'/System/Library/Frameworks/WebKit.framework/Versions/A/WebKit',
 'IOKit':'/System/Library/Frameworks/IOKit.framework/Versions/A/IOKit',
 'Metal':'/System/Library/Frameworks/Metal.framework/Versions/A/Metal',
 'UserNotifications':'/System/Library/Frameworks/UserNotifications.framework/Versions/A/UserNotifications',
 'ServiceManagement':'/System/Library/Frameworks/ServiceManagement.framework/Versions/A/ServiceManagement',
 'UniformTypeIdentifiers':'/System/Library/Frameworks/UniformTypeIdentifiers.framework/Versions/A/UniformTypeIdentifiers',
}
stubs=[]
for name,path in frameworks.items():
 p=OUT/f'{name}.tbd'
 # One known System export avoids needing a real sysroot for LLD's binder check.
 symbols="['_dyld_stub_binder', 'dyld_stub_binder']" if name=='System' else '[]'
 p.write_text(f"--- !tapi-tbd-v3\narchs: [ arm64, x86_64 ]\nplatform: macosx\ninstall-name: '{path}'\ncurrent-version: 1.0\ncompatibility-version: 1.0\nexports:\n  - archs: [ arm64, x86_64 ]\n    symbols: {symbols}\n...\n")
 stubs.extend(['-needed_library',str(p)])
slices=[]
for arch in ['arm64','x86_64']:
 objs=[OUT/f'{arch}-main.o',OUT/f'{arch}-logic.o']; binary=OUT/f'PulseMonitor-{arch}'
 for source,obj in zip([ROOT/'native/main.m',ROOT/'native/PulseLogic.m'],objs):
  subprocess.run([CLANG,'-target',f'{arch}-apple-macos13.0','-fobjc-arc','-fblocks','-DPULSE_CROSS_HEADERS=1','-fobjc-runtime=macosx-13.0','-O2','-Wall','-Wextra','-Werror','-Wno-unused-parameter','-c',str(source),'-o',str(obj)],check=True)
 subprocess.run([LD,'-arch',arch,'-platform_version','macos','13.0','13.0','-e','_main','-undefined','dynamic_lookup','-adhoc_codesign','-o',str(binary),*[str(o) for o in objs],*stubs],check=True)
 data=binary.read_bytes();magic,cpu,sub=struct.unpack_from('<III',data)
 assert magic==0xfeedfacf
 slices.append((cpu,sub,data))
# Standard FAT_MAGIC universal container, each slice aligned to 16 KiB.
header=bytearray(struct.pack('>II',0xcafebabe,len(slices)));pos=16384;entries=[]
for cpu,sub,data in slices:
 entries.append((pos,data));header+=struct.pack('>IIIII',cpu,sub,pos,len(data),14);pos=(pos+len(data)+16383)&~16383
result=bytearray(pos);result[:len(header)]=header
for offset,data in entries:result[offset:offset+len(data)]=data
fat=OUT/'PulseMonitor';fat.write_bytes(result);fat.chmod(0o755)
print(f'Universal executable: {fat} ({len(result):,} bytes)')
