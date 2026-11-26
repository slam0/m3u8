#import <UIKit/UIKit.h>

/* Kafelki z ikonkami kanałów. Gdy logo jest dostępne, kafelek pokazuje je na szklanej płytce; gdy nie ma
 * logo (albo się nie pobrało), kafelek ma kolorową płytkę z inicjałami kanału.
 * Logo pobieramy w tle (3 połączenia naraz), zapamiętujemy na dysku (Caches/logos) i w pamięci.
 * Po każdym pobraniu idzie powiadomienie M3ULogoDidLoad. */

extern NSString *const M3ULogoDidLoad;

UIImage *M3UMonogramTile(NSString *name, CGFloat side);          /* płytka z inicjałami */
UIImage *M3UCachedLogoTile(NSString *url, CGFloat side);         /* kafelek z logo z pamięci albo nil; side <= 0 = logo w swoich proporcjach (duże kafelki) */
BOOL M3ULogoFailed(NSString *url);                               /* YES, jeśli logo się nie pobrało */
NSString *M3ULogoStatus(NSString *url);                          /* opis stanu dla ekranu „Szczegóły” */
/* Prosi o pobranie. stillNeeded woła się tuż przed pobraniem - gdy zwróci NO (wiersz przewinięty), pomijamy. */
unsigned long long M3ULogoCacheBytes(void);                       /* rozmiar logo zapisanych na dysku */
void M3UClearLogoCache(void);                                    /* kasuje logo z dysku (pobiorą się ponownie) */
void M3URequestLogo(NSString *url, CGFloat side, BOOL (^stillNeeded)(void));
