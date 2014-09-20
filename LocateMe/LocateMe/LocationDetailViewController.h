/*
 <codex>
 <abstract>Lists the values for all the properties of a single CLLocation object. 
 </abstract>
 </codex>
 */

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

@interface LocationDetailViewController : UITableViewController

@property (nonatomic, strong) CLLocation *location;

@end
