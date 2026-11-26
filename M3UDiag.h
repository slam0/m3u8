#import <Foundation/Foundation.h>

/* Prosty „czarny rekord”: aplikacja zapisuje kilka ostatnich kroków (np. „otwieram plik lista.m3u8”).
 * Gdy poprzednie uruchomienie skończyło się awarią, po starcie pokazujemy te kroki w okienku,
 * dzięki czemu wiadomo, gdzie dokładnie się wysypało. */

void M3UDiagInstall(void);                       /* wyjątki Objective-C trafiają do rekordu */
void M3UBreadcrumb(NSString *step);              /* zapisz krok */
NSString *M3UDiagCrashReportIfAny(void);         /* tekst raportu, gdy poprzednio była awaria; inaczej nil */
void M3UDiagMarkRunning(BOOL running);           /* YES na starcie i po powrocie; NO przy wyjściu z aplikacji */
