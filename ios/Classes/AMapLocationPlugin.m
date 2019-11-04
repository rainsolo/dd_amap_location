#import "AMapLocationPlugin.h"

#import <amap_location/amap_location-Swift.h>

/*
static NSDictionary* DesiredAccuracy = @{@"kCLLocationAccuracyBest":@(kCLLocationAccuracyBest),
                                         @"kCLLocationAccuracyNearestTenMeters":@(kCLLocationAccuracyNearestTenMeters),
                                         @"kCLLocationAccuracyHundredMeters":@(kCLLocationAccuracyHundredMeters),
                                         @"kCLLocationAccuracyKilometer":@(kCLLocationAccuracyKilometer),
                                         @"kCLLocationAccuracyThreeKilometers":@(kCLLocationAccuracyThreeKilometers),
                                         
                                         };*/

@implementation AMapLocationPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    [SwiftAMapLocationPlugin registerWithRegistrar:registrar];
}

@end
