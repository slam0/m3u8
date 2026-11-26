#import <UIKit/UIKit.h>

/* Ikonki kanałów: kafelek 46x46 pt (ramka + szkło + logo). Logo pobieramy w tle (3 połączenia naraz),
 * zapamiętujemy na dysku (Caches/logos) i w pamięci. Po każdym pobraniu idzie powiadomienie M3ULogoDidLoad. */

extern NSString *const M3ULogoDidLoad;

UIImage *M3UPlaceholderTile(void);                       /* kafelek bez logo */
UIImage *M3UCachedLogoTile(NSString *url);               /* gotowy kafelek z pamięci albo nil */
BOOL M3ULogoFailed(NSString *url);                       /* YES, jeśli tego logo nie da się pobrać */
/* Prosi o pobranie. stillNeeded woła się tuż przed pobraniem - gdy zwróci NO (wiersz już przewinięty), pomijamy. */
void M3URequestLogo(NSString *url, BOOL (^stillNeeded)(void));
