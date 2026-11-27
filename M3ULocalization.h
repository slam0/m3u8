#import <Foundation/Foundation.h>

/* Języki aplikacji: polski (domyślny), angielski, rosyjski. Kluczem jest polski napis z kodu;
 * L(@"...") zwraca tłumaczenie na wybrany język, a gdy go brak - polski oryginał. */

extern NSString *const M3ULanguageDidChange;

NSString *M3ULocalize(NSString *polish);
NSString *M3UCurrentLanguage(void);            /* @"pl", @"en" albo @"ru" */
void M3USetLanguage(NSString *code);
void M3USetLanguageQuiet(NSString *code);      /* zapis bez powiadomienia (ekran konfiguracji sam odświeża napisy) */

#define L(s) M3ULocalize(s)
