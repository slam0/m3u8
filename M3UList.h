#import <Foundation/Foundation.h>

/* Jeden kanał z listy. */
@interface M3UEntry : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *group;   /* pusty, jeśli lista nie ma grup */
@property (nonatomic, copy) NSString *logo;
@property (nonatomic, copy) NSString *url;
@end

/* Zamienia pobrane bajty na tekst: UTF-8, a gdy się nie da, Windows-1250, a potem Latin-1. */
NSString *M3UDecode(NSData *data);

/* Parsuje listę. Jeśli to pojedynczy strumień HLS (#EXT-X-...), zwraca *isHLS = YES i pustą tablicę. */
NSArray *M3UParse(NSString *text, BOOL *isHLS);

/* Pobiera listę z adresu http(s) w tle; done wołane na głównym wątku (data albo komunikat błędu). */
void M3UFetch(NSString *url, void (^done)(NSData *data, NSString *error));
