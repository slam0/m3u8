#import <UIKit/UIKit.h>

@class M3UAddController;
@protocol M3UAddDelegate <NSObject>
- (void)addController:(M3UAddController *)c didAddName:(NSString *)name url:(NSString *)url;
- (void)addControllerDidCancel:(M3UAddController *)c;
@end

/* Formularz: nazwa + adres playlisty, z przyciskiem „Wklej ze schowka”. */
@interface M3UAddController : UITableViewController
@property (nonatomic, weak) id<M3UAddDelegate> delegate;
@end
