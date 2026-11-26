#import <Foundation/Foundation.h>

/* Program TV (EPG). Aplikacja nie czyta wielkich plików XMLTV: pobiera mały epg.json, który co kilka godzin
 * buduje GitHub Actions (tools/build_epg.py). Kanały z playlisty dopasowujemy do programu po nazwie
 * (bez wielkości liter, bez "HD", spacji i znaków specjalnych; "+2" zostaje). */

extern NSString *const M3UEpgDidUpdate;       /* powiadomienie po wczytaniu nowego programu */
extern NSString *const M3UEpgDefaultURL;

BOOL M3UEpgEnabled(void);
void M3UEpgSetEnabled(BOOL on);
NSString *M3UEpgURL(void);                    /* adres z ustawień albo domyślny */
void M3UEpgSetURL(NSString *url);             /* puste = domyślny */

/* Wczytuje zapisany plik i, gdy jest starszy niż 6 godzin (albo force), pobiera nowy. Nic nie robi, gdy wyłączone. */
void M3UEpgRefresh(BOOL force);
NSString *M3UEpgStatus(void);                 /* krótki opis stanu do ustawień */
NSUInteger M3UEpgChannelCount(void);

/* Program kanału o danej nazwie albo nil. Klucze: now (NSString, może brakować), start, end (NSNumber, sekundy),
 * next (NSString, może brakować), nextStart, nextEnd. */
NSDictionary *M3UEpgFor(NSString *channelName);
/* Program kanału na najbliższe godziny: tablica @[start, koniec, tytuł] od audycji, która jeszcze trwa. Pusta, gdy brak. */
NSArray *M3UEpgList(NSString *channelName);
NSString *M3UEpgClock(NSTimeInterval t);      /* "20:45" w czasie lokalnym */
