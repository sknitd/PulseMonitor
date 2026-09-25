#pragma once

#if defined(PULSE_CROSS_HEADERS)
#import "Platform.h"
#else
#import <Foundation/Foundation.h>
#import <sys/types.h>
#endif

typedef struct {
    BOOL available;
    double usage;
    double user;
    double system;
    double idle;
} PulseCPUReading;

@interface PulseHistoryBuffer : NSObject
@property(nonatomic, readonly) NSUInteger count;
@property(nonatomic, readonly) NSUInteger capacity;
- (instancetype)initWithCapacity:(NSUInteger)capacity;
- (void)appendObject:(id)object;
- (NSArray *)allObjects;
@end

PulseCPUReading PulseCalculateCPU(const uint32_t previous[4], const uint32_t current[4], BOOL hasPrevious);
NSString *PulseMemoryPressureName(int level, BOOL available);
NSString *PulseThermalStateName(NSInteger state);
BOOL PulseIsDevelopmentRuntime(NSString *executablePath);
NSDictionary<NSString *, NSArray<NSNumber *> *> *PulseListeningPortsFromLsof(NSString *output);
NSString *PulseDecodeLsofEscapedPath(NSString *path);
BOOL PulsePortSetsIntersect(NSArray *expectedPorts, NSArray *livePorts);
BOOL PulseProjectIdentityMatches(NSDictionary *expected, NSDictionary *live, uid_t currentUID, pid_t ownPID);
BOOL PulseAppQuitIsAllowed(NSString *name, NSString *bundlePath, pid_t pid, pid_t ownPID);
NSArray *PulseGroupProcesses(NSArray *processes, NSArray *runningApplications);
NSDictionary *PulseApplyingSettings(NSDictionary *current, NSDictionary *input);
BOOL PulseAlertConditionIsSustained(double startedAt, double now, double duration);
BOOL PulseCooldownAllows(NSMutableDictionary *cooldowns, NSString *key, double now, double cooldown);
BOOL PulseNumberIsIntegerInRange(id value, NSInteger minimum, NSInteger maximum);
BOOL PulseBridgeMessageIsWellFormed(NSDictionary *message);
NSDictionary *PulseExportObject(NSDictionary *snapshot, NSArray *history, NSArray *alerts);
NSString *PulseISO8601Timestamp(NSTimeInterval timestamp);
