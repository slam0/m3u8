#import <Foundation/Foundation.h>

/* Playlisty: słowniki @{@"name", @"url"} (z adresu) albo @{@"name", @"file"} (plik w Documents). */
NSArray *M3UPlaylists(void);
void M3USavePlaylists(NSArray *list);

/* Ulubione kanały: słowniki @{@"name", @"url", @"group", @"logo"}. */
NSArray *M3UFavorites(void);
BOOL M3UIsFavorite(NSString *url);
void M3UToggleFavorite(NSString *name, NSString *url, NSString *group, NSString *logo);

/* Ostatnio pobrany tekst listy (żeby lista kanałów otwierała się bez internetu). */
NSString *M3UCachedText(NSString *key);
void M3USaveCachedText(NSString *key, NSString *text);

/* Pliki .m3u/.m3u8 wrzucone do aplikacji przez iTunes lub „Otwórz w…”. */
NSString *M3UDocumentsPath(void);
NSArray *M3ULocalFiles(void);
