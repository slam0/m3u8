#import <UIKit/UIKit.h>

/* Lista kanałów jednej playlisty (albo ulubionych), z wyszukiwarką i odtwarzaniem. */
@interface M3UChannelsController : UITableViewController
- (id)initWithPlaylist:(NSDictionary *)playlist;   /* @{name, url} lub @{name, file} */
- (id)initWithFavorites;
@end
