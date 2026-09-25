#pragma once
#if !defined(PULSE_CROSS_HEADERS)
#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <UserNotifications/UserNotifications.h>
#import <ServiceManagement/ServiceManagement.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/ps/IOPowerSources.h>
#import <Metal/Metal.h>
#import <mach/mach.h>
#import <sys/sysctl.h>
#import <libproc.h>
#import <sys/proc_info.h>
#import <signal.h>
#import <unistd.h>
#import <stdio.h>
#else
// Minimal declarations for cross-compiling. macOS rebuilds use Apple's SDK above.
// These declarations contain no implementation and are not a replacement SDK.
typedef unsigned long NSUInteger; typedef long NSInteger; typedef double NSTimeInterval; typedef double CGFloat;
typedef unsigned int uint32_t; typedef unsigned long long uint64_t; typedef long long int64_t;
typedef unsigned long size_t; typedef int pid_t; typedef unsigned int uid_t;
typedef unsigned short unichar;
#if defined(__arm64__)
typedef _Bool BOOL;
#else
typedef signed char BOOL;
#endif
#define YES __objc_yes
#define NO __objc_no
#define nil ((id)0)
#define NULL ((void *)0)
#define NSNotFound ((NSUInteger)0x7fffffffffffffffUL)
#define MIN(a,b) ((a)<(b)?(a):(b))
#define MAX(a,b) ((a)>(b)?(a):(b))
typedef struct {NSUInteger location,length;} NSRange;
typedef struct {CGFloat x,y;} NSPoint; typedef struct {CGFloat width,height;} NSSize;
typedef struct {NSPoint origin;NSSize size;} NSRect;
static inline NSRect NSMakeRect(CGFloat x,CGFloat y,CGFloat w,CGFloat h){return (NSRect){{x,y},{w,h}};}
static inline NSSize NSMakeSize(CGFloat w,CGFloat h){return (NSSize){w,h};}
static inline NSRange NSMakeRange(NSUInteger a,NSUInteger b){return (NSRange){a,b};}
#define NSUTF8StringEncoding 4
#define NSJSONWritingPrettyPrinted 1
#define NSWindowStyleMaskTitled 1
#define NSWindowStyleMaskClosable 2
#define NSWindowStyleMaskMiniaturizable 4
#define NSWindowStyleMaskResizable 8
#define NSBackingStoreBuffered 2
#define NSViewWidthSizable 2
#define NSViewHeightSizable 16
#define NSApplicationActivationPolicyRegular 0
#define NSApplicationActivationPolicyAccessory 1
#define NSVariableStatusItemLength -1
#define NSImageLeft 2
#define NSPopoverBehaviorTransient 1
#define NSMinYEdge 1
#define NSAlertStyleWarning 0
#define NSAlertFirstButtonReturn 1000
#define UNAuthorizationOptionBadge 1
#define UNAuthorizationOptionSound 2
#define UNAuthorizationOptionAlert 4
#define UNNotificationPresentationOptionBanner 16
#define UNNotificationPresentationOptionSound 2
typedef NSInteger WKNavigationActionPolicy;
typedef NSUInteger UNNotificationPresentationOptions;
#define NSBitmapImageFileTypePNG 4
#define NSCompositingOperationSourceOver 2
#define SMAppServiceStatusEnabled 1
#define SIGTERM 15
#define SIGKILL 9
@class NSString,NSArray,NSMutableArray,NSDictionary,NSMutableDictionary,NSNumber,NSDate,NSISO8601DateFormatter,NSData,NSURL,NSError,NSSet;
@protocol NSObject
- (BOOL)isKindOfClass:(Class)c; - (BOOL)respondsToSelector:(SEL)s;
@end
@protocol NSCopying @end
@protocol NSFastEnumeration
- (NSUInteger)countByEnumeratingWithState:(void*)state objects:(id __unsafe_unretained*)objects count:(NSUInteger)count;
@end
__attribute__((objc_root_class)) @interface NSObject <NSObject> {Class isa;}
+ (instancetype)alloc; + (instancetype)new; + (Class)class;
- (instancetype)init; - (id)copy; - (id)mutableCopy; - (BOOL)isEqual:(id)o;
@end
@interface NSString : NSObject <NSCopying>
+ (instancetype)stringWithUTF8String:(const char*)s; + (instancetype)stringWithFormat:(NSString*)f,...;
- (instancetype)initWithData:(NSData*)d encoding:(NSUInteger)e;
@property(readonly) NSUInteger length; @property(readonly) const char* UTF8String;
@property(readonly) NSString *lastPathComponent,*stringByDeletingLastPathComponent,*stringByDeletingPathExtension,*lowercaseString;
- (NSString*)stringByAppendingPathComponent:(NSString*)s; - (NSString*)stringByAppendingString:(NSString*)s;
- (NSString*)stringByTrimmingCharactersInSet:(id)s;
- (NSString*)stringByReplacingOccurrencesOfString:(NSString*)a withString:(NSString*)b;
- (NSArray*)componentsSeparatedByString:(NSString*)s; - (NSArray*)componentsSeparatedByCharactersInSet:(id)s;
- (NSString*)substringWithRange:(NSRange)r; - (NSString*)substringToIndex:(NSUInteger)n;
- (NSString*)substringFromIndex:(NSUInteger)n; - (NSRange)rangeOfString:(NSString*)s;
- (unichar)characterAtIndex:(NSUInteger)i;
- (BOOL)hasPrefix:(NSString*)s; - (BOOL)hasSuffix:(NSString*)s; - (BOOL)containsString:(NSString*)s; - (BOOL)isEqualToString:(NSString*)s;
- (NSData*)dataUsingEncoding:(NSUInteger)e; - (NSInteger)integerValue; - (int)intValue; - (double)doubleValue; - (long long)longLongValue;
- (BOOL)writeToURL:(NSURL*)u atomically:(BOOL)b encoding:(NSUInteger)e error:(NSError**)err;
@end
@interface NSNumber : NSObject <NSCopying>
+ (NSNumber*)numberWithInteger:(NSInteger)x; + (NSNumber*)numberWithUnsignedInteger:(NSUInteger)x;
+ (NSNumber*)numberWithInt:(int)x; + (NSNumber*)numberWithUnsignedInt:(unsigned int)x;
+ (NSNumber*)numberWithLong:(long)x; + (NSNumber*)numberWithUnsignedLong:(unsigned long)x;
+ (NSNumber*)numberWithLongLong:(long long)x; + (NSNumber*)numberWithUnsignedLongLong:(unsigned long long)x;
+ (NSNumber*)numberWithDouble:(double)x; + (NSNumber*)numberWithBool:(BOOL)x;
@property(readonly) int intValue; @property(readonly) NSInteger integerValue; @property(readonly) double doubleValue;
@property(readonly) BOOL boolValue; @property(readonly) unsigned int unsignedIntValue; @property(readonly) unsigned long long unsignedLongLongValue;
@property(readonly) NSString* stringValue;
@end
@interface NSArray<__covariant ObjectType> : NSObject <NSCopying,NSFastEnumeration>
+ (instancetype)array; + (instancetype)arrayWithObjects:(const id[])objects count:(NSUInteger)n;
@property(readonly) NSUInteger count; @property(readonly) ObjectType firstObject,lastObject;
- (ObjectType)objectAtIndexedSubscript:(NSUInteger)i; - (ObjectType)objectAtIndex:(NSUInteger)i;
- (NSArray*)sortedArrayUsingComparator:(NSInteger(^)(id,id))b;
- (NSArray*)subarrayWithRange:(NSRange)r; - (NSString*)componentsJoinedByString:(NSString*)s; - (BOOL)containsObject:(id)o;
- (NSUInteger)indexOfObject:(id)o;
@end
@interface NSMutableArray<ObjectType> : NSArray<ObjectType>
+ (instancetype)arrayWithCapacity:(NSUInteger)c; - (void)addObject:(ObjectType)o;
- (void)setObject:(ObjectType)o atIndexedSubscript:(NSUInteger)i;
- (void)addObjectsFromArray:(NSArray*)a; - (void)removeObjectAtIndex:(NSUInteger)i; - (void)removeAllObjects;
- (void)removeObjectsInRange:(NSRange)r; - (void)insertObject:(ObjectType)o atIndex:(NSUInteger)i;
- (void)sortUsingComparator:(NSInteger(^)(id,id))b;
@end
@interface NSDictionary<KeyType,ObjectType> : NSObject <NSCopying,NSFastEnumeration>
+ (instancetype)dictionary; + (instancetype)dictionaryWithObjects:(const id[])o forKeys:(const id[])k count:(NSUInteger)n;
- (ObjectType)objectForKeyedSubscript:(KeyType)k; - (ObjectType)objectForKey:(KeyType)k;
@property(readonly) NSArray<KeyType>*allKeys; @property(readonly) NSArray<ObjectType>*allValues; @property(readonly) NSUInteger count;
@end
@interface NSMutableDictionary<KeyType,ObjectType> : NSDictionary<KeyType,ObjectType>
- (void)setObject:(ObjectType)o forKeyedSubscript:(KeyType)k; - (void)setObject:(ObjectType)o forKey:(KeyType)k;
- (void)removeObjectForKey:(KeyType)k; - (void)removeAllObjects; - (void)addEntriesFromDictionary:(NSDictionary*)d;
@end
@interface NSSet<ObjectType> : NSObject <NSFastEnumeration>
+ (instancetype)setWithArray:(NSArray*)a; - (BOOL)containsObject:(ObjectType)o; @property(readonly) NSArray*allObjects;
@end
@interface NSMutableSet<ObjectType> : NSSet<ObjectType>
+ (instancetype)set; - (void)addObject:(ObjectType)o;
@end
@interface NSNull : NSObject + (NSNull*)null; @end
@interface NSDate : NSObject + (instancetype)date; + (instancetype)dateWithTimeIntervalSince1970:(NSTimeInterval)t; @property(readonly) NSTimeInterval timeIntervalSince1970; @end
@interface NSISO8601DateFormatter : NSObject + (instancetype)new; - (NSString*)stringFromDate:(NSDate*)d; @end
@interface NSData : NSObject
@property(readonly) NSUInteger length; @property(readonly) const void*bytes;
+ (instancetype)dataWithContentsOfURL:(NSURL*)u;
- (NSString*)base64EncodedStringWithOptions:(NSUInteger)o; - (BOOL)writeToURL:(NSURL*)u atomically:(BOOL)b;
@end
@interface NSMutableData : NSData
+ (instancetype)data; - (void)appendBytes:(const void*)bytes length:(NSUInteger)length;
@end
@interface NSURL : NSObject
+ (instancetype)fileURLWithPath:(NSString*)s; + (instancetype)URLWithString:(NSString*)s;
@property(readonly) NSString *path,*scheme; @property(readonly) BOOL isFileURL;
- (NSURL*)URLByAppendingPathComponent:(NSString*)s;
@end
@interface NSError : NSObject @property(readonly) NSString*localizedDescription; @end
@interface NSException : NSObject @property(readonly) NSString*reason; @end
@interface NSCharacterSet : NSObject
+ (instancetype)whitespaceAndNewlineCharacterSet; + (instancetype)whitespaceCharacterSet; + (instancetype)newlineCharacterSet;
@end
@interface NSRegularExpression : NSObject
+ (instancetype)regularExpressionWithPattern:(NSString*)p options:(NSUInteger)o error:(NSError**)e;
- (id)firstMatchInString:(NSString*)s options:(NSUInteger)o range:(NSRange)r;
@end
@interface NSTextCheckingResult : NSObject - (NSRange)rangeAtIndex:(NSUInteger)i; @end
@interface NSJSONSerialization : NSObject
+ (NSData*)dataWithJSONObject:(id)o options:(NSUInteger)opts error:(NSError**)e;
+ (id)JSONObjectWithData:(NSData*)d options:(NSUInteger)opts error:(NSError**)e;
@end
@interface NSPropertyListSerialization : NSObject
+ (id)propertyListWithData:(NSData*)d options:(NSUInteger)o format:(NSUInteger*)f error:(NSError**)e;
@end
@interface NSBundle : NSObject
+ (instancetype)mainBundle; @property(readonly) NSString *bundlePath,*resourcePath;
@property(readonly) NSURL *resourceURL; - (id)objectForInfoDictionaryKey:(NSString*)k;
@end
@interface NSUserDefaults : NSObject
+ (instancetype)standardUserDefaults; - (void)registerDefaults:(NSDictionary*)d;
- (id)objectForKey:(NSString*)k; - (void)setObject:(id)o forKey:(NSString*)k; - (NSDictionary*)dictionaryForKey:(NSString*)k;
@end
@interface NSProcessInfo : NSObject
+ (instancetype)processInfo; @property(readonly) NSTimeInterval systemUptime; @property(readonly) NSInteger activeProcessorCount,thermalState;
@property(readonly) NSString *operatingSystemVersionString,*hostName;
@property(readonly) NSDictionary*environment;
@end
@interface NSFileManager : NSObject
+ (instancetype)defaultManager; - (NSDictionary*)attributesOfFileSystemForPath:(NSString*)p error:(NSError**)e;
- (BOOL)fileExistsAtPath:(NSString*)p; - (BOOL)createDirectoryAtPath:(NSString*)p withIntermediateDirectories:(BOOL)b attributes:(NSDictionary*)a error:(NSError**)e;
@end
extern NSString *NSHomeDirectory(void); extern NSString *NSUserName(void);
@interface NSFileHandle : NSObject
+ (instancetype)fileHandleWithNullDevice; - (NSData*)readDataToEndOfFile;
@end
@interface NSPipe : NSObject + (instancetype)pipe; @property(readonly) NSFileHandle*fileHandleForReading; @end
@interface NSTask : NSObject
@property(copy) NSURL*executableURL; @property(copy) NSArray*arguments; @property(copy) NSDictionary*environment;
@property(strong) id standardOutput,standardError; @property(readonly,getter=isRunning) BOOL running;
- (BOOL)launchAndReturnError:(NSError**)e; - (void)waitUntilExit; - (void)terminate;
@end
@interface NSTimer : NSObject
+ (instancetype)scheduledTimerWithTimeInterval:(NSTimeInterval)t target:(id)o selector:(SEL)s userInfo:(id)i repeats:(BOOL)r;
- (void)invalidate; @property NSTimeInterval tolerance;
@end
@interface NSNotification : NSObject @end
@protocol NSApplicationDelegate <NSObject> @end
@protocol NSWindowDelegate <NSObject> @end
@interface NSMenu : NSObject
- (instancetype)initWithTitle:(NSString*)t; - (void)addItem:(id)i;
- (id)addItemWithTitle:(NSString*)t action:(SEL)a keyEquivalent:(NSString*)k;
@end
@interface NSMenuItem : NSObject
- (instancetype)initWithTitle:(NSString*)t action:(SEL)a keyEquivalent:(NSString*)k;
@property(strong) NSMenu*submenu; @property(weak) id target; + (instancetype)separatorItem;
@end
@interface NSApplication : NSObject
+ (instancetype)sharedApplication; @property(weak) id delegate; @property(strong) NSMenu*mainMenu;
- (BOOL)setActivationPolicy:(NSInteger)p; - (void)activateIgnoringOtherApps:(BOOL)b;
- (void)run; - (void)terminate:(id)o; - (void)hide:(id)o;
@end
#define NSApp [NSApplication sharedApplication]
@interface NSView : NSObject
@property NSRect frame,bounds; @property NSUInteger autoresizingMask;
@end
@interface NSWindow : NSObject
- (instancetype)initWithContentRect:(NSRect)r styleMask:(NSUInteger)s backing:(NSUInteger)b defer:(BOOL)d;
@property(copy) NSString*title; @property NSSize minSize; @property BOOL releasedWhenClosed;
@property(strong) NSView*contentView; @property(weak) id delegate; @property(readonly,getter=isVisible) BOOL visible;
- (void)center; - (void)makeKeyAndOrderFront:(id)o; - (void)orderOut:(id)o;
- (BOOL)setFrameAutosaveName:(NSString*)n;
@end
@interface NSViewController : NSObject @property(strong) NSView*view; @end
@interface NSImage : NSObject
+ (instancetype)imageWithSystemSymbolName:(NSString*)n accessibilityDescription:(NSString*)d;
- (instancetype)initWithSize:(NSSize)s; @property NSSize size; @property(getter=isTemplate) BOOL template;
@property(readonly) NSData*TIFFRepresentation; - (void)lockFocus; - (void)unlockFocus;
- (void)drawInRect:(NSRect)r fromRect:(NSRect)f operation:(NSUInteger)o fraction:(CGFloat)x;
@end
@interface NSBitmapImageRep : NSObject
+ (instancetype)imageRepWithData:(NSData*)d; - (NSData*)representationUsingType:(NSUInteger)t properties:(NSDictionary*)p;
@end
@interface NSButton : NSView
@property(copy) NSString*title,*toolTip; @property(strong) NSImage*image; @property NSUInteger imagePosition;
@property SEL action; @property(weak) id target;
@end
@interface NSStatusItem : NSObject @property(readonly) NSButton*button; @property(strong) NSMenu*menu; @end
@interface NSStatusBar : NSObject + (instancetype)systemStatusBar; - (NSStatusItem*)statusItemWithLength:(CGFloat)l; @end
@interface NSPopover : NSObject
@property NSSize contentSize; @property NSUInteger behavior; @property(strong) NSViewController*contentViewController;
@property(readonly,getter=isShown) BOOL shown; - (void)showRelativeToRect:(NSRect)r ofView:(NSView*)v preferredEdge:(NSUInteger)e;
- (void)performClose:(id)o;
@end
@interface NSAlert : NSObject
@property(copy) NSString*messageText,*informativeText; @property NSUInteger alertStyle;
- (NSButton*)addButtonWithTitle:(NSString*)s; - (NSInteger)runModal;
@end
@interface NSSavePanel : NSObject
+ (instancetype)savePanel; @property(copy) NSString*nameFieldStringValue,*message;
@property(copy) NSArray*allowedContentTypes; @property(readonly) NSURL*URL;
- (NSInteger)runModal;
@end
@interface NSRunningApplication : NSObject
@property(readonly) pid_t processIdentifier; @property(readonly) NSURL*bundleURL;
@property(readonly) NSString*localizedName; @property(readonly) NSImage*icon;
@property(readonly,getter=isTerminated) BOOL terminated;
+ (instancetype)runningApplicationWithProcessIdentifier:(pid_t)p; - (BOOL)terminate;
@end
@interface NSWorkspace : NSObject
+ (instancetype)sharedWorkspace; @property(readonly) NSArray<NSRunningApplication*>*runningApplications;
- (BOOL)openURL:(NSURL*)u; - (void)activateFileViewerSelectingURLs:(NSArray*)u;
@end
@protocol WKScriptMessageHandler <NSObject>
- (void)userContentController:(id)c didReceiveScriptMessage:(id)m;
@end
@protocol WKNavigationDelegate <NSObject> @end
@interface WKUserScript : NSObject
- (instancetype)initWithSource:(NSString*)s injectionTime:(NSInteger)t forMainFrameOnly:(BOOL)b;
@end
@interface WKUserContentController : NSObject
- (void)addScriptMessageHandler:(id)h name:(NSString*)n; - (void)addUserScript:(WKUserScript*)s;
@end
@interface WKPreferences : NSObject @property BOOL javaScriptCanOpenWindowsAutomatically; @end
@interface WKWebViewConfiguration : NSObject
@property(strong) WKUserContentController*userContentController; @property(readonly) WKPreferences*preferences;
@end
@interface WKWebView : NSView
- (instancetype)initWithFrame:(NSRect)r configuration:(WKWebViewConfiguration*)c;
@property(weak) id navigationDelegate; @property BOOL allowsBackForwardNavigationGestures;
- (id)loadFileURL:(NSURL*)u allowingReadAccessToURL:(NSURL*)a;
- (void)evaluateJavaScript:(NSString*)s completionHandler:(void(^)(id,NSError*))b;
@end
@interface WKFrameInfo : NSObject @property(readonly,getter=isMainFrame) BOOL mainFrame; @end
@interface WKScriptMessage : NSObject
@property(readonly) id body; @property(readonly) WKFrameInfo*frameInfo; @property(readonly) WKWebView*webView;
@end
@interface NSURLRequest : NSObject @property(readonly) NSURL*URL; @end
@interface WKNavigationAction : NSObject @property(readonly) NSURLRequest*request; @end
#define WKNavigationActionPolicyCancel 0
#define WKNavigationActionPolicyAllow 1
@interface UNMutableNotificationContent : NSObject
@property(copy) NSString*title,*body;
@end
@interface UNNotificationRequest : NSObject
+ (instancetype)requestWithIdentifier:(NSString*)i content:(id)c trigger:(id)t;
@end
@protocol UNUserNotificationCenterDelegate <NSObject> @end
@interface UNUserNotificationCenter : NSObject
+ (instancetype)currentNotificationCenter; @property(weak) id delegate;
- (void)requestAuthorizationWithOptions:(NSUInteger)o completionHandler:(void(^)(BOOL,NSError*))h;
- (void)addNotificationRequest:(UNNotificationRequest*)r withCompletionHandler:(void(^)(NSError*))h;
@end
@interface SMAppService : NSObject
+ (instancetype)mainAppService; @property(readonly) NSInteger status;
- (BOOL)registerAndReturnError:(NSError**)e; - (BOOL)unregisterAndReturnError:(NSError**)e;
@end
@class UTType;
extern UTType *UTTypeJSON;
@protocol MTLDevice <NSObject>
@property(readonly) NSString*name; @property(readonly) BOOL hasUnifiedMemory;
@property(readonly) NSUInteger recommendedMaxWorkingSetSize;
@end
extern id<MTLDevice> MTLCreateSystemDefaultDevice(void);
typedef void (^dispatch_block_t)(void); typedef void* dispatch_queue_t; typedef uint64_t dispatch_time_t;
extern dispatch_queue_t dispatch_queue_create(const char*,void*);
extern struct dispatch_queue_s _dispatch_main_q;
static inline dispatch_queue_t dispatch_get_main_queue(void){ return (dispatch_queue_t)&_dispatch_main_q; }
extern dispatch_queue_t dispatch_get_global_queue(long,unsigned long);
extern void dispatch_async(dispatch_queue_t,dispatch_block_t); extern void dispatch_after(dispatch_time_t,dispatch_queue_t,dispatch_block_t);
extern dispatch_time_t dispatch_time(dispatch_time_t,int64_t);
#define NSEC_PER_SEC 1000000000ULL
extern int sysctlbyname(const char*,void*,size_t*,void*,size_t);
extern pid_t getpid(void); extern uid_t getuid(void); extern int kill(pid_t,int);
extern int puts(const char*);
extern int getloadavg(double*,int); extern unsigned int sleep(unsigned int);
extern void *memset(void*,int,size_t);
extern uint32_t mach_host_self(void);
extern int host_statistics(uint32_t,int,int*,uint32_t*);
extern int host_statistics64(uint32_t,int,int*,uint32_t*);
extern int host_page_size(uint32_t,unsigned long*);
typedef const void*CFTypeRef; typedef const void*CFArrayRef; typedef const void*CFDictionaryRef;
typedef void*CFMutableDictionaryRef; typedef const void*CFAllocatorRef;
extern void CFRelease(CFTypeRef);
extern CFTypeRef IOPSCopyPowerSourcesInfo(void); extern CFArrayRef IOPSCopyPowerSourcesList(CFTypeRef);
extern CFDictionaryRef IOPSGetPowerSourceDescription(CFTypeRef,CFTypeRef);
extern CFMutableDictionaryRef IOServiceMatching(const char*);
extern int IOServiceGetMatchingServices(uint32_t,CFDictionaryRef,uint32_t*);
extern uint32_t IOIteratorNext(uint32_t); extern int IOObjectRelease(uint32_t);
extern int IORegistryEntryCreateCFProperties(uint32_t,CFMutableDictionaryRef*,CFAllocatorRef,uint32_t);
extern int proc_pid_rusage(int,int,void*);
#define MAXCOMLEN 16
#define PROC_PIDTBSDINFO 3
#define PROC_PIDPATHINFO_MAXSIZE 4096
struct proc_bsdinfo {
 uint32_t pbi_flags,pbi_status,pbi_xstatus,pbi_pid,pbi_ppid; uid_t pbi_uid; uint32_t pbi_gid; uid_t pbi_ruid; uint32_t pbi_rgid;
 uid_t pbi_svuid; uint32_t pbi_svgid,rfu_1; char pbi_comm[MAXCOMLEN]; char pbi_name[2*MAXCOMLEN];
 uint32_t pbi_nfiles,pbi_pgid,pbi_pjobc,e_tdev,e_tpgid; int32_t pbi_nice; uint64_t pbi_start_tvsec,pbi_start_tvusec;
};
_Static_assert(sizeof(struct proc_bsdinfo)==136,"Unexpected proc_bsdinfo ABI layout");
extern int proc_pidinfo(int,int,uint64_t,void*,int);
extern int proc_pidpath(int,void*,uint32_t);
#endif
// ABI-neutral own aliases: layouts correspond to the public Mach/libproc API.
typedef struct { uint32_t free,active,inactive,wired; uint64_t zero,react,pageins,pageouts,faults,cow,lookups,hits,purges;
 uint32_t purgeable,speculative; uint64_t decompressions,compressions,swapins,swapouts;
 uint32_t compressed,throttled,external,internal; uint64_t uncompressed; } PulseVMInfo;
typedef struct { unsigned char uuid[16]; uint64_t user,system,wakeups,interruptWakeups,pageins,wired,resident,footprint,start,exit;
 uint64_t childUser,childSystem,childWakeups,childInterruptWakeups,childPageins,childElapsed,readBytes,writeBytes; } PulseRUsage;

_Static_assert(sizeof(PulseVMInfo)==152,"Unexpected Mach VM ABI layout");
_Static_assert(sizeof(PulseRUsage)==160,"Unexpected libproc rusage v2 ABI layout");
