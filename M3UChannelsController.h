#import <UIKit/UIKit.h>

/* Kanały jednej playlisty (albo ulubione): wyszukiwarka, układ listy lub kafelków, odtwarzanie. */
@interface M3UChannelsController : UIViewController
- (id)initWithPlaylist:(NSDictionary *)playlist;   /* @{name, url} lub @{name, file} */
@property (nonatomic, copy) NSString *resumeURL;   /* kanał do automatycznego odtworzenia po wczytaniu listy (wznawianie) */
- (id)initWithFavorites;
- (id)initWithEntries:(NSArray *)entries group:(NSString *)group title:(NSString *)title;   /* group nil = wszystkie */

/* Dla paska bocznego (iPad) */
- (BOOL)isFavoritesScreen;
- (BOOL)isPlaylistRoot;                       /* ekran kanałów playlisty (nie ulubione, nie kategoria) */
- (NSArray *)categoryItems;                   /* @[@{name,count}] albo nil, gdy playlista nie ma kategorii */
- (void)openCategoryAtIndex:(NSInteger)r;
- (void)focusSearch;
- (void)toggleLayout;
- (void)refreshTapped;
@end
