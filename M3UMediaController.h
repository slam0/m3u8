#import <UIKit/UIKit.h>

/* Mediateka: kategorie, plakaty filmów, odcinki seriali. Jeden kontroler obsługuje każdy poziom:
 * listę kategorii, siatkę plakatów (gdy pozycje mają okładki), wyniki szukania i ekran filmu z odcinkami. */
@interface M3UMediaController : UIViewController
/* Główny ekran mediateki z pozycji playlisty (słownik z kluczem @"url" = link portal::[key:...]http://...). */
- (id)initWithPlaylist:(NSDictionary *)playlist;
@end
