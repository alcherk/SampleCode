/*
 <codex>
 <import>AppDelegate.h</import>
 </codex>
 */

#import "AppDelegate.h"
#import <CoreLocation/CoreLocation.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    if (![CLLocationManager locationServicesEnabled]) {
        // location services is disabled, alert user
        UIAlertView *servicesDisabledAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"DisabledTitle", @"DisabledTitle")
                                                                        message:NSLocalizedString(@"DisabledMessage", @"DisabledMessage")
                                                                       delegate:nil
                                                              cancelButtonTitle:NSLocalizedString(@"OKButtonTitle", @"OKButtonTitle")
                                                              otherButtonTitles:nil];
        [servicesDisabledAlert show];
    }
    return YES;
}

@end
