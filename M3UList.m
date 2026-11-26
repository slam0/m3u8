#import "M3UList.h"
#import "M3ULocalization.h"
#include "m3u.h"

@implementation M3UEntry
@end

NSString *M3UDecode(NSData *data)
{
    NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (s) return s;
    NSStringEncoding win = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingWindowsLatin2);
    s = [[NSString alloc] initWithData:data encoding:win];
    if (s) return s;
    return [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
}

static void entryCallback(void *ctx, const char *name, const char *group, const char *logo, const char *url)
{
    NSMutableArray *list = (__bridge NSMutableArray *)ctx;
    M3UEntry *e = [[M3UEntry alloc] init];
    e.name = [NSString stringWithUTF8String:name] ?: @"";
    e.group = [NSString stringWithUTF8String:group] ?: @"";
    e.logo = [NSString stringWithUTF8String:logo] ?: @"";
    e.url = [NSString stringWithUTF8String:url] ?: @"";
    if ([e.url length]) [list addObject:e];
}

NSArray *M3UParse(NSString *text, BOOL *isHLS)
{
    const char *utf = [text UTF8String];
    size_t len = utf ? strlen(utf) : 0;
    if (isHLS) *isHLS = NO;
    if (!len) return [NSArray array];
    if (m3u_is_hls(utf, len)) {
        if (isHLS) *isHLS = YES;
        return [NSArray array];
    }
    NSMutableArray *list = [NSMutableArray array];
    m3u_parse(utf, len, entryCallback, (__bridge void *)list);
    return list;
}

void M3UFetch(NSString *url, void (^done)(NSData *data, NSString *error))
{
    NSURL *u = [NSURL URLWithString:url];
    NSString *scheme = [[u scheme] lowercaseString];
    if (!u || !([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"])) {
        done(nil, L(@"Adres musi zaczynać się od http:// lub https://"));
        return;
    }
    /* Klasy sieciowe bierzemy po nazwie w czasie działania: SDK 9.3 wpisuje je do CFNetwork,
     * a w iOS 6 są w Foundation, więc bezpośrednie odwołanie wyrzucałoby aplikację od razu po starcie. */
    Class reqClass = NSClassFromString(@"NSMutableURLRequest");
    Class connClass = NSClassFromString(@"NSURLConnection");
    Class httpClass = NSClassFromString(@"NSHTTPURLResponse");
    if (!reqClass || !connClass || !httpClass) {
        done(nil, L(@"Ten system nie ma potrzebnych funkcji sieciowych."));
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableURLRequest *req = [reqClass requestWithURL:u
                                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                            timeoutInterval:30.0];
        [req setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 6_0 like Mac OS X) AppleWebKit/536.26" forHTTPHeaderField:@"User-Agent"];
        NSURLResponse *resp = nil;
        NSError *err = nil;
        NSData *data = [connClass sendSynchronousRequest:req returningResponse:&resp error:&err];
        NSInteger code = [resp isKindOfClass:httpClass] ? [(NSHTTPURLResponse *)resp statusCode] : 0;
        NSString *msg = nil;
        if (!data) {
            if ([[err domain] isEqualToString:@"NSURLErrorDomain"] && [err code] <= -1200 && [err code] >= -1206) {
                msg = L(@"Telefon nie mógł nawiązać bezpiecznego połączenia (HTTPS). Spróbuj adresu z http:// albo zainstaluj poprawkę SSL/TLS z Cydii i sprawdź datę w telefonie.");
            } else {
                msg = [NSString stringWithFormat:L(@"Nie udało się pobrać listy: %@"), [err localizedDescription] ?: L(@"brak połączenia")];
            }
        } else if (code >= 400) {
            msg = [NSString stringWithFormat:L(@"Serwer zwrócił błąd %d"), (int)code];
            data = nil;
        } else if ([data length] == 0) {
            msg = L(@"Lista jest pusta");
            data = nil;
        }
        dispatch_async(dispatch_get_main_queue(), ^{ done(data, msg); });
    });
}
