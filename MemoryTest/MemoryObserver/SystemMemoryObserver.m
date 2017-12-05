//
//  SystemMemoryObserver.m
//  MemoryTest
//
//  Created by wangqianzhou on 8/18/16.
//  Copyright © 2016 Jan Ilavsky. All rights reserved.
//

#import "SystemMemoryObserver.h"
#import "MemoryLimitMap.h"
#import <mach/mach.h>
#include <sys/sysctl.h>

NSString* const kMemoryUseUpToKillZone = @"kMemoryUseUpToKillZone";

@interface SystemMemoryObserver ()
@property(nonatomic, strong)NSThread* memoryObserverThread;
@property(atomic, assign)BOOL isObservering;
@property(nonatomic, assign)unsigned long memoryLimit;
@end

@implementation SystemMemoryObserver

+ (instancetype)instance
{
    static SystemMemoryObserver* _inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _inst = [[[self class] alloc] init];
    });
    
    return _inst;
}

- (instancetype)init
{
    if (self = [super init])
    {
        unsigned long limitOnKilled = getLimitMemoryOnKilled([[self class] getDeviceModelIdentifier]);
        _memoryLimit = limitOnKilled * 0.95; //限制分配最多95%可用内存
    }
    
    return self;
}

+ (NSString*)getDeviceModelIdentifier
{
    size_t size;
    
    sysctlbyname("hw.machine",NULL, &size, NULL,0);
    
    char *machine = (char*)malloc(size);
    
    sysctlbyname("hw.machine", machine, &size,NULL, 0);
    
    NSString *platform = [NSString stringWithUTF8String:machine];
    
    free(machine);
    
    return platform;
}

- (void)startObserver
{
    if (self.memoryObserverThread == nil
        && !self.isObservering
        && self.memoryLimit)
    {
        self.isObservering = YES;
        self.memoryObserverThread = [[NSThread alloc] initWithTarget:self selector:@selector(doNothing) object:nil];
        [self.memoryObserverThread start];
    }
}


- (void)stopObserver
{
    self.isObservering = NO;
    self.memoryObserverThread = nil;
}

- (void)doNothing
{
    // The application uses garbage collection, so no autorelease pool is needed.
    NSRunLoop* myRunLoop = [NSRunLoop currentRunLoop];
    
    // Create a run loop observer and attach it to the run loop.
    CFRunLoopObserverContext  context = {0, (__bridge void *)(self), NULL, NULL, NULL};
    CFRunLoopObserverRef    observer = CFRunLoopObserverCreate(kCFAllocatorDefault,
                                                               kCFRunLoopAllActivities, YES, 0, NULL, &context);
    
    if (observer)
    {
        CFRunLoopRef    cfLoop = [myRunLoop getCFRunLoop];
        CFRunLoopAddObserver(cfLoop, observer, kCFRunLoopDefaultMode);
    }
    
    // Create and schedule the timer.
    [NSTimer scheduledTimerWithTimeInterval:1 target:self
                                   selector:@selector(doFireTimer:) userInfo:nil repeats:YES];
    
    do
    {
        // Run the run loop 10 times to let the timer fire.
        [myRunLoop runUntilDate:[NSDate distantFuture]];
    }
    while (self.isObservering);
}

- (void)doFireTimer:(NSTimer*)timer
{
    unsigned long currentUse = [[self class] currentVirtualSize];
    if (currentUse >= self.memoryLimit)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:kMemoryUseUpToKillZone object:nil];
        });
    }
}

+ (unsigned long ) currentVirtualSize
{
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    
    kern_return_t kerr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
    
    unsigned long currentMemVirtualSize = 0;
    if( kerr == KERN_SUCCESS ){
        currentMemVirtualSize = info.virtual_size;

    }
    
    return currentMemVirtualSize / 1024 / 1024;
}
@end
