//
//  MemoryLimitMap.m
//  MemoryTest
//
//  Created by wangqianzhou on 8/18/16.
//  Copyright © 2016 Jan Ilavsky. All rights reserved.
//

#import "MemoryLimitMap.h"

unsigned long getLimitMemoryOnKilled (NSString* modelIdentifier)
{
    if ([modelIdentifier length] == 0)
    {
        return 0;
    }
    
    
    NSDictionary* const modelLimitMemory = @{
                                             @"iPhone1,2" : @(0), //iPhone 3G
                                             @"iPhone2,1" : @(0), //iPhone 3GS
                                             @"iPhone3,1" : @(0), //iPhone 4
                                             @"iPhone3,2" : @(0), //iPhone 4 (8G)
                                             @"iPhone3,3" : @(0), //Verizon iPhone 4
                                             @"iPhone4,1" : @(0), //iPhone 4S
                                             @"iPhone5,1" : @(0), //iPhone 5 (GSM)
                                             @"iPhone5,2" : @(1271), //iPhone 5 (3G+4G+GSM+CDMA)
                                             @"iPhone5,3" : @(0), //iPhone 5c (CDMA)
                                             @"iPhone5,4" : @(0), //iPhone 5c (GSM)
                                             @"iPhone6,1" : @(0), //iPhone 5s (CDMA)
                                             @"iPhone6,2" : @(0), //iPhone 5s (GSM)
                                             @"iPhone7,1" : @(0), //iPhone 6 Plus
                                             @"iPhone7,2" : @(0), //iPhone 6
                                             @"iPhone8,1" : @(0), //iPhone 6s
                                             @"iPhone8,2" : @(0), //iPhone 6s Plus
                                             @"iPhone8,4" : @(2158), //iPhone SE
                                             @"iPod1,1" : @(0), //iPod Touch 1G
                                             @"iPod2,1" : @(0), //iPod Touch 2G
                                             @"iPod3,1" : @(0), //iPod Touch 3G
                                             @"iPod4,1" : @(0), //iPod Touch 4G
                                             @"iPod5,1" : @(850), //iPod Touch 5G
                                             @"iPad1,1" : @(0), //iPad
                                             @"iPad1,2" : @(0), //iPad 3G
                                             @"iPad2,1" : @(0), //iPad 2 (WiFi)
                                             @"iPad2,2" : @(0), //iPad 2 (WiFi+3G+GSM)
                                             @"iPad2,3" : @(0), //iPad 2 (WiFi+3G+GSM+CDMA)
                                             @"iPad2,4" : @(0), //iPad 2 (WiFi)
                                             @"iPad2,5" : @(0), //iPad Mini (WiFi)
                                             @"iPad2,6" : @(0), //iPad Mini (WiFi+3G+4G+GSM)
                                             @"iPad2,7" : @(0), //iPad Mini (WiFi+3G+4G+GSM+CDMA)
                                             @"iPad3,1" : @(0), //iPad 3 (WiFi)
                                             @"iPad3,2" : @(0), //iPad 3 (WiFi+3G+GSM+CDMA)
                                             @"iPad3,3" : @(0), //iPad 3 (WiFi+3G+GSM)
                                             @"iPad3,4" : @(0), //iPad 4 (WiFi)
                                             @"iPad3,5" : @(0), //iPad 4 (WiFi+3G+4G+GSM)
                                             @"iPad3,6" : @(0), //iPad 4 (WiFi+3G+4G+GSM+CDMA)
                                             @"iPad4,1" : @(0), //iPad Air (WiFi)
                                             @"iPad4,2" : @(0), //iPad Air (Cellular)
                                             @"iPad4,4" : @(0), //iPad Mini 2 (WiFi)
                                             @"iPad4,5" : @(0), //iPad Mini 2 (Cellular)
                                             @"iPad4,6" : @(0), //iPad Mini 2
                                             @"iPad4,7" : @(0), //iPad Mini 3
                                             @"iPad4,8" : @(0), //iPad Mini 3
                                             @"iPad4,9" : @(0), //iPad Mini 3
                                             @"iPad5,1" : @(0), //iPad Mini 4 (WiFi)
                                             @"iPad5,2" : @(0), //iPad Mini 4 (LTE)
                                             @"iPad5,3" : @(0), //iPad Air 2
                                             @"iPad5,4" : @(0), //iPad Air 2
                                             @"iPad6,8" : @(0), //iPad Pro
                                             };
    
    return [modelLimitMemory[modelIdentifier] unsignedLongValue];
}

