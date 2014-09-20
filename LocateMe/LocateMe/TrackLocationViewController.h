/*
 <codex>
 <abstract>Attempts to track the user location with a specific level of accuracy. A "distance filter" indicates the smallest change in location that triggers an update from the location manager to its delegate. Presents a SetupViewController instance so the user can configure the desired accuracy and distance filter. Uses a LocationDetailViewController instance to drill down into details for a given location measurement.
 </abstract>
 </codex>
 */

#import <UIKit/UIKit.h>

@interface TrackLocationViewController : UIViewController

@end
