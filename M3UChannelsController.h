#import <UIKit/UIKit.h>

/* Kanały jednej playlisty (albo ulubione): wyszukiwarka, układ listy lub kafelków, odtwarzanie. */
@interface M3UChannelsController : UIViewController
- (id)initWithPlaylist:(NSDictionary *)playlist;   /* @{name, url} lub @{name, file} */
- (id)initWithFavorites;
@end
