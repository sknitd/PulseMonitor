#import "Platform.h"
#import "PulseLogic.h"

static id Null(void) { return [NSNull null]; }
static double Clamp(double x,double a,double b) { return x<a?a:(x>b?b:x); }
static NSString *JSONString(id obj) {
    NSData *d=[NSJSONSerialization dataWithJSONObject:obj options:0 error:NULL];
    return d ? [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] : @"{}";
}
static NSArray *Words(NSString *s) {
    NSMutableArray *a=[NSMutableArray array];
    for(NSString *w in [s componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]])
        if(w.length) [a addObject:w];
    return a;
}
static NSString *Run(NSString *path,NSArray *args) {
    @try {
        NSTask *t=[NSTask new]; t.executableURL=[NSURL fileURLWithPath:path]; t.arguments=args;
        NSMutableDictionary *env=[[NSProcessInfo processInfo].environment mutableCopy]; env[@"LC_ALL"]=@"C"; t.environment=env;
        NSPipe *p=[NSPipe pipe]; t.standardOutput=p; t.standardError=[NSFileHandle fileHandleWithNullDevice];
        if(![t launchAndReturnError:NULL]) return @"";
        dispatch_after(dispatch_time(0,4*NSEC_PER_SEC),dispatch_get_global_queue(0,0),^{
            @try { if(t.running) [t terminate]; } @catch(NSException *e) {}
        });
        NSData *d=[p.fileHandleForReading readDataToEndOfFile]; [t waitUntilExit];
        return [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] ?: @"";
    } @catch(NSException *e) { return @""; }
}
static double SysNumber(const char *name,double fallback) {
    uint64_t value=0; size_t size=sizeof(value);
    if(sysctlbyname(name,&value,&size,NULL,0)!=0) return fallback;
    return size==4 ? (double)(uint32_t)value : (double)value;
}
static NSString *SysString(const char *name) {
    char buffer[256]={0}; size_t n=sizeof(buffer)-1;
    return sysctlbyname(name,buffer,&n,NULL,0)==0 ? [NSString stringWithUTF8String:buffer] : @"";
}
static NSArray *Registry(const char *className) {
    NSMutableArray *out=[NSMutableArray array]; uint32_t iterator=0;
    CFMutableDictionaryRef match=IOServiceMatching(className);
    if(!match || IOServiceGetMatchingServices(0,match,&iterator)!=0) return out;
    uint32_t service;
    while((service=IOIteratorNext(iterator))) {
        CFMutableDictionaryRef props=NULL;
        if(IORegistryEntryCreateCFProperties(service,&props,NULL,0)==0 && props) {
            [out addObject:(__bridge NSDictionary*)props]; CFRelease(props);
        }
        IOObjectRelease(service);
    }
    IOObjectRelease(iterator); return out;
}
static NSDictionary *ProcessIdentity(pid_t pid) {
    struct proc_bsdinfo info={0};
    if(proc_pidinfo(pid,PROC_PIDTBSDINFO,0,&info,sizeof(info))!=sizeof(info)||info.pbi_pid!=(uint32_t)pid)return nil;
    char pathBuffer[PROC_PIDPATHINFO_MAXSIZE]={0};
    int pathLength=proc_pidpath(pid,pathBuffer,sizeof(pathBuffer));
    NSString *path=pathLength>0?[NSString stringWithUTF8String:pathBuffer]:@"";
    if(![path hasPrefix:@"/"])path=@"";
    NSString *birth=[NSString stringWithFormat:@"%llu:%llu",(unsigned long long)info.pbi_start_tvsec,(unsigned long long)info.pbi_start_tvusec];
    return @{@"pid":@(pid),@"uid":@(info.pbi_uid),@"ppid":@(info.pbi_ppid),@"path":path,@"startToken":birth};
}
static NSMutableArray *ReadProcesses(void) {
    NSString *text=Run(@"/bin/ps",@[@"-axo",@"pid=,ppid=,uid=,%cpu=,rss=,etime=,lstart=,comm="]);
    NSRegularExpression *rx=[NSRegularExpression regularExpressionWithPattern:
        @"^\\s*(\\d+)\\s+(\\d+)\\s+(\\d+)\\s+([0-9.]+)\\s+(\\d+)\\s+(\\S+)\\s+(\\S+\\s+\\S+\\s+\\d+\\s+\\S+\\s+\\d+)\\s+(.*)$"
        options:0 error:NULL];
    NSMutableArray *out=[NSMutableArray array];
    for(NSString *line in [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        NSTextCheckingResult *m=[rx firstMatchInString:line options:0 range:NSMakeRange(0,line.length)];
        if(!m) continue;
        NSMutableArray *fields=[NSMutableArray array];
        for(NSUInteger i=1;i<=8;i++) [fields addObject:[line substringWithRange:[m rangeAtIndex:i]]];
        int pid=[fields[0] intValue]; if(pid<1) continue;
        NSDictionary *identityBefore=ProcessIdentity(pid);
        NSString *birthBefore=identityBefore[@"startToken"]?:@"";
        double rss=[fields[4] doubleValue]*1024.0, memory=rss;
        PulseRUsage ru={0}; BOOL footprint=identityBefore&&proc_pid_rusage(pid,2,(void*)&ru)==0;
        if(footprint) memory=(double)ru.footprint;
        NSDictionary *identityAfter=identityBefore?ProcessIdentity(pid):nil;
        if(identityBefore&&(!identityAfter||![birthBefore isEqualToString:identityAfter[@"startToken"]]||
            ![identityBefore[@"path"] isEqualToString:identityAfter[@"path"]]))continue;
        NSDictionary *identity=identityAfter?:identityBefore;
        NSString *path=identity[@"path"]?:@"";
        NSString *command=fields[7];
        NSString *name=path.length?path.lastPathComponent:command.lastPathComponent;
        [out addObject:[@{@"pid":@(pid),@"ppid":identity[@"ppid"]?:@([fields[1] intValue]),@"uid":identity[@"uid"]?:@([fields[2] intValue]),
            @"cpu":@([fields[3] doubleValue]),@"rss":@(rss),@"memory":@(memory),
            @"footprint":@(footprint),@"elapsed":fields[5],@"startToken":identity[@"startToken"]?:@"",
            @"path":path,@"name":name.length?name:@"Process"} mutableCopy]];
    }
    return out;
}

@interface PulseCollector : NSObject {
    uint32_t _host,_oldTicks[4]; BOOL _haveCPU;
    double _lastTime,_lastProjects,_netIn,_netOut,_diskRead,_diskWrite,_sessionIn,_sessionOut;
    BOOL _haveNetwork,_haveDisk;
    NSMutableArray *_projects;
    NSMutableDictionary *_lowSince;
    NSString *_chip,*_model,*_gpuName;
    BOOL _unified;
}
- (NSDictionary*)sample:(NSArray*)running;
- (void)resetBaselines;
@end

@implementation PulseCollector
- (void)resetBaselines { _haveCPU=NO;_haveDisk=NO;_haveNetwork=NO;_lastTime=0;[_lowSince removeAllObjects]; }
- (instancetype)init {
    if((self=[super init])) {
        _host=mach_host_self(); _projects=[NSMutableArray array]; _lowSince=[NSMutableDictionary dictionary];
        _chip=SysString("machdep.cpu.brand_string"); _model=SysString("hw.model");
        id<MTLDevice> gpu=MTLCreateSystemDefaultDevice(); _gpuName=gpu.name?:@"Not reported";
        _unified=gpu ? gpu.hasUnifiedMemory : NO;
    } return self;
}
- (NSDictionary*)sample:(NSArray*)running {
    double now=[NSProcessInfo processInfo].systemUptime;
    double dt=_lastTime>0 ? MAX(0.1,now-_lastTime) : 0; _lastTime=now;
    uint32_t ticks[4]={0},count=4;
    BOOL cpuOK=host_statistics(_host,3,(int*)ticks,&count)==0;
    PulseCPUReading cpuReading=PulseCalculateCPU(_oldTicks,ticks,cpuOK&&_haveCPU);
    if(cpuOK){for(int i=0;i<4;i++)_oldTicks[i]=ticks[i];_haveCPU=YES;}
    double loads[3]={0}; int loadCount=getloadavg(loads,3);
    NSUInteger cores=MAX(1,[NSProcessInfo processInfo].activeProcessorCount);
    NSDictionary *cpu=@{@"available":@(cpuReading.available),@"usage":cpuReading.available?@(cpuReading.usage):Null(),
        @"user":cpuReading.available?@(cpuReading.user):Null(),@"system":cpuReading.available?@(cpuReading.system):Null(),
        @"idle":cpuReading.available?@(cpuReading.idle):Null(),@"cores":@(cores),
        @"load1":loadCount>=1?@(loads[0]):Null(),@"load5":loadCount>=2?@(loads[1]):Null(),@"load15":loadCount>=3?@(loads[2]):Null()};
    PulseVMInfo vm={0}; count=sizeof(vm)/sizeof(uint32_t);
    BOOL memOK=host_statistics64(_host,4,(int*)&vm,&count)==0;
    unsigned long page=4096; host_page_size(_host,&page);
    double total=SysNumber("hw.memsize",0),wired=(double)vm.wired*page,compressed=(double)vm.compressed*page;
    double app=MAX(0.0,((double)vm.internal-vm.purgeable)*page);
    app=MIN(app,MAX(0.0,total-wired-compressed));
    double used=MIN(total,app+wired+compressed),cached=MIN(total,(double)(vm.external+vm.purgeable)*page);
    struct {uint64_t total,avail,used; uint32_t pagesize; BOOL encrypted;} swap={0}; size_t sn=sizeof(swap);
    BOOL swapOK=sysctlbyname("vm.swapusage",&swap,&sn,NULL,0)==0;
    int level=0; size_t ln=sizeof(level); BOOL pressureOK=sysctlbyname("kern.memorystatus_vm_pressure_level",&level,&ln,NULL,0)==0;
    NSString *pressure=PulseMemoryPressureName(level,pressureOK);
    BOOL memoryAvailable=memOK&&total>0;
    NSDictionary *memory=@{@"available":@(memoryAvailable),@"total":memoryAvailable?@(total):Null(),
        @"used":memoryAvailable?@(used):Null(),@"app":memoryAvailable?@(app):Null(),
        @"wired":memoryAvailable?@(wired):Null(),@"compressed":memoryAvailable?@(compressed):Null(),
        @"cached":memoryAvailable?@(cached):Null(),@"free":memoryAvailable?@(MAX(0,total-used)):Null(),
        @"physicalFree":memoryAvailable?@((double)vm.free*page):Null(),@"swap":swapOK?@((double)swap.used):Null(),@"pressure":pressure};
    NSDictionary *fs=[[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:NULL];
    double diskTotal=[fs[@"NSFileSystemSize"] doubleValue],diskFree=[fs[@"NSFileSystemFreeSize"] doubleValue];
    BOOL diskAvailable=diskTotal>0&&diskFree>=0&&diskFree<=diskTotal;
    double dr=0,dw=0; BOOL diskIO=NO;
    for(NSDictionary *p in Registry("IOBlockStorageDriver")) {
        NSDictionary *st=p[@"Statistics"];
        if(st[@"Bytes (Read)"]&&st[@"Bytes (Write)"]){diskIO=YES;dr+=[st[@"Bytes (Read)"] doubleValue];dw+=[st[@"Bytes (Write)"] doubleValue];}
    }
    BOOL diskRate=diskIO&&_haveDisk&&dt>0;
    NSDictionary *disk=@{@"available":@(diskAvailable),@"total":diskAvailable?@(diskTotal):Null(),@"free":diskAvailable?@(diskFree):Null(),
        @"used":diskAvailable?@(MAX(0,diskTotal-diskFree)):Null(),
        @"read":diskRate?@(MAX(0,dr-_diskRead)/dt):Null(),@"write":diskRate?@(MAX(0,dw-_diskWrite)/dt):Null(),
        @"volume":@"Home volume",@"ioAvailable":@(diskRate)};
    _diskRead=dr;_diskWrite=dw;_haveDisk=diskIO;
    NSString *net=Run(@"/usr/sbin/netstat",@[@"-ibn"]); NSArray *lines=[net componentsSeparatedByString:@"\n"];
    double ni=0,no=0; NSMutableArray *interfaces=[NSMutableArray array]; NSUInteger inIdx=NSNotFound,outIdx=NSNotFound;
    for(NSString *line in lines) {
        NSArray *f=Words(line); if(f.count<4)continue;
        if([f[0] isEqualToString:@"Name"]){inIdx=[f indexOfObject:@"Ibytes"];outIdx=[f indexOfObject:@"Obytes"];continue;}
        if(inIdx==NSNotFound||outIdx==NSNotFound||f.count<=MAX(inIdx,outIdx))continue;
        NSString *iface=f[0]; if(![iface hasPrefix:@"en"]||![f[2] hasPrefix:@"<Link#"])continue;
        if([interfaces containsObject:iface])continue;
        [interfaces addObject:iface]; ni+=[f[inIdx] doubleValue];no+=[f[outIdx] doubleValue];
    }
    BOOL netOK=interfaces.count>0,netRate=netOK&&_haveNetwork&&dt>0;
    double dIn=netRate?MAX(0,ni-_netIn):0,dOut=netRate?MAX(0,no-_netOut):0;
    _sessionIn+=dIn;_sessionOut+=dOut;_netIn=ni;_netOut=no;_haveNetwork=netOK;
    NSDictionary *network=@{@"available":@(netRate),@"download":netRate?@(dIn/dt):Null(),@"upload":netRate?@(dOut/dt):Null(),
        @"received":@(_sessionIn),@"sent":@(_sessionOut),@"interfaces":interfaces};
    NSMutableDictionary *battery=[@{@"available":@NO,@"percent":Null(),@"charging":@NO,@"pluggedIn":@NO,
        @"minutes":Null(),@"cycles":Null(),@"health":Null(),@"watts":Null()} mutableCopy];
    CFTypeRef power=IOPSCopyPowerSourcesInfo();
    if(power) {
        CFArrayRef sources=IOPSCopyPowerSourcesList(power);
        if(sources) {
            for(id source in (__bridge NSArray*)sources) {
                NSDictionary *d=(__bridge NSDictionary*)IOPSGetPowerSourceDescription(power,(__bridge CFTypeRef)source);
                if(![d[@"Type"] isEqualToString:@"InternalBattery"])continue;
                double max=[d[@"Max Capacity"] doubleValue],current=[d[@"Current Capacity"] doubleValue];
                if(max<=0)continue;
                battery[@"available"]=@YES; battery[@"percent"]=@(Clamp(100*current/max,0,100));
                battery[@"charging"]=d[@"Is Charging"]?:@NO;
                battery[@"pluggedIn"]=@([d[@"Power Source State"] isEqualToString:@"AC Power"]);
                id mins=[battery[@"charging"] boolValue]?d[@"Time to Full Charge"]:d[@"Time to Empty"];
                if(mins&&[mins doubleValue]>0)battery[@"minutes"]=mins;
                break;
            }
            CFRelease(sources);
        } CFRelease(power);
    }
    if([battery[@"available"] boolValue]) {
        NSDictionary *b=Registry("AppleSmartBattery").firstObject;
        if(b[@"CycleCount"])battery[@"cycles"]=b[@"CycleCount"];
        double design=[b[@"DesignCapacity"] doubleValue],full=[b[@"AppleRawMaxCapacity"] doubleValue];
        if(full<=0)full=[b[@"NominalChargeCapacity"] doubleValue];
        if(design>0&&full>0&&full/design<1.3)battery[@"health"]=@(Clamp(100*full/design,0,100));
        // No per-app watts: neither CPU percentage nor memory is an energy meter.
    }
    // Metal identifies the device but does not expose system-wide utilization.
    // IOAccelerator PerformanceStatistics is driver-private and is not used here.
    NSDictionary *gpu=@{@"available":@NO,@"usage":Null(),@"name":_gpuName,
        @"deviceAvailable":@(![_gpuName isEqualToString:@"Not reported"]),@"unified":@(_unified)};
    NSMutableArray *processes=ReadProcesses();
    NSMutableDictionary *byPID=[NSMutableDictionary dictionary];
    for(NSDictionary *p in processes)byPID[[p[@"pid"] stringValue]]=p;
    NSArray *apps=PulseGroupProcesses(processes,running);
    for(NSMutableDictionary *group in apps)
        group[@"quitAllowed"]=@(PulseAppQuitIsAllowed(group[@"name"],group[@"path"],[group[@"rootPID"] intValue],getpid()));
    if(now-_lastProjects>=10 || _lastProjects==0) {
        _lastProjects=now;
        NSString *ls=Run(@"/usr/sbin/lsof",@[@"-nP",@"-iTCP",@"-sTCP:LISTEN",@"-Fpn"]);
        NSDictionary *ports=PulseListeningPortsFromLsof(ls);
        NSMutableArray *pids=[NSMutableArray array];
        for(NSString *pidString in ports) {
            NSDictionary *p=byPID[pidString];
            if(!p||[p[@"uid"] intValue]!=(int)getuid()||[p[@"pid"] intValue]==getpid())continue;
            NSDictionary *currentIdentity=ProcessIdentity([p[@"pid"] intValue]);
            if(currentIdentity&&PulseProjectIdentityMatches(p,currentIdentity,getuid(),getpid()))[pids addObject:pidString];
        }
        NSMutableDictionary *dirs=[NSMutableDictionary dictionary]; NSString *current=nil;
        if(pids.count) {
            NSString *cwd=Run(@"/usr/sbin/lsof",@[@"-a",@"-p",[pids componentsJoinedByString:@","],@"-d",@"cwd",@"-Fpn"]);current=nil;
            for(NSString *line in [cwd componentsSeparatedByString:@"\n"]) {
                if([line hasPrefix:@"p"])current=[line substringFromIndex:1];
                else if([line hasPrefix:@"n/"]&&current)dirs[current]=PulseDecodeLsofEscapedPath([line substringFromIndex:1]);
            }
        }
        _projects=[NSMutableArray array];
        for(NSString *pid in pids) {
            NSDictionary *p=byPID[pid];NSString *cwd=dirs[pid]?:@"";
            if(![cwd hasPrefix:@"/"]||![[NSFileManager defaultManager] fileExistsAtPath:cwd])cwd=@"";
            [_projects addObject:[@{@"pid":p[@"pid"],@"name":cwd.length?cwd.lastPathComponent:p[@"name"],@"cwd":cwd,
                @"runtime":p[@"name"],@"path":p[@"path"],@"startToken":p[@"startToken"],
                @"uid":p[@"uid"],@"ports":ports[pid],@"memory":p[@"memory"],
                @"cpu":p[@"cpu"],@"elapsed":p[@"elapsed"],@"lowSeconds":@0} mutableCopy]];
        }
    }
    NSMutableArray *activeProjects=[NSMutableArray array];NSMutableSet *activeKeys=[NSMutableSet set];
    for(NSMutableDictionary *p in _projects) {
        NSString *pid=[p[@"pid"] stringValue]; NSDictionary *live=byPID[pid];
        if(!live||!PulseProjectIdentityMatches(p,live,getuid(),getpid()))continue;
        p[@"memory"]=live[@"memory"];p[@"cpu"]=live[@"cpu"];p[@"elapsed"]=live[@"elapsed"];
        NSString *key=[NSString stringWithFormat:@"%@:%@",pid,p[@"startToken"]];[activeKeys addObject:key];
        if([p[@"cpu"] doubleValue]<1){if(!_lowSince[key])_lowSince[key]=@(now);}
        else [_lowSince removeObjectForKey:key];
        p[@"lowSeconds"]=_lowSince[key]?@(now-[_lowSince[key] doubleValue]):@0;[activeProjects addObject:[p copy]];
    }
    for(NSString *k in [_lowSince.allKeys copy])if(![activeKeys containsObject:k])[_lowSince removeObjectForKey:k];
    [activeProjects sortUsingComparator:^NSInteger(id a,id b){double d=[b[@"memory"] doubleValue]-[a[@"memory"] doubleValue];return d>0?1:d<0?-1:0;}];
    NSUInteger appCount=0;for(NSDictionary *a in apps)if(![a[@"id"] isEqualToString:@"__background__"])appCount++;
    return @{@"timestamp":@([NSDate date].timeIntervalSince1970),@"uptime":@(now),
        @"model":_model,@"chip":_chip,@"os":[NSProcessInfo processInfo].operatingSystemVersionString,
        @"cpu":cpu,@"memory":memory,@"disk":disk,@"network":network,@"battery":battery,@"gpu":gpu,
        @"thermal":PulseThermalStateName([NSProcessInfo processInfo].thermalState),@"apps":apps,@"processCount":@(processes.count),
        @"appCount":@(appCount),@"projects":activeProjects,@"processesAvailable":@(processes.count>0),@"version":@"1.0.0"};
}
@end

@interface PulseApp : NSObject <NSApplicationDelegate,NSWindowDelegate,WKScriptMessageHandler,WKNavigationDelegate,UNUserNotificationCenterDelegate>
@property(strong) NSWindow *window; @property(strong) WKWebView *web,*menuWeb;
@property(strong) NSStatusItem *status; @property(strong) NSPopover *popover;
@property(strong) NSTimer *timer; @property(strong) PulseCollector *collector;
@property(strong) NSDictionary *snapshot; @property(strong) NSMutableDictionary *settings,*cpuSince,*growth,*cooldowns,*icons;
@property(strong) PulseHistoryBuffer *history; @property(strong) NSMutableArray *alerts;
@property BOOL busy,paused,webReady,menuReady; @property double lastPoll;
#if defined(PULSE_CROSS_HEADERS)
@property dispatch_queue_t queue;
#else
@property(strong) dispatch_queue_t queue;
#endif
@end

@implementation PulseApp
- (void)applicationDidFinishLaunching:(NSNotification*)n {
    self.queue=dispatch_queue_create("local.pulse.monitor.sampler",NULL);self.collector=[PulseCollector new];
    self.history=[[PulseHistoryBuffer alloc] initWithCapacity:600];self.alerts=[NSMutableArray array];self.cpuSince=[NSMutableDictionary dictionary];
    self.growth=[NSMutableDictionary dictionary];self.cooldowns=[NSMutableDictionary dictionary];self.icons=[NSMutableDictionary dictionary];
    self.settings=[@{@"interval":@2,@"theme":@"system",@"alerts":@NO,@"cpuThreshold":@80,@"cpuDuration":@60,
        @"growthMB":@512,@"hideDock":@NO,@"launchAtLogin":@NO} mutableCopy];
    NSDictionary *saved=[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"PulseSettings"];
    if(saved)self.settings=[PulseApplyingSettings(self.settings,saved) mutableCopy];
    self.settings[@"launchAtLogin"]=@([SMAppService mainAppService].status==SMAppServiceStatusEnabled);
    [UNUserNotificationCenter currentNotificationCenter].delegate=self;
    self.window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,1120,800)
        styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered defer:NO];
    self.window.title=@"Pulse Monitor";self.window.minSize=NSMakeSize(860,650);self.window.releasedWhenClosed=NO;
    self.window.delegate=self;[self.window setFrameAutosaveName:@"PulseMainWindow"];
    self.web=[self newWebView:NO];self.window.contentView=self.web;[self.window center];
    [self buildMenu];
    self.status=[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.status.button.image=[NSImage imageWithSystemSymbolName:@"waveform.path.ecg" accessibilityDescription:@"Pulse Monitor"];
    self.status.button.image.template=YES;self.status.button.imagePosition=NSImageLeft;
    self.status.button.title=@" —";self.status.button.target=self;self.status.button.action=@selector(togglePopover:);
    self.status.button.toolTip=@"Pulse Monitor — click for your Mac’s vitals";
    [NSApp setActivationPolicy:[self.settings[@"hideDock"] boolValue]?NSApplicationActivationPolicyAccessory:NSApplicationActivationPolicyRegular];
    [self.window makeKeyAndOrderFront:nil];[NSApp activateIgnoringOtherApps:YES];
    [self startSamplerTimer];[self tick:nil];
}
- (void)startSamplerTimer {
    if(self.timer)return;
    self.timer=[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(tick:) userInfo:nil repeats:YES];
    self.timer.tolerance=0.2;
}
- (void)buildMenu {
    NSMenu *bar=[NSMenu new];NSMenuItem *root=[[NSMenuItem alloc] initWithTitle:@"Pulse Monitor" action:NULL keyEquivalent:@""];[bar addItem:root];
    NSMenu *app=[[NSMenu alloc] initWithTitle:@"Pulse Monitor"];root.submenu=app;
    NSMenuItem *show=[app addItemWithTitle:@"Open Pulse Monitor" action:@selector(showMain:) keyEquivalent:@"0"];show.target=self;
    NSMenuItem *settings=[app addItemWithTitle:@"Settings…" action:@selector(showSettings:) keyEquivalent:@","];settings.target=self;
    [app addItem:[NSMenuItem separatorItem]];
    NSMenuItem *pause=[app addItemWithTitle:@"Pause / Resume Monitoring" action:@selector(togglePause:) keyEquivalent:@"p"];pause.target=self;
    NSMenuItem *export=[app addItemWithTitle:@"Export Snapshot…" action:@selector(exportSnapshot:) keyEquivalent:@"e"];export.target=self;
    [app addItem:[NSMenuItem separatorItem]];
    [app addItemWithTitle:@"Hide Pulse Monitor" action:@selector(hide:) keyEquivalent:@"h"];
    [app addItemWithTitle:@"Quit Pulse Monitor" action:@selector(terminate:) keyEquivalent:@"q"];
    NSMenuItem *editRoot=[[NSMenuItem alloc] initWithTitle:@"Edit" action:NULL keyEquivalent:@""];[bar addItem:editRoot];NSMenu *edit=[[NSMenu alloc] initWithTitle:@"Edit"];editRoot.submenu=edit;
    [edit addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [edit addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [edit addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [edit addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    NSMenuItem *windowRoot=[[NSMenuItem alloc] initWithTitle:@"Window" action:NULL keyEquivalent:@""];[bar addItem:windowRoot];
    NSMenu *windowMenu=[[NSMenu alloc] initWithTitle:@"Window"];windowRoot.submenu=windowMenu;
    NSMenuItem *close=[windowMenu addItemWithTitle:@"Close Window" action:@selector(performClose:) keyEquivalent:@"w"];close.target=self.window;
    NSMenuItem *minimize=[windowMenu addItemWithTitle:@"Minimize" action:@selector(performMiniaturize:) keyEquivalent:@"m"];minimize.target=self.window;
    NSApp.mainMenu=bar;
}
- (WKWebView*)newWebView:(BOOL)menu {
    WKWebViewConfiguration *config=[WKWebViewConfiguration new];
    config.preferences.javaScriptCanOpenWindowsAutomatically=NO;
    WKUserContentController *controller=[WKUserContentController new];[controller addScriptMessageHandler:self name:@"pulse"];
    NSString *script=[NSString stringWithFormat:@"window.PULSE_MODE='%@';",menu?@"menu":@"main"];
    [controller addUserScript:[[WKUserScript alloc] initWithSource:script injectionTime:0 forMainFrameOnly:YES]];
    config.userContentController=controller;
    WKWebView *w=[[WKWebView alloc] initWithFrame:NSMakeRect(0,0,menu?420:1120,menu?660:770) configuration:config];
    w.navigationDelegate=self;w.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
    NSURL *root=[[NSBundle mainBundle].resourceURL URLByAppendingPathComponent:@"ui"];
    [w loadFileURL:[root URLByAppendingPathComponent:@"index.html"] allowingReadAccessToURL:root];return w;
}
- (void)webView:(WKWebView*)w decidePolicyForNavigationAction:(WKNavigationAction*)a decisionHandler:(void(^)(WKNavigationActionPolicy))handler {
    // UI is local-only; remote pages must never acquire the privileged native bridge.
    NSURL *u=a.request.URL;
    NSString *root=[[[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:@"ui"] stringByAppendingString:@"/"];
    handler(u.isFileURL&&[u.path hasPrefix:root]?WKNavigationActionPolicyAllow:WKNavigationActionPolicyCancel);
}
- (void)webView:(WKWebView*)w didFinishNavigation:(id)n {
    if(w==self.web)self.webReady=YES;else self.menuReady=YES;
    [self sendState];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)a { return NO; }
- (BOOL)windowShouldClose:(NSWindow*)w { [w orderOut:nil];return NO; }
- (BOOL)applicationShouldHandleReopen:(NSApplication*)a hasVisibleWindows:(BOOL)b { [self showMain:nil];return YES; }
- (void)showMain:(id)sender { [self.popover performClose:nil];[self.window makeKeyAndOrderFront:nil];[NSApp activateIgnoringOtherApps:YES];[self sendState]; }
- (void)showSettings:(id)sender { [self showMain:nil];[self.web evaluateJavaScript:@"window.Pulse && Pulse.navigate('settings')" completionHandler:nil]; }
- (void)togglePause:(id)sender {
    self.paused=!self.paused;[self.cpuSince removeAllObjects];[self.growth removeAllObjects];
    if(self.paused){[self.timer invalidate];self.timer=nil;}
    else {dispatch_async(self.queue,^{[self.collector resetBaselines];});self.lastPoll=0;[self startSamplerTimer];[self tick:nil];}
    [self sendState];
}
- (void)togglePopover:(id)sender {
    if(self.popover.shown){[self.popover performClose:nil];return;}
    if(!self.popover) {
        self.popover=[NSPopover new];self.popover.contentSize=NSMakeSize(420,660);self.popover.behavior=NSPopoverBehaviorTransient;
        NSViewController *vc=[NSViewController new];self.menuWeb=[self newWebView:YES];vc.view=self.menuWeb;self.popover.contentViewController=vc;
    }
    [self.popover showRelativeToRect:self.status.button.bounds ofView:self.status.button preferredEdge:NSMinYEdge];[self sendState];
}
- (NSArray*)runningApps {
    NSMutableArray *out=[NSMutableArray array];NSMutableSet *activePaths=[NSMutableSet set];
    for(NSRunningApplication *a in [NSWorkspace sharedWorkspace].runningApplications) {
        if(!a.bundleURL.path.length)continue;
        [out addObject:@{@"pid":@(a.processIdentifier),@"path":a.bundleURL.path,@"name":a.localizedName?:@"App"}];
        NSString *path=a.bundleURL.path;
        [activePaths addObject:path];
        if(!self.icons[path]&&a.icon) {
            @try {
                NSImage *img=[[NSImage alloc] initWithSize:NSMakeSize(32,32)];[img lockFocus];
                [a.icon drawInRect:NSMakeRect(0,0,32,32) fromRect:NSMakeRect(0,0,0,0) operation:NSCompositingOperationSourceOver fraction:1];[img unlockFocus];
                NSBitmapImageRep *rep=[NSBitmapImageRep imageRepWithData:img.TIFFRepresentation];
                NSData *data=[rep representationUsingType:NSBitmapImageFileTypePNG properties:[NSDictionary dictionary]];
                if(data)self.icons[path]=[NSString stringWithFormat:@"data:image/png;base64,%@",[data base64EncodedStringWithOptions:0]];
            } @catch(NSException *e) {}
        }
    }
    for(NSString *path in [self.icons.allKeys copy])if(![activePaths containsObject:path])[self.icons removeObjectForKey:path];
    return out;
}
- (void)tick:(id)sender {
    double now=[NSProcessInfo processInfo].systemUptime;
    if(self.paused||self.busy||now-self.lastPoll<[self.settings[@"interval"] doubleValue])return;
    self.busy=YES;self.lastPoll=now;NSArray *running=[self runningApps];
    dispatch_async(self.queue,^{@autoreleasepool{
        NSDictionary *snap=nil;
        @try {snap=[self.collector sample:running];} @catch(NSException *e) {snap=@{@"error":e.reason?:@"Sampling failed"};}
        dispatch_async(dispatch_get_main_queue(),^{
            self.busy=NO;if(snap[@"error"]){[self toast:snap[@"error"]];return;}self.snapshot=snap;
            if(self.paused)return;
            [self.history appendObject:@{@"t":snap[@"timestamp"],@"cpu":snap[@"cpu"][@"usage"],@"memory":snap[@"memory"][@"used"],
                @"network":snap[@"network"][@"download"],@"upload":snap[@"network"][@"upload"],@"gpu":snap[@"gpu"][@"usage"],
                @"battery":snap[@"battery"][@"percent"],@"disk":snap[@"disk"][@"read"]}];
            [self checkAlerts];[self sendState];
        });
    }});
}
- (void)sendState {
    NSString *value=self.paused?@" Ⅱ":([self.snapshot[@"cpu"][@"available"] boolValue]?[NSString stringWithFormat:@" %.0f%%",[self.snapshot[@"cpu"][@"usage"] doubleValue]]:@" —");
    self.status.button.title=value;
    NSDictionary *state=@{@"snapshot":self.snapshot?:Null(),@"history":[self.history allObjects],@"settings":self.settings?:[NSDictionary dictionary],
        @"alerts":self.alerts?:[NSArray array],@"paused":@(self.paused),@"icons":self.icons?:[NSDictionary dictionary]};
    NSString *js=[NSString stringWithFormat:@"window.Pulse && window.Pulse.receive(%@);",JSONString(state)];
    if(self.webReady&&self.window.visible)[self.web evaluateJavaScript:js completionHandler:nil];
    if(self.menuReady&&self.popover.shown)[self.menuWeb evaluateJavaScript:js completionHandler:nil];
}
- (void)toast:(NSString*)message {
    NSString *js=[NSString stringWithFormat:@"window.Pulse && Pulse.toast(%@);",JSONString(@[message])];
    [self.web evaluateJavaScript:js completionHandler:nil];if(self.menuWeb)[self.menuWeb evaluateJavaScript:js completionHandler:nil];
}
- (void)addAlert:(NSString*)title body:(NSString*)body key:(NSString*)key {
    double now=[NSDate date].timeIntervalSince1970;
    if(!PulseCooldownAllows(self.cooldowns,key,[NSProcessInfo processInfo].systemUptime,900))return;
    [self.alerts insertObject:@{@"title":title,@"body":body,@"time":@(now),@"key":key} atIndex:0];
    while(self.alerts.count>50)[self.alerts removeObjectAtIndex:self.alerts.count-1];
    if([self.settings[@"alerts"] boolValue]) {
        UNMutableNotificationContent *c=[UNMutableNotificationContent new];c.title=title;c.body=body;
        [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:
            [UNNotificationRequest requestWithIdentifier:key content:c trigger:nil] withCompletionHandler:nil];
    }
}
- (void)checkAlerts {
    double now=[NSProcessInfo processInfo].systemUptime;
    for(NSString *key in [self.cooldowns.allKeys copy])
        if(now-[self.cooldowns[key] doubleValue]>3600)[self.cooldowns removeObjectForKey:key];
    if(![self.settings[@"alerts"] boolValue]){[self.cpuSince removeAllObjects];[self.growth removeAllObjects];return;}
    NSMutableSet *present=[NSMutableSet set];
    for(NSDictionary *a in self.snapshot[@"apps"]) {
        NSString *key=a[@"id"];if([key isEqualToString:@"__background__"])continue;[present addObject:key];
        if([a[@"cpu"] doubleValue]>=[self.settings[@"cpuThreshold"] doubleValue]) {
            if(!self.cpuSince[key])self.cpuSince[key]=@(now);
            if(PulseAlertConditionIsSustained([self.cpuSince[key] doubleValue],now,[self.settings[@"cpuDuration"] doubleValue]))
                [self addAlert:[NSString stringWithFormat:@"%@ is keeping the CPU busy",a[@"name"]]
                    body:[NSString stringWithFormat:@"Above %.0f%% of one CPU core for at least %.0f seconds. Review it before quitting.",[self.settings[@"cpuThreshold"] doubleValue],[self.settings[@"cpuDuration"] doubleValue]]
                    key:[key stringByAppendingString:@":cpu"]];
        } else [self.cpuSince removeObjectForKey:key];
        NSMutableArray *points=self.growth[key];if(!points){points=[NSMutableArray array];self.growth[key]=points;}
        [points addObject:@{@"t":@(now),@"m":a[@"memory"],@"pid":a[@"rootPID"]}];
        while(points.count>1&&now-[points[1][@"t"] doubleValue]>300)[points removeObjectAtIndex:0];
        NSDictionary *first=points.firstObject;
        if(![first[@"pid"] isEqual:a[@"rootPID"]]){[points removeAllObjects];continue;}
        double base=[first[@"m"] doubleValue],gain=[a[@"memory"] doubleValue]-base;
        if(PulseAlertConditionIsSustained([first[@"t"] doubleValue],now,290)&&gain>=[self.settings[@"growthMB"] doubleValue]*1048576&&gain>base*.25)
            [self addAlert:[NSString stringWithFormat:@"%@ memory use is growing",a[@"name"]]
                body:[NSString stringWithFormat:@"Up %.0f MiB over about five minutes. This is a growth warning, not a confirmed memory leak.",gain/1048576]
                key:[key stringByAppendingString:@":memory"]];
    }
    for(NSString *k in [self.growth.allKeys copy])if(![present containsObject:k]){[self.growth removeObjectForKey:k];[self.cpuSince removeObjectForKey:k];}
}
- (void)userNotificationCenter:(UNUserNotificationCenter*)center willPresentNotification:(id)n withCompletionHandler:(void(^)(UNNotificationPresentationOptions))handler {
    handler(UNNotificationPresentationOptionBanner|UNNotificationPresentationOptionSound);
}
- (BOOL)confirm:(NSString*)title detail:(NSString*)detail button:(NSString*)button {
    [self.popover performClose:nil];[NSApp activateIgnoringOtherApps:YES];
    NSAlert *a=[NSAlert new];a.messageText=title;a.informativeText=detail;a.alertStyle=NSAlertStyleWarning;
    [a addButtonWithTitle:@"Cancel"];[a addButtonWithTitle:button];return [a runModal]==NSAlertFirstButtonReturn+1;
}
- (void)stopProjects:(NSArray*)projects {
    if(!projects.count){[self toast:@"No eligible servers to stop."];return;}
    NSMutableArray *names=[NSMutableArray array];for(NSDictionary *p in projects)[names addObject:[NSString stringWithFormat:@"%@ (PID %@)",p[@"name"],p[@"pid"]]];
    if(![self confirm:@"Stop these developer servers?" detail:[NSString stringWithFormat:@"%@\n\nLow CPU does not prove a server is unused. Active requests or unsaved work may be interrupted. Pulse will send SIGTERM only to these processes owned by your account.",[names componentsJoinedByString:@"\n"]] button:@"Stop servers"])return;
    dispatch_async(self.queue,^{@autoreleasepool{
        NSArray *live=ReadProcesses();NSMutableDictionary *map=[NSMutableDictionary dictionary];for(NSDictionary *p in live)map[[p[@"pid"] stringValue]]=p;
        NSDictionary *livePorts=PulseListeningPortsFromLsof(Run(@"/usr/sbin/lsof",@[@"-nP",@"-iTCP",@"-sTCP:LISTEN",@"-Fpn"]));
        NSUInteger stopped=0,failed=0;
        for(NSDictionary *old in projects) {
            int pid=[old[@"pid"] intValue];NSDictionary *p=map[[old[@"pid"] stringValue]];
            NSDictionary *identity=ProcessIdentity(pid);
            BOOL sameProcess=p&&PulseProjectIdentityMatches(old,p,getuid(),getpid())&&
                identity&&PulseProjectIdentityMatches(old,identity,getuid(),getpid());
            BOOL stillOwnsPort=PulsePortSetsIntersect(old[@"ports"],livePorts[[old[@"pid"] stringValue]]);
            if(sameProcess&&stillOwnsPort&&kill(pid,SIGTERM)==0)stopped++;else failed++;
        }
        dispatch_async(dispatch_get_main_queue(),^{[self toast:[NSString stringWithFormat:@"Termination requested for %lu server(s). %lu skipped or denied.",(unsigned long)stopped,(unsigned long)failed]];self.lastPoll=0;[self tick:nil];});
    }});
}
- (void)saveSettings:(NSDictionary*)input {
    BOOL previousAlerts=[self.settings[@"alerts"] boolValue];
    self.settings=[PulseApplyingSettings(self.settings,input) mutableCopy];
    if([input[@"launchAtLogin"] isKindOfClass:[NSNumber class]]) {
        BOOL enable=[input[@"launchAtLogin"] boolValue];NSError *error=nil;
        BOOL ok=enable?[[SMAppService mainAppService] registerAndReturnError:&error]:[[SMAppService mainAppService] unregisterAndReturnError:&error];
        self.settings[@"launchAtLogin"]=@([SMAppService mainAppService].status==SMAppServiceStatusEnabled);
        if(!ok)[self toast:error.localizedDescription?:@"Login item could not be changed. Move Pulse to Applications and try again."];
        else if(enable&&![self.settings[@"launchAtLogin"] boolValue])[self toast:@"Approve Pulse in System Settings → General → Login Items."];
    }
    if(!previousAlerts&&[self.settings[@"alerts"] boolValue]) {
        [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:UNAuthorizationOptionAlert|UNAuthorizationOptionSound
            completionHandler:^(BOOL granted,NSError *e){if(!granted)dispatch_async(dispatch_get_main_queue(),^{[self toast:@"System notifications are disabled. Alerts still appear in Pulse; enable banners in System Settings → Notifications."];});}];
    }
    [[NSUserDefaults standardUserDefaults] setObject:self.settings forKey:@"PulseSettings"];
    [NSApp setActivationPolicy:[self.settings[@"hideDock"] boolValue]?NSApplicationActivationPolicyAccessory:NSApplicationActivationPolicyRegular];
    [self sendState];
}
- (void)exportSnapshot:(id)sender {
    if(!self.snapshot){[self toast:@"Wait for the first live sample."];return;}
    [self.popover performClose:nil];[NSApp activateIgnoringOtherApps:YES];NSSavePanel *panel=[NSSavePanel savePanel];
    panel.nameFieldStringValue=@"Pulse-Snapshot.json";panel.allowedContentTypes=@[UTTypeJSON];
    panel.message=@"Export includes app/process names, local paths, and listening ports. Review it before sharing.";
    if([panel runModal]==1){NSData *data=[NSJSONSerialization dataWithJSONObject:PulseExportObject(self.snapshot,[self.history allObjects],self.alerts) options:NSJSONWritingPrettyPrinted error:NULL];
        [self toast:[data writeToURL:panel.URL atomically:YES]?@"Snapshot exported.":@"Could not write the snapshot."];}
}
- (void)userContentController:(id)c didReceiveScriptMessage:(WKScriptMessage*)message {
    if((message.webView!=self.web&&message.webView!=self.menuWeb)||!message.frameInfo.mainFrame||
        ![message.body isKindOfClass:[NSDictionary class]])return;
    NSDictionary *body=message.body;if(!PulseBridgeMessageIsWellFormed(body))return;
    NSString *action=body[@"action"];
    if([action isEqualToString:@"ready"]){if(message.webView==self.web)self.webReady=YES;else self.menuReady=YES;[self sendState];}
    else if([action isEqualToString:@"pause"])[self togglePause:nil];
    else if([action isEqualToString:@"open"])[self showMain:nil];
    else if([action isEqualToString:@"settings"])[self showSettings:nil];
    else if([action isEqualToString:@"quit"])[NSApp terminate:nil];
    else if([action isEqualToString:@"export"])[self exportSnapshot:nil];
    else if([action isEqualToString:@"clearAlerts"]){[self.alerts removeAllObjects];[self sendState];}
    else if([action isEqualToString:@"saveSettings"]&&[body[@"settings"] isKindOfClass:[NSDictionary class]])[self saveSettings:body[@"settings"]];
    else if([action isEqualToString:@"stopProject"]) {
        for(NSDictionary *p in self.snapshot[@"projects"])if([p[@"pid"] isEqual:body[@"pid"]]){[self stopProjects:@[p]];break;}
    } else if([action isEqualToString:@"stopLow"]) {
        NSMutableArray *list=[NSMutableArray array];for(NSDictionary *p in self.snapshot[@"projects"])if([p[@"lowSeconds"] doubleValue]>=300)[list addObject:p];[self stopProjects:list];
    } else if([action isEqualToString:@"quitApp"]) {
    for(NSDictionary *a in self.snapshot[@"apps"]) {
            pid_t rootPID=[a[@"rootPID"] intValue];
            if(![a[@"id"] isEqual:body[@"id"]]||![a[@"quitAllowed"] boolValue]||
                !PulseAppQuitIsAllowed(a[@"name"],a[@"path"],rootPID,getpid()))continue;
            NSDictionary *rootProcess=nil;
            for(NSDictionary *p in a[@"processes"])if([p[@"pid"] intValue]==rootPID){rootProcess=p;break;}
            NSDictionary *identity=ProcessIdentity(rootPID);
            BOOL sameIdentity=rootProcess&&identity&&[rootProcess[@"uid"] unsignedIntValue]==getuid()&&
                [rootProcess[@"startToken"] isEqual:identity[@"startToken"]]&&[rootProcess[@"path"] isEqual:identity[@"path"]];
            if(!sameIdentity){[self toast:@"That app changed since the process list was sampled. Refresh and try again."];break;}
            NSRunningApplication *app=[NSRunningApplication runningApplicationWithProcessIdentifier:rootPID];
            if(![app.bundleURL.path isEqualToString:a[@"path"]])continue;
            if([self confirm:[NSString stringWithFormat:@"Quit %@?",a[@"name"]] detail:@"Save your work first. Pulse requests a normal quit so the app can show its own save prompts. It will not force-kill the app." button:@"Quit app"])
                [self toast:[app terminate]?@"Quit requested.":@"The app declined the quit request."];
            break;
        }
    } else if([action isEqualToString:@"openPort"]) {
        int port=[body[@"port"] intValue];BOOL known=NO;
        for(NSDictionary *p in self.snapshot[@"projects"])if([p[@"ports"] containsObject:@(port)])known=YES;
        if(known&&port>0&&port<=65535)[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%d",port]]];
    } else if([action isEqualToString:@"revealProject"]) {
        for(NSDictionary *p in self.snapshot[@"projects"])if([p[@"pid"] isEqual:body[@"pid"]]&&[p[@"cwd"] hasPrefix:@"/"]&&
            [[NSFileManager defaultManager] fileExistsAtPath:p[@"cwd"]])
            [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[[NSURL fileURLWithPath:p[@"cwd"]]]];
    }
}
@end

int main(int argc,const char *argv[]) {
    @autoreleasepool {
        if(argc>1&&[[NSString stringWithUTF8String:argv[1]] isEqualToString:@"--diagnose"]) {
            PulseCollector *collector=[PulseCollector new];[collector sample:[NSArray array]];sleep(2);
            puts(JSONString([collector sample:[NSArray array]]).UTF8String);return 0;
        }
        NSApplication *app=[NSApplication sharedApplication];__attribute__((objc_precise_lifetime)) PulseApp *delegate=[PulseApp new];app.delegate=delegate;
        [app run];(void)delegate;
    } return 0;
}
