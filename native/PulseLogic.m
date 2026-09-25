#import "PulseLogic.h"
#import <math.h>
#import <limits.h>

@interface PulseHistoryBuffer () {
    NSMutableArray *_storage;
    NSUInteger _oldestIndex;
}
@property(nonatomic, readwrite) NSUInteger capacity;
@end

@implementation PulseHistoryBuffer
- (instancetype)initWithCapacity:(NSUInteger)capacity {
    if ((self = [super init])) {
        _capacity = MAX(1, capacity);
        _storage = [NSMutableArray arrayWithCapacity:_capacity];
    }
    return self;
}
- (NSUInteger)count { return _storage.count; }
- (void)appendObject:(id)object {
    if (!object) return;
    if (_storage.count < _capacity) {
        [_storage addObject:object];
        return;
    }
    _storage[_oldestIndex] = object;
    _oldestIndex = (_oldestIndex + 1) % _capacity;
}
- (NSArray *)allObjects {
    if (_storage.count < _capacity || _oldestIndex == 0) return [_storage copy];
    NSMutableArray *ordered = [NSMutableArray arrayWithCapacity:_storage.count];
    [ordered addObjectsFromArray:[_storage subarrayWithRange:NSMakeRange(_oldestIndex, _storage.count - _oldestIndex)]];
    [ordered addObjectsFromArray:[_storage subarrayWithRange:NSMakeRange(0, _oldestIndex)]];
    return ordered;
}
@end

PulseCPUReading PulseCalculateCPU(const uint32_t previous[4], const uint32_t current[4], BOOL hasPrevious) {
    PulseCPUReading result = {0};
    if (!hasPrevious) return result;
    double delta[4], total = 0;
    for (int i = 0; i < 4; i++) {
        // CPU counters are unsigned and can wrap. Unsigned subtraction is intentional.
        delta[i] = (uint32_t)(current[i] - previous[i]);
        total += delta[i];
    }
    if (total <= 0) return result;
    result.available = YES;
    result.user = 100.0 * (delta[0] + delta[3]) / total;
    result.system = 100.0 * delta[1] / total;
    result.idle = 100.0 * delta[2] / total;
    result.usage = result.user + result.system;
    return result;
}

NSString *PulseMemoryPressureName(int level, BOOL available) {
    if (!available) return @"Not reported";
    switch (level) {
        case 0: return @"Normal";
        case 1:
        case 2: return @"Warning"; // XNU's Urgent level is synonymous with Warning.
        case 3: return @"Critical";
        case 4: return @"Jetsam"; // Kernel-only threshold, not a userland critical state.
        default: return @"Not reported";
    }
}

NSString *PulseThermalStateName(NSInteger state) {
    switch (state) {
        case 0: return @"Nominal";
        case 1: return @"Fair";
        case 2: return @"Serious";
        case 3: return @"Critical";
        default: return @"Unknown";
    }
}

static NSString *PulseOuterApp(NSString *path) {
    if (![path isKindOfClass:[NSString class]] || path.length == 0) return @"";
    NSRange range = [path rangeOfString:@".app/"];
    if (range.location != NSNotFound) return [path substringToIndex:range.location + 4];
    return [path hasSuffix:@".app"] ? path : @"";
}

BOOL PulseIsDevelopmentRuntime(NSString *executablePath) {
    if (![executablePath isKindOfClass:[NSString class]] || ![executablePath hasPrefix:@"/"]) return NO;
    NSString *name = executablePath.lastPathComponent.lowercaseString;
    return [name isEqualToString:@"node"] || [name isEqualToString:@"bun"] || [name isEqualToString:@"deno"] ||
        [name hasPrefix:@"python"] || [name hasPrefix:@"ruby"] || [name isEqualToString:@"java"] ||
        [name hasPrefix:@"php"] || [name isEqualToString:@"go"] || [name isEqualToString:@"uvicorn"] ||
        [name isEqualToString:@"gunicorn"] || [name isEqualToString:@"vite"] || [name isEqualToString:@"next-server"];
}

static BOOL PulseDigits(NSString *value) {
    if (![value isKindOfClass:[NSString class]] || value.length == 0) return NO;
    for (NSUInteger i = 0; i < value.length; i++) {
        unichar c = [value characterAtIndex:i];
        if (c < '0' || c > '9') return NO;
    }
    return YES;
}

NSDictionary<NSString *, NSArray<NSNumber *> *> *PulseListeningPortsFromLsof(NSString *output) {
    NSMutableDictionary *portsByPID = [NSMutableDictionary dictionary];
    NSString *currentPID = nil;
    for (NSString *line in [output componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        if ([line hasPrefix:@"p"]) {
            NSString *candidate = [line substringFromIndex:1];
            currentPID = PulseDigits(candidate) ? candidate : nil;
            continue;
        }
        if (![line hasPrefix:@"n"] || !currentPID) continue;
        NSString *address = [line substringFromIndex:1];
        NSArray *parts = [address componentsSeparatedByString:@":"];
        if (parts.count < 2) continue;
        NSString *tail = parts.lastObject;
        if (!PulseDigits(tail)) continue;
        NSInteger port = tail.integerValue;
        if (port < 1 || port > 65535) continue;
        if (!portsByPID[currentPID]) portsByPID[currentPID] = [NSMutableArray array];
        NSNumber *number = @(port);
        if (![portsByPID[currentPID] containsObject:number]) [portsByPID[currentPID] addObject:number];
    }
    return portsByPID;
}

static int PulseHexValue(unichar c) {
    if(c>='0'&&c<='9')return (int)(c-'0');
    if(c>='a'&&c<='f')return (int)(c-'a'+10);
    if(c>='A'&&c<='F')return (int)(c-'A'+10);
    return -1;
}

NSString *PulseDecodeLsofEscapedPath(NSString *path) {
    if(![path isKindOfClass:[NSString class]])return @"";
    NSMutableData *bytes=[NSMutableData data];
    for(NSUInteger i=0;i<path.length;) {
        if(i+3<path.length&&[path characterAtIndex:i]=='\\'&&[path characterAtIndex:i+1]=='x') {
            int high=PulseHexValue([path characterAtIndex:i+2]),low=PulseHexValue([path characterAtIndex:i+3]);
            if(high>=0&&low>=0) {
                unsigned char byte=(unsigned char)((high<<4)|low);[bytes appendBytes:&byte length:1];i+=4;continue;
            }
        }
        NSUInteger length=1;unichar c=[path characterAtIndex:i];
        if(c>=0xd800&&c<=0xdbff&&i+1<path.length) {
            unichar next=[path characterAtIndex:i+1];if(next>=0xdc00&&next<=0xdfff)length=2;
        }
        NSData *encoded=[[path substringWithRange:NSMakeRange(i,length)] dataUsingEncoding:NSUTF8StringEncoding];
        if(encoded.length)[bytes appendBytes:encoded.bytes length:encoded.length];
        i+=length;
    }
    return [[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding] ?: path;
}

BOOL PulsePortSetsIntersect(NSArray *expectedPorts, NSArray *livePorts) {
    for (id expected in expectedPorts) {
        if (![expected isKindOfClass:[NSNumber class]]) continue;
        double raw = [expected doubleValue];
        if (!isfinite(raw) || floor(raw) != raw || raw < 1 || raw > 65535) continue;
        NSNumber *port = @((NSInteger)raw);
        if ([livePorts containsObject:port]) return YES;
    }
    return NO;
}

BOOL PulseNumberIsIntegerInRange(id value, NSInteger minimum, NSInteger maximum) {
    if (![value isKindOfClass:[NSNumber class]]) return NO;
    double number = [value doubleValue];
    return isfinite(number) && floor(number) == number && number >= minimum && number <= maximum;
}

BOOL PulseProjectIdentityMatches(NSDictionary *expected, NSDictionary *live, uid_t currentUID, pid_t ownPID) {
    if (![expected isKindOfClass:[NSDictionary class]] || ![live isKindOfClass:[NSDictionary class]]) return NO;
    id expectedPID = expected[@"pid"], livePID = live[@"pid"];
    if (!PulseNumberIsIntegerInRange(expectedPID, 2, INT_MAX) || !PulseNumberIsIntegerInRange(livePID, 2, INT_MAX)) return NO;
    NSInteger pid = [expectedPID integerValue];
    if (pid == ownPID || pid != [livePID integerValue]) return NO;
    if (![live[@"uid"] isKindOfClass:[NSNumber class]] || [live[@"uid"] unsignedIntValue] != currentUID) return NO;
    NSString *expectedPath = expected[@"path"], *livePath = live[@"path"];
    NSString *expectedBirth = expected[@"startToken"], *liveBirth = live[@"startToken"];
    return [expectedPath isKindOfClass:[NSString class]] && expectedPath.length > 0 &&
        [livePath isKindOfClass:[NSString class]] && [expectedPath isEqualToString:livePath] &&
        [expectedBirth isKindOfClass:[NSString class]] && expectedBirth.length > 0 &&
        [liveBirth isKindOfClass:[NSString class]] && [expectedBirth isEqualToString:liveBirth] &&
        PulseIsDevelopmentRuntime(livePath);
}

BOOL PulseAppQuitIsAllowed(NSString *name, NSString *bundlePath, pid_t pid, pid_t ownPID) {
    if(pid<2||pid==ownPID||![name isKindOfClass:[NSString class]]||name.length==0||
       ![bundlePath isKindOfClass:[NSString class]]||bundlePath.length==0)return NO;
    NSString *key=name.lowercaseString;
    return ![@[@"finder",@"dock",@"windowserver",@"loginwindow",@"systemuiserver",@"controlcenter",@"pulse monitor"] containsObject:key];
}

static NSInteger PulseMemoryDescending(id a, id b) {
    double difference = [b[@"memory"] doubleValue] - [a[@"memory"] doubleValue];
    return difference > 0 ? 1 : difference < 0 ? -1 : 0;
}

NSArray *PulseGroupProcesses(NSArray *processes, NSArray *runningApplications) {
    NSMutableDictionary *byPID = [NSMutableDictionary dictionary];
    NSMutableDictionary *appNames = [NSMutableDictionary dictionary];
    NSMutableDictionary *appRoots = [NSMutableDictionary dictionary];
    NSMutableDictionary *appPathByRootPID = [NSMutableDictionary dictionary];
    for (NSDictionary *process in processes) {
        if (![process[@"pid"] isKindOfClass:[NSNumber class]]) continue;
        byPID[[process[@"pid"] stringValue]] = process;
    }
    for (NSDictionary *app in runningApplications) {
        NSString *path = app[@"path"];
        NSNumber *pid = app[@"pid"];
        if (![path isKindOfClass:[NSString class]] || path.length == 0 || ![pid isKindOfClass:[NSNumber class]]) continue;
        appNames[path] = app[@"name"] ?: path.lastPathComponent;
        appRoots[path] = pid;
        appPathByRootPID[[pid stringValue]] = path;
    }

    NSMutableDictionary *groups = [NSMutableDictionary dictionary];
    for (NSMutableDictionary *source in processes) {
        NSMutableDictionary *process = [source mutableCopy];
        NSString *appPath = PulseOuterApp(process[@"path"]);
        if (appPath.length == 0) appPath = PulseOuterApp(appPathByRootPID[[process[@"pid"] stringValue]]);
        NSDictionary *ancestor = process;
        NSMutableSet *seen = [NSMutableSet set];
        int uid = [process[@"uid"] intValue];
        for (int depth = 0; appPath.length == 0 && depth < 32; depth++) {
            NSString *parentKey = [ancestor[@"ppid"] stringValue];
            if (!parentKey || [seen containsObject:parentKey]) break;
            [seen addObject:parentKey];
            ancestor = byPID[parentKey];
            if (!ancestor || [ancestor[@"uid"] intValue] != uid) break;
            appPath = PulseOuterApp(ancestor[@"path"]);
            if (appPath.length == 0) appPath = PulseOuterApp(appPathByRootPID[[ancestor[@"pid"] stringValue]]);
        }
        NSString *key = appPath.length ? appPath : @"__background__";
        process[@"appKey"] = key;
        NSMutableDictionary *group = groups[key];
        if (!group) {
            NSString *name = appPath.length ? (appNames[appPath] ?: appPath.lastPathComponent.stringByDeletingPathExtension) : @"System & background";
            group = [@{@"id":key, @"path":appPath, @"name":name, @"cpu":@0, @"memory":@0, @"rss":@0,
                @"processes":[NSMutableArray array], @"count":@0, @"fallbackCount":@0, @"rootPID":appRoots[appPath] ?: @0} mutableCopy];
            groups[key] = group;
        }
        group[@"cpu"] = @([group[@"cpu"] doubleValue] + [process[@"cpu"] doubleValue]);
        group[@"memory"] = @([group[@"memory"] doubleValue] + [process[@"memory"] doubleValue]);
        group[@"rss"] = @([group[@"rss"] doubleValue] + [process[@"rss"] doubleValue]);
        group[@"count"] = @([group[@"count"] integerValue] + 1);
        if (![process[@"footprint"] boolValue]) group[@"fallbackCount"] = @([group[@"fallbackCount"] integerValue] + 1);
        [group[@"processes"] addObject:process];
    }

    NSMutableArray *apps = [groups.allValues mutableCopy];
    [apps sortUsingComparator:^NSInteger(id a, id b) { return PulseMemoryDescending(a, b); }];
    for (NSMutableDictionary *app in apps) {
        [app[@"processes"] sortUsingComparator:^NSInteger(id a, id b) { return PulseMemoryDescending(a, b); }];
    }
    return apps;
}

NSDictionary *PulseApplyingSettings(NSDictionary *current, NSDictionary *input) {
    NSMutableDictionary *settings = [current mutableCopy] ?: [NSMutableDictionary dictionary];
    if (![input isKindOfClass:[NSDictionary class]]) return settings;
    id theme = input[@"theme"];
    if ([theme isKindOfClass:[NSString class]] && [@[@"system", @"light", @"dark"] containsObject:theme]) settings[@"theme"] = theme;
    id interval = input[@"interval"];
    if ([interval isKindOfClass:[NSNumber class]] && [@[@1, @2, @5, @10] containsObject:interval]) settings[@"interval"] = interval;
    for (NSString *key in @[@"alerts", @"hideDock"]) {
        id value = input[key];
        if ([value isKindOfClass:[NSNumber class]]) settings[key] = @([value boolValue]);
    }
    for (NSString *key in @[@"cpuThreshold", @"cpuDuration", @"growthMB"]) {
        id value = input[key];
        if (![value isKindOfClass:[NSNumber class]] || !isfinite([value doubleValue])) continue;
        double minimum = [key isEqualToString:@"cpuThreshold"] ? 10 : [key isEqualToString:@"cpuDuration"] ? 30 : 128;
        double maximum = [key isEqualToString:@"cpuThreshold"] ? 1000 : [key isEqualToString:@"cpuDuration"] ? 600 : 8192;
        settings[key] = @(fmin(maximum, fmax(minimum, [value doubleValue])));
    }
    return settings;
}

BOOL PulseAlertConditionIsSustained(double startedAt, double now, double duration) {
    return isfinite(startedAt) && isfinite(now) && isfinite(duration) && duration >= 0 && now >= startedAt && now - startedAt >= duration;
}

BOOL PulseCooldownAllows(NSMutableDictionary *cooldowns, NSString *key, double now, double cooldown) {
    if (![cooldowns isKindOfClass:[NSMutableDictionary class]] || ![key isKindOfClass:[NSString class]] || key.length == 0 ||
        !isfinite(now) || !isfinite(cooldown) || cooldown < 0) return NO;
    NSNumber *last = cooldowns[key];
    if ([last isKindOfClass:[NSNumber class]] && now - last.doubleValue < cooldown) return NO;
    cooldowns[key] = @(now);
    return YES;
}

BOOL PulseBridgeMessageIsWellFormed(NSDictionary *message) {
    if (![message isKindOfClass:[NSDictionary class]]) return NO;
    NSString *action = message[@"action"];
    if (![action isKindOfClass:[NSString class]]) return NO;
    if ([@[@"ready", @"pause", @"open", @"settings", @"quit", @"export", @"clearAlerts", @"stopLow"] containsObject:action]) return YES;
    if ([action isEqualToString:@"stopProject"] || [action isEqualToString:@"revealProject"])
        return PulseNumberIsIntegerInRange(message[@"pid"], 2, INT_MAX);
    if ([action isEqualToString:@"openPort"])
        return PulseNumberIsIntegerInRange(message[@"port"], 1, 65535);
    if ([action isEqualToString:@"quitApp"]) {
        id identifier = message[@"id"];
        return [identifier isKindOfClass:[NSString class]] && [identifier length] > 0 && [identifier length] <= 1024;
    }
    if ([action isEqualToString:@"saveSettings"]) return [message[@"settings"] isKindOfClass:[NSDictionary class]];
    return NO;
}

NSDictionary *PulseExportObject(NSDictionary *snapshot, NSArray *history, NSArray *alerts) {
    NSMutableDictionary *snapshotCopy=[snapshot mutableCopy] ?: [NSMutableDictionary dictionary];
    [snapshotCopy removeObjectForKey:@"host"];
    id timestamp=snapshotCopy[@"timestamp"];
    if([timestamp isKindOfClass:[NSNumber class]])snapshotCopy[@"timestamp"]=PulseISO8601Timestamp([timestamp doubleValue]);
    if([snapshotCopy[@"disk"] isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *disk=[snapshotCopy[@"disk"] mutableCopy];disk[@"volume"]=@"Home volume";snapshotCopy[@"disk"]=disk;
    }
    if([snapshotCopy[@"apps"] isKindOfClass:[NSArray class]]) {
        NSMutableArray *apps=[NSMutableArray arrayWithCapacity:[snapshotCopy[@"apps"] count]];
        for(NSDictionary *app in snapshotCopy[@"apps"]) {
            if(![app isKindOfClass:[NSDictionary class]])continue;
            NSMutableDictionary *appCopy=[app mutableCopy];
            if([appCopy[@"processes"] isKindOfClass:[NSArray class]]) {
                NSMutableArray *processes=[NSMutableArray arrayWithCapacity:[appCopy[@"processes"] count]];
                for(NSDictionary *process in appCopy[@"processes"]) {
                    if(![process isKindOfClass:[NSDictionary class]])continue;
                    NSMutableDictionary *processCopy=[process mutableCopy];
                    for(NSString *key in @[@"uid",@"ppid",@"startToken",@"start",@"command"])[processCopy removeObjectForKey:key];
                    [processes addObject:processCopy];
                }
                appCopy[@"processes"]=processes;
            }
            [apps addObject:appCopy];
        }
        snapshotCopy[@"apps"]=apps;
    }
    if([snapshotCopy[@"projects"] isKindOfClass:[NSArray class]]) {
        NSMutableArray *projects=[NSMutableArray arrayWithCapacity:[snapshotCopy[@"projects"] count]];
        for(NSDictionary *project in snapshotCopy[@"projects"]) {
            if(![project isKindOfClass:[NSDictionary class]])continue;
            NSMutableDictionary *projectCopy=[project mutableCopy];
            for(NSString *key in @[@"uid",@"startToken",@"start",@"path"])[projectCopy removeObjectForKey:key];
            [projects addObject:projectCopy];
        }
        snapshotCopy[@"projects"]=projects;
    }
    NSMutableArray *historyCopy=[NSMutableArray arrayWithCapacity:history.count];
    for(NSDictionary *point in history) {
        NSMutableDictionary *copy=[point mutableCopy];
        id time=copy[@"t"];
        if([time isKindOfClass:[NSNumber class]])copy[@"t"]=PulseISO8601Timestamp([time doubleValue]);
        [historyCopy addObject:copy];
    }
    NSMutableArray *alertsCopy=[NSMutableArray arrayWithCapacity:alerts.count];
    for(NSDictionary *alert in alerts) {
        NSMutableDictionary *copy=[alert mutableCopy];
        id time=copy[@"time"];
        if([time isKindOfClass:[NSNumber class]])copy[@"time"]=PulseISO8601Timestamp([time doubleValue]);
        [alertsCopy addObject:copy];
    }
    NSISO8601DateFormatter *formatter=[NSISO8601DateFormatter new];
    return @{@"schemaVersion":@1, @"exportedAt":[formatter stringFromDate:[NSDate date]],
        @"units":@{@"memory":@"bytes",@"diskCapacity":@"bytes",@"diskThroughput":@"bytesPerSecond",
                    @"networkTotals":@"bytes",@"networkThroughput":@"bytesPerSecond"},
        @"snapshot":snapshotCopy, @"history":historyCopy, @"alerts":alertsCopy};
}

NSString *PulseISO8601Timestamp(NSTimeInterval timestamp) {
    if(!isfinite(timestamp)||timestamp<0)return @"";
    NSISO8601DateFormatter *formatter=[NSISO8601DateFormatter new];
    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:timestamp]] ?: @"";
}
