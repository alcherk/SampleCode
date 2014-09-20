/*
 <codex>
 <abstract>UITableViewController that displays the propeties of a CLPlacemark.
 </abstract>
 </codex>
 */

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>

@interface PlacemarkViewController : UITableViewController <MKAnnotation>

// designated initilizers
//
// show the map and coordinate above the address info.
- (instancetype)initWithPlacemark:(CLPlacemark *)placemark preferCoord:(BOOL)shouldPreferCoord NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithPlacemark:(CLPlacemark *)placemark;


#pragma mark - MKAnnotation Protocol (for map pin)

@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *title;

@end
