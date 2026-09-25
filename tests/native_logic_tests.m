#import <Foundation/Foundation.h>
#import "../native/PulseLogic.h"
#include <math.h>
#include <stdint.h>
#include <unistd.h>

static NSUInteger passed=0,failed=0;
#define CHECK(name,...) do { if((__VA_ARGS__)){ passed++; NSLog(@"PASS %@",@name); } else { failed++; NSLog(@"FAIL %@",@name); } } while(0)
static BOOL Near(double a,double b,double e){return fabs(a-b)<=e;}

int main(void) {
    @autoreleasepool {
        uint32_t first[4]={0,0,0,0},next[4]={100,50,100,10};
        PulseCPUReading cpu=PulseCalculateCPU(first,next,YES);
        CHECK("CPU usage uses user, system, idle and nice deltas",cpu.available&&Near(cpu.usage,61.5384615,0.0001)&&Near(cpu.user,42.3076923,0.0001)&&Near(cpu.system,19.2307692,0.0001)&&Near(cpu.idle,38.4615385,0.0001));
        CHECK("CPU subcategories sum to 100 percent",Near(cpu.user+cpu.system+cpu.idle,100,0.0001));
        CHECK("First CPU sample is unavailable",!PulseCalculateCPU(first,next,NO).available);
        uint32_t same[4]={0,0,0,0};CHECK("Zero CPU delta is unavailable",!PulseCalculateCPU(same,same,YES).available);
        uint32_t beforeWrap[4]={UINT32_MAX-4,UINT32_MAX-4,UINT32_MAX-4,UINT32_MAX-4};uint32_t afterWrap[4]={5,5,5,5};
        CHECK("CPU tick counter wrap is handled",Near(PulseCalculateCPU(beforeWrap,afterWrap,YES).usage,75,0.0001));

        CHECK("Memory pressure Normal mapping",[PulseMemoryPressureName(0,YES) isEqualToString:@"Normal"]);
        CHECK("Memory pressure Warning and Urgent mapping",[PulseMemoryPressureName(1,YES) isEqualToString:@"Warning"]&&[PulseMemoryPressureName(2,YES) isEqualToString:@"Warning"]);
        CHECK("Memory pressure Critical and kernel Jetsam mapping",[PulseMemoryPressureName(3,YES) isEqualToString:@"Critical"]&&[PulseMemoryPressureName(4,YES) isEqualToString:@"Jetsam"]);
        CHECK("Unavailable and unknown pressure stay unavailable",[PulseMemoryPressureName(0,NO) isEqualToString:@"Not reported"]&&[PulseMemoryPressureName(99,YES) isEqualToString:@"Not reported"]);
        CHECK("Thermal states map to known labels",[PulseThermalStateName(0) isEqualToString:@"Nominal"]&&[PulseThermalStateName(3) isEqualToString:@"Critical"]&&[PulseThermalStateName(99) isEqualToString:@"Unknown"]);

        PulseHistoryBuffer *history=[[PulseHistoryBuffer alloc] initWithCapacity:3];
        for(NSNumber *n in @[@1,@2,@3,@4,@5])[history appendObject:n];
        CHECK("History ring stays bounded",history.count==3&&history.capacity==3);
        CHECK("History ring returns oldest-to-newest samples",[[history allObjects] isEqual:@[@3,@4,@5]]);

        CHECK("Recognized development runtime executable",PulseIsDevelopmentRuntime(@"/opt/homebrew/bin/node"));
        CHECK("Python versioned runtime is recognized",PulseIsDevelopmentRuntime(@"/usr/bin/python3"));
        CHECK("Relative or unrelated executable is rejected",!PulseIsDevelopmentRuntime(@"node")&&!PulseIsDevelopmentRuntime(@"/usr/bin/WindowServer"));
        NSString *lsof=@"p123\nf3\nn127.0.0.1:3000\nn*:3001\np456\nn[::1]:5173\nn[::]:8080\n";
        NSDictionary *ports=PulseListeningPortsFromLsof(lsof);
        CHECK("lsof parser handles multiple PIDs and IPv4/IPv6 port forms",[ports[@"123"] isEqual:@[@3000,@3001]]&&[ports[@"456"] isEqual:@[@5173,@8080]]);
        CHECK("lsof UTF-8 hex escapes decode Unicode working-directory names",[PulseDecodeLsofEscapedPath(@"/private/tmp/Pulse Test \\xc3\\xb1/server \\xc3\\xbc") isEqualToString:@"/private/tmp/Pulse Test ñ/server ü"]);
        CHECK("Port match uses exact valid intersection",PulsePortSetsIntersect(@[@3000,@4000],ports[@"123"])&&!PulsePortSetsIntersect(@[@3002],ports[@"123"])&&!PulsePortSetsIntersect(@[@70000],ports[@"123"]));

        NSDictionary *expected=@{@"pid":@123,@"path":@"/opt/homebrew/bin/node",@"startToken":@"1:2",@"ports":@[@3000]};
        NSDictionary *live=@{@"pid":@123,@"uid":@(getuid()),@"path":@"/opt/homebrew/bin/node",@"startToken":@"1:2"};
        CHECK("Project identity matches exact pid, uid, path and start time",PulseProjectIdentityMatches(expected,live,getuid(),getpid()));
        NSMutableDictionary *other=[live mutableCopy];other[@"startToken"]=@"1:3";
        CHECK("Project identity rejects a reused PID",!PulseProjectIdentityMatches(expected,other,getuid(),getpid()));
        other=[live mutableCopy];other[@"path"]=@"/tmp/node";
        CHECK("Project identity rejects a changed executable",!PulseProjectIdentityMatches(expected,other,getuid(),getpid()));
        other=[live mutableCopy];other[@"uid"]=@(getuid()+1);
        CHECK("Project identity rejects another user's process",!PulseProjectIdentityMatches(expected,other,getuid(),getpid()));
        other=[live mutableCopy];other[@"pid"]=@(getpid());
        CHECK("Project identity protects Pulse Monitor itself",!PulseProjectIdentityMatches(expected,other,getuid(),getpid()));
        CHECK("Normal app quit excludes self and critical system apps",PulseAppQuitIsAllowed(@"TextEdit",@"/System/Applications/TextEdit.app",4321,getpid())&&!PulseAppQuitIsAllowed(@"Finder",@"/System/Library/CoreServices/Finder.app",4321,getpid())&&!PulseAppQuitIsAllowed(@"Pulse Monitor",@"/Applications/Pulse Monitor.app",getpid(),getpid()));

        NSArray *processes=@[
            @{@"pid":@10,@"ppid":@1,@"uid":@(getuid()),@"path":@"/Applications/Example.app/Contents/MacOS/Example",@"name":@"Example",@"cpu":@3,@"memory":@100,@"rss":@90,@"footprint":@YES},
            @{@"pid":@11,@"ppid":@10,@"uid":@(getuid()),@"path":@"/usr/libexec/helper",@"name":@"helper",@"cpu":@2,@"memory":@50,@"rss":@40,@"footprint":@YES},
            @{@"pid":@12,@"ppid":@10,@"uid":@(getuid()+1),@"path":@"/tmp/untrusted-child",@"name":@"untrusted",@"cpu":@1,@"memory":@25,@"rss":@20,@"footprint":@NO}
        ];
        NSArray *running=@[@{@"pid":@10,@"path":@"/Applications/Example.app",@"name":@"Example App"}];
        NSArray *groups=PulseGroupProcesses(processes,running);NSDictionary *appGroup=nil,*background=nil;
        for(NSDictionary *g in groups){if([g[@"id"] isEqual:@"/Applications/Example.app"])appGroup=g;else if([g[@"id"] isEqual:@"__background__"])background=g;}
        CHECK("Process grouping associates same-user helpers with app",appGroup&&[appGroup[@"count"] integerValue]==2&&[appGroup[@"name"] isEqual:@"Example App"]);
        CHECK("Process grouping keeps cross-user child separate",background&&[background[@"count"] integerValue]==1);

        NSDictionary *defaults=@{@"theme":@"system",@"interval":@2,@"cpuThreshold":@80,@"cpuDuration":@60,@"growthMB":@512,@"alerts":@NO,@"hideDock":@NO};
        NSDictionary *normalized=PulseApplyingSettings(defaults,@{@"theme":@"nope",@"interval":@5,@"cpuThreshold":@5000,@"cpuDuration":@20,@"growthMB":@64,@"alerts":@YES,@"hideDock":@"true"});
        CHECK("Preference validation filters invalid values and clamps ranges",[normalized[@"theme"] isEqual:@"system"]&&[normalized[@"interval"] isEqual:@5]&&[normalized[@"cpuThreshold"] isEqual:@1000]&&[normalized[@"cpuDuration"] isEqual:@30]&&[normalized[@"growthMB"] isEqual:@128]&&[normalized[@"alerts"] boolValue]&&![normalized[@"hideDock"] boolValue]);
        NSString *suite=[NSString stringWithFormat:@"local.pulse.test.%@",NSUUID.UUID.UUIDString];NSUserDefaults *prefs=[[NSUserDefaults alloc] initWithSuiteName:suite];
        [prefs setObject:normalized forKey:@"PulseSettings"];[prefs synchronize];NSDictionary *reread=[[NSUserDefaults alloc] initWithSuiteName:suite].dictionaryRepresentation[@"PulseSettings"];
        CHECK("Normalized settings survive an isolated preferences reload",[reread[@"interval"] isEqual:@5]&&[reread[@"alerts"] boolValue]);
        [prefs removePersistentDomainForName:suite];

        CHECK("Sustained alert waits for the configured duration",PulseAlertConditionIsSustained(10,70,60)&&!PulseAlertConditionIsSustained(10,69,60)&&!PulseAlertConditionIsSustained(70,10,1));
        NSMutableDictionary *cooldowns=[NSMutableDictionary dictionary];
        CHECK("Alert cooldown allows first alert then suppresses repeats",PulseCooldownAllows(cooldowns,@"app:cpu",100,900)&&!PulseCooldownAllows(cooldowns,@"app:cpu",500,900)&&PulseCooldownAllows(cooldowns,@"app:cpu",1000,900));

        CHECK("Bridge accepts supported settings payload",PulseBridgeMessageIsWellFormed(@{@"action":@"saveSettings",@"settings":@{@"interval":@2}}));
        CHECK("Bridge rejects unknown action and malformed payload",!PulseBridgeMessageIsWellFormed(@{@"action":@"executeShell",@"command":@"rm -rf"})&&!PulseBridgeMessageIsWellFormed((NSDictionary*)(id)@[@"pause"]));
        CHECK("Bridge validates PID, port and quit identifiers",PulseBridgeMessageIsWellFormed(@{@"action":@"stopProject",@"pid":@42})&&PulseBridgeMessageIsWellFormed(@{@"action":@"openPort",@"port":@65535})&&PulseBridgeMessageIsWellFormed(@{@"action":@"quitApp",@"id":@"/Applications/App.app"}));
        CHECK("Bridge rejects fractional/out-of-range identifiers",!PulseBridgeMessageIsWellFormed(@{@"action":@"openPort",@"port":@80.5})&&!PulseBridgeMessageIsWellFormed(@{@"action":@"stopProject",@"pid":@1})&&!PulseBridgeMessageIsWellFormed(@{@"action":@"quitApp",@"id":@""}));

        NSDictionary *snapshot=@{@"timestamp":@1790210100,@"host":@"private-host",@"disk":@{@"available":@NO,@"free":[NSNull null],@"volume":@"/Users/private"},
            @"apps":@[@{@"pid":@42,@"processes":@[@{@"pid":@43,@"uid":@501,@"ppid":@42,@"startToken":@"private-token",@"command":@"private command",@"name":@"worker"}]}],
            @"projects":@[@{@"pid":@44,@"uid":@501,@"startToken":@"private-token",@"path":@"/private/runtime",@"cwd":@"/private/project",@"ports":@[@8123]}]};
        NSDictionary *export=PulseExportObject(snapshot,@[@{@"t":@1790210100,@"cpu":[NSNull null]}],@[@{@"time":@1790210100,@"title":@"Test"}]);
        NSString *iso=export[@"snapshot"][@"timestamp"];
        CHECK("Export declares stable version, exported time and byte units",[export[@"schemaVersion"] isEqual:@1]&&[export[@"exportedAt"] isKindOfClass:[NSString class]]&&[export[@"units"][@"memory"] isEqual:@"bytes"]);
        CHECK("Export converts snapshot, history and alert times to ISO 8601",[iso containsString:@"T"]&&[iso hasSuffix:@"Z"]&&[export[@"history"][0][@"t"] isEqual:iso]&&[export[@"alerts"][0][@"time"] isEqual:iso]);
        CHECK("Export preserves numeric PIDs and unavailable null metrics",[export[@"snapshot"][@"apps"][0][@"pid"] isKindOfClass:[NSNumber class]]&&export[@"snapshot"][@"disk"][@"free"]==[NSNull null]&&export[@"history"][0][@"cpu"]==[NSNull null]&&! [export[@"snapshot"][@"disk"][@"available"] boolValue]);
        CHECK("Export removes host, home-volume path and internal process identity fields",!export[@"snapshot"][@"host"]&&[export[@"snapshot"][@"disk"][@"volume"] isEqual:@"Home volume"]&&!export[@"snapshot"][@"apps"][0][@"processes"][0][@"uid"]&&!export[@"snapshot"][@"apps"][0][@"processes"][0][@"startToken"]&&!export[@"snapshot"][@"projects"][0][@"path"]);
        NSData *json=[NSJSONSerialization dataWithJSONObject:export options:0 error:NULL];id parsed=json?[NSJSONSerialization JSONObjectWithData:json options:0 error:NULL]:nil;
        CHECK("Export object serializes as valid JSON",[parsed isKindOfClass:[NSDictionary class]]&&[parsed[@"schemaVersion"] isEqual:@1]);

        NSLog(@"Native logic tests: %lu passed, %lu failed",(unsigned long)passed,(unsigned long)failed);
        return failed?1:0;
    }
}
