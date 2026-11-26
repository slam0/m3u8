#import "M3UList.h"
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
        done(nil, @"Adres musi zaczynać się od http:// lub https://");
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:u
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:30.0];
        [req setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 6_0 like Mac OS X) AppleWebKit/536.26" forHTTPHeaderField:@"User-Agent"];
        NSHTTPURLResponse *resp = nil;
        NSError *err = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:&err];
        NSString *msg = nil;
        if (!data) {
            msg = [NSString stringWithFormat:@"Nie udało się pobrać listy: %@", [err localizedDescription] ?: @"brak połączenia"];
        } else if ([resp isKindOfClass:[NSHTTPURLResponse class]] && [resp statusCode] >= 400) {
            msg = [NSString stringWithFormat:@"Serwer zwrócił błąd %d", (int)[resp statusCode]];
            data = nil;
        } else if ([data length] == 0) {
            msg = @"Lista jest pusta";
            data = nil;
        }
        dispatch_async(dispatch_get_main_queue(), ^{ done(data, msg); });
    });
}
