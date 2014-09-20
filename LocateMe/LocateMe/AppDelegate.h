/*
 <codex>
 <abstract>The application delegate has a minimal role in this sample: in -applicationDidFinishLaunching: it adds the tab bar controller's view to the window. It also creates a CLLocationManager object to check the locationServicesEnabled property at launch time.
 </abstract>
 </codex>
 */
 
#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@end
