//
//  SystemMemoryObserver.h
//  MemoryTest
//
//  Created by wangqianzhou on 8/18/16.
//  Copyright © 2016 Jan Ilavsky. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString* const kMemoryUseUpToKillZone;

@interface SystemMemoryObserver : NSObject

+ (instancetype)instance;

- (void)startObserver;

- (void)stopObserver;

+ (unsigned long ) currentVirtualSize;
@end
