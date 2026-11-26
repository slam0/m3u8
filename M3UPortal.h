#import <UIKit/UIKit.h>

/* Mediateka (filmy i seriale) z serwisu, który podaje link w postaci
 *   portal::[key:KLUCZ]http://adres/api/v1/
 * To nie jest playlista M3U, tylko proste API JSON: aplikacja wysyła POST z kluczem i poleceniem
 * (np. lista kategorii, lista filmów, szukanie) i dostaje listę pozycji albo adresy strumieni HLS. */

BOOL M3UIsPortalLink(NSString *s);

@interface M3UPortal : NSObject
@property (nonatomic, copy, readonly) NSString *key;
@property (nonatomic, copy, readonly) NSString *apiURL;
/* nil, gdy tekst nie jest poprawnym linkiem portal::[key:...]http://... */
+ (M3UPortal *)portalFromLink:(NSString *)link;
/* Wysyła polecenie (klucz dodajemy sami). done na głównym wątku: słownik JSON albo komunikat błędu. */
- (void)request:(NSDictionary *)params done:(void (^)(NSDictionary *json, NSString *error))done;
/* Okładka z pamięci albo nil. */
- (UIImage *)cachedImage:(NSString *)url;
/* Pobiera okładkę w tle (4 naraz); done na głównym wątku, może dostać nil. */
- (void)loadImage:(NSString *)url done:(void (^)(UIImage *img))done;
@end
