//
//  ViewController.m
//  MemoryTest
//
//  Created by Jan Ilavsky on 11/5/12.
//  Copyright (c) 2012 Jan Ilavsky. All rights reserved.
//

#import "ViewController.h"
#import <sys/types.h>
#import <sys/sysctl.h>
#import "SystemMemoryObserver.h"
#include <mach/vm_statistics.h>
#include <mach/mach_types.h>
#include <mach/mach_init.h>
#include <mach/mach_host.h>
#import <mach/mach.h>
#include <sys/sysctl.h>

#define CRASH_MEMORY_FILE_NAME @"CrashMemory.dat"
#define MEMORY_WARNINGS_FILE_NAME @"MemoryWarnings.dat"

static const int kBytesPerMB = (1 << 20);
static BOOL shouldAllocateMore = YES;

double currentTime() { return [[NSDate date] timeIntervalSince1970]; }

int systemMemoryLevel()
{
#if IOS_SIMULATOR
    return 35;
#else
    static int memoryFreeLevel = -1;
    static double previousCheckTime;
    double time = currentTime();
    if (time - previousCheckTime < 0.1)
        return memoryFreeLevel;
    previousCheckTime = time;
    size_t size = sizeof(memoryFreeLevel);
    sysctlbyname("kern.memorystatus_level", &memoryFreeLevel, &size, nullptr, 0);
    return memoryFreeLevel;
#endif
    
//    
//    return 10;
}


@interface ViewController () {
    
    NSTimer *timer;

    int allocatedMB;
    Byte *p[10000];
    uint64_t physicalMemorySize;
    uint64_t userMemorySize;
    uint64_t memory_footprint;
    
    NSMutableArray *infoLabels;
    NSMutableArray *memoryWarnings;
    
    BOOL initialLayoutFinished;
    BOOL firstMemoryWarningReceived;
}

@property (weak, nonatomic) IBOutlet UIView *progressBarBG;
@property (weak, nonatomic) IBOutlet UIView *alocatedMemoryBar;
@property (weak, nonatomic) IBOutlet UIView *kernelMemoryBar;
@property (weak, nonatomic) IBOutlet UILabel *userMemoryLabel;
@property (weak, nonatomic) IBOutlet UILabel *totalMemoryLabel;
@property (weak, nonatomic) IBOutlet UIButton *startButton;
@property (nonatomic, strong)  dispatch_source_t memoryStatusEventSource;
@end

@implementation ViewController

#pragma mark - Helpers

- (void)refreshUI {
    uint64_t physicalMemorySizeMB = physicalMemorySize / kBytesPerMB;
    uint64_t userMemorySizeMB = userMemorySize / kBytesPerMB;
    
    self.userMemoryLabel.text = [NSString stringWithFormat:@"%lld MB -", userMemorySizeMB];
    self.totalMemoryLabel.text = [NSString stringWithFormat:@"%lld MB -", physicalMemorySizeMB];
    
    CGRect rect;
    
    CGFloat userMemoryProgressLength = self.progressBarBG.bounds.size.height *  (userMemorySizeMB / (float)physicalMemorySizeMB);
    
    rect = self.userMemoryLabel.frame;
    rect.origin.y = roundf((self.progressBarBG.bounds.size.height - userMemoryProgressLength) - self.userMemoryLabel.bounds.size.height * 0.5f + self.progressBarBG.frame.origin.y - 3);
    self.userMemoryLabel.frame = rect;
    
    rect = self.kernelMemoryBar.frame;
    rect.size.height = roundf(self.progressBarBG.bounds.size.height - userMemoryProgressLength);
    self.kernelMemoryBar.frame = rect;
    
    rect = self.alocatedMemoryBar.frame;
    rect.size.height = roundf(self.progressBarBG.bounds.size.height * (allocatedMB / (float)physicalMemorySizeMB));
    rect.origin.y = self.progressBarBG.bounds.size.height - rect.size.height;
    self.alocatedMemoryBar.frame = rect;
}


- (int64_t)memoryFootprint
{
    task_vm_info_data_t vmInfo;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    kern_return_t result = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t) &vmInfo, &count);
    if (result != KERN_SUCCESS)
        return 0;
    
    return (count == TASK_VM_INFO_COUNT) ? static_cast<uint64_t>(vmInfo.phys_footprint) : 0;
}

- (int64_t)memoryFootprintEarlyIOS //earlier than iOS 9.0
{
    task_vm_info_data_t vmInfo;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    kern_return_t result = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t) &vmInfo, &count);
    if (result != KERN_SUCCESS)
        return 0;
    
    return static_cast<uint64_t>(vmInfo.internal + vmInfo.compressed);
}

- (void)refreshMemoryInfo {
    
    // Get memory info
    int mib[2];
    size_t length;
    mib[0] = CTL_HW;
    
//    mib[1] = HW_MEMSIZE;
//    length = sizeof(int64_t);
//    sysctl(mib, 2, &physicalMemorySize, &length, NULL, 0);
    physicalMemorySize = [[NSProcessInfo processInfo] physicalMemory];
    
    mib[1] = HW_USERMEM;
    length = sizeof(int64_t);
    sysctl(mib, 2, &userMemorySize, &length, NULL, 0);
    
    
    vm_size_t page_size;
    mach_port_t mach_port;
    mach_msg_type_number_t count;
    vm_statistics64_data_t vm_stats;
    
    long long free_memory_64 = 0;
    long long used_memory = 0;
    
    mach_port = mach_host_self();
    count = sizeof(vm_stats) / sizeof(natural_t);
    if (KERN_SUCCESS == host_page_size(mach_port, &page_size) &&
        KERN_SUCCESS == host_statistics64(mach_port, HOST_VM_INFO,
                                          (host_info64_t)&vm_stats, &count))
    {
        free_memory_64 = (int64_t)vm_stats.free_count * (int64_t)page_size;
        
        used_memory = ((int64_t)vm_stats.active_count +
                                 (int64_t)vm_stats.inactive_count +
                                 (int64_t)vm_stats.wire_count) *  (int64_t)page_size;
    }
    
    
//    struct task_basic_info info;
//    mach_msg_type_number_t size = sizeof(info);
//    
//    task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
    
    struct mach_task_basic_info info2;
    mach_msg_type_number_t size2 = sizeof(info2);
    task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info2, &size2);
    
    NSLog(@"memLevel: %3d, alloc: %4lldM; "
          @"MemTotal:%lld, UserModeMem:%lld, "
          @"VMUsed:%lld, "
          @"Resident2:%lld, "
          @"ResidentMax:%lld, "
          @"FootPrint:%lld, "
          @"FootPrint2:%lld, "
          @"MemUsed:%lld, "
          @"MemFree64:%lld, "
          @"active:%lld, inactive:%lld, wire:%lld,"
          @"level:%lld, ",
          systemMemoryLevel(), (uint64_t)allocatedMB,
          (uint64_t)physicalMemorySize >> 20,
          (uint64_t)userMemorySize >> 20,
          (uint64_t)[SystemMemoryObserver currentVirtualSize],
          (uint64_t)info2.resident_size >> 20,
          (uint64_t)info2.resident_size_max >> 20,
          (uint64_t)[self memoryFootprint] >> 20,
          (uint64_t)[self memoryFootprintEarlyIOS] >> 20,
          (uint64_t)used_memory >> 20,
          (uint64_t)free_memory_64 >> 20,
          ((int64_t)vm_stats.active_count * (int64_t)page_size) >> 20,
          ((int64_t)vm_stats.inactive_count * (int64_t)page_size) >> 20,
          ((int64_t)vm_stats.wire_count * (int64_t)page_size) >> 20,
          (info2.resident_size + info2.virtual_size) * 100 / physicalMemorySize);
    
//    if(info.resident_size/1024/1024 + 30 < allocatedMB)
//    {
//        for(int i = allocatedMB - 1; i >= 0; --i)
//        {
//            memset(p[i], 0xff, 1048576);
//        }
//    }
}

- (void)allocateMemory {
    
//    if(!shouldAllocateMore)
//    {
//        return;
//    }
    
    p[allocatedMB] = (Byte*)malloc(kBytesPerMB);
    memset(p[allocatedMB], allocatedMB % 0xff, kBytesPerMB);
    allocatedMB += 1;
    
    [self refreshMemoryInfo];
    [self refreshUI];

    
    if (firstMemoryWarningReceived) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
        [NSKeyedArchiver archiveRootObject:@(allocatedMB) toFile:[basePath stringByAppendingPathComponent:CRASH_MEMORY_FILE_NAME]];
    }
}

- (void)clearAll {
    
    for (int i = 0; i < allocatedMB; i++) {
        free(p[i]);
    }
    
    allocatedMB = 0;
    
    [infoLabels makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [infoLabels removeAllObjects];
    
    [memoryWarnings removeAllObjects];
}

- (void)addLabelAtMemoryProgress:(NSInteger)memory text:(NSString*)text color:(UIColor*)color {

    CGFloat length = self.progressBarBG.bounds.size.height * (1.0f - memory / (float)(physicalMemorySize / kBytesPerMB));
    
    CGRect rect;
    rect.origin.x = 20;
    rect.size.width = self.progressBarBG.frame.origin.x - rect.origin.x - 8;
    rect.size.height = 20;
    rect.origin.y = roundf(self.progressBarBG.frame.origin.y + length - rect.size.height * 0.5f);

    UILabel *label = [[UILabel alloc] initWithFrame:rect];
    label.textAlignment = NSTextAlignmentRight;
    label.text = [NSString stringWithFormat:@"%@ %zd MB -", text, memory];
    label.font = self.totalMemoryLabel.font;
    label.textColor = color;
    
    [infoLabels addObject:label];
    [self.view addSubview:label];
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    infoLabels = [[NSMutableArray alloc] init];
    memoryWarnings = [[NSMutableArray alloc] init];
    
    [self registerMemoryPressureListener];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onRecvMemLimitNotification) name:kMemoryUseUpToKillZone object:nil];
    
    size_t size;
    sysctlbyname("kern.boottime", NULL, &size, NULL, 0);
    
    char *boot_time = (char *)malloc(size);
    sysctlbyname("kern.boottime", boot_time, &size, NULL, 0);
    
    uint32_t timestamp = 0;
    memcpy(&timestamp, boot_time, sizeof(uint32_t));
    free(boot_time);
    
    NSDate* bootTime = [NSDate dateWithTimeIntervalSince1970:timestamp];
    NSLog(@"Device boot @%@", bootTime);
    
//    sysctlbyname("kern.jetsam_critical_threshold", NULL, &size, NULL, 0);
//    char *cr_threshold = (char *)malloc(size);
//    sysctlbyname("kern.jetsam_critical_threshold", cr_threshold, &size, NULL, 0);
//    uint32_t crThreashold = 0;
//    memcpy(&crThreashold, cr_threshold, sizeof(uint32_t));
//    free(cr_threshold);
}

- (void)viewDidLayoutSubviews {
    
    if (!initialLayoutFinished) {
    
        [self refreshMemoryInfo];
        [self refreshUI];
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
        NSInteger crashMemory = [[NSKeyedUnarchiver unarchiveObjectWithFile:[basePath stringByAppendingPathComponent:CRASH_MEMORY_FILE_NAME]] integerValue];
        if (crashMemory > 0) {
            [self addLabelAtMemoryProgress:crashMemory text:@"Crash" color:[UIColor colorWithRed:0.8 green:0.0 blue:0.0 alpha:1.0]];
        }
        
        NSArray *lastMemoryWarnings = [NSKeyedUnarchiver unarchiveObjectWithFile:[basePath stringByAppendingPathComponent:MEMORY_WARNINGS_FILE_NAME]];
        if (lastMemoryWarnings) {
            
            for (NSNumber *number in lastMemoryWarnings) {
                
                [self addLabelAtMemoryProgress:[number intValue] text:@"Memory Warning" color:[UIColor colorWithWhite:0.6 alpha:1.0]];
            }
        }
        
        initialLayoutFinished = YES;
    }
}

- (void)viewDidUnload {
    
    [timer invalidate];
    [self clearAll];    
    
    infoLabels = nil;
    memoryWarnings = nil;
    
    initialLayoutFinished = NO;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super viewDidUnload];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
 
    NSLog(@"=========== didReceiveMemoryWarning ========");
    
    firstMemoryWarningReceived = YES;
    
    [self addLabelAtMemoryProgress:allocatedMB text:@"Memory Warning" color:[UIColor colorWithWhite:0.6 alpha:1.0]];
    
    [memoryWarnings addObject:@(allocatedMB)];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    [NSKeyedArchiver archiveRootObject:memoryWarnings toFile:[basePath stringByAppendingPathComponent:MEMORY_WARNINGS_FILE_NAME]];
}

- (void)registerMemoryPressureListener
{
    self.memoryStatusEventSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_MEMORYPRESSURE,
                                                      0,
                                                      DISPATCH_MEMORYPRESSURE_NORMAL|DISPATCH_MEMORYPRESSURE_WARN|DISPATCH_MEMORYPRESSURE_CRITICAL,
                                                      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    
    dispatch_source_set_event_handler(self.memoryStatusEventSource, ^{
        unsigned long currentStatus = dispatch_source_get_data(self.memoryStatusEventSource);
        [self onMemoryWarningWithStatus:currentStatus];
    });
    
    dispatch_resume(self.memoryStatusEventSource);
}

- (void)onMemoryWarningWithStatus:(unsigned long)status
{
    NSLog(@"******************** Recv Memory Status : %@", @(status));
    shouldAllocateMore = NO;
    
}

#pragma mark - Actions

- (IBAction)startButtonPressed:(id)sender {
    
    [self clearAll];
    
    firstMemoryWarningReceived = NO;
    
    [timer invalidate];
    timer = [NSTimer scheduledTimerWithTimeInterval:0.02 target:self selector:@selector(allocateMemory) userInfo:nil repeats:YES];
}

- (void)onRecvMemLimitNotification
{
    NSLog(@"onRecvMemLimitNotification .........");
}
@end

