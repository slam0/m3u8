#import "M3UPortal.h"
#import "M3ULocalization.h"

BOOL M3UIsPortalLink(NSString *s)
{
    return [[s lowercaseString] hasPrefix:@"portal::"];
}

/* Klasy sieciowe po nazwie - patrz M3UFetch (iOS 6 i dyld). */
static NSData *netSend(NSURL *u, NSData *body, NSString *contentType, NSInteger *code, NSError **err)
{
    Class reqClass = NSClassFromString(@"NSMutableURLRequest");
    Class connClass = NSClassFromString(@"NSURLConnection");
    Class httpClass = NSClassFromString(@"NSHTTPURLResponse");
    if (!reqClass || !connClass || !httpClass) return nil;
    NSMutableURLRequest *req = [reqClass requestWithURL:u cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30.0];
    [req setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 6_0 like Mac OS X) AppleWebKit/536.26" forHTTPHeaderField:@"User-Agent"];
    if (body) {
        [req setHTTPMethod:@"POST"];
        [req setValue:contentType forHTTPHeaderField:@"Content-Type"];
        [req setHTTPBody:body];
    }
    NSURLResponse *resp = nil;
    NSData *data = [connClass sendSynchronousRequest:req returningResponse:&resp error:err];
    *code = [resp isKindOfClass:httpClass] ? [(NSHTTPURLResponse *)resp statusCode] : 0;
    return data;
}

@implementation M3UPortal {
    NSMutableDictionary *_cache;
    NSMutableArray *_pending;      /* [url, done] czekające na wolne miejsce */
    int _active;
}

+ (M3UPortal *)portalFromLink:(NSString *)link
{
    NSString *s = [link stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!M3UIsPortalLink(s)) return nil;
    s = [s substringFromIndex:8];
    NSRange k = [s rangeOfString:@"[key:"];
    if (k.location != 0) return nil;
    NSRange e = [s rangeOfString:@"]"];
    if (e.location == NSNotFound || e.location <= 5) return nil;
    NSString *key = [s substringWithRange:NSMakeRange(5, e.location - 5)];
    NSString *url = [s substringFromIndex:e.location + 1];
    NSString *low = [url lowercaseString];
    if (![key length] || !([low hasPrefix:@"http://"] || [low hasPrefix:@"https://"]) || ![NSURL URLWithString:url]) return nil;
    M3UPortal *p = [[M3UPortal alloc] init];
    p->_key = [key copy];
    p->_apiURL = [url copy];
    p->_cache = [NSMutableDictionary dictionary];
    p->_pending = [NSMutableArray array];
    [[NSNotificationCenter defaultCenter] addObserver:p selector:@selector(memoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    return p;
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)memoryWarning { [_cache removeAllObjects]; }

- (void)request:(NSDictionary *)params done:(void (^)(NSDictionary *, NSString *))done
{
    NSMutableDictionary *body = [NSMutableDictionary dictionaryWithDictionary:params ?: [NSDictionary dictionary]];
    [body setObject:_key forKey:@"key"];
    NSData *json = [NSJSONSerialization dataWithJSONObject:body options:0 error:NULL];
    NSURL *u = [NSURL URLWithString:_apiURL];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSInteger code = 0;
        NSError *err = nil;
        NSData *data = netSend(u, json, @"application/json", &code, &err);
        NSDictionary *obj = nil;
        NSString *msg = nil;
        if (!data) {
            msg = [NSString stringWithFormat:L(@"Nie udało się połączyć z mediateką: %@"), [err localizedDescription] ?: L(@"brak połączenia")];
        } else if (code >= 400) {
            msg = [NSString stringWithFormat:L(@"Serwer zwrócił błąd %d"), (int)code];
        } else {
            id j = nil;
            @try { j = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]; } @catch (NSException *x) { j = nil; }
            if (![j isKindOfClass:[NSDictionary class]]) {
                msg = L(@"Mediateka zwróciła niezrozumiałą odpowiedź.");
            } else if ([[j objectForKey:@"type"] isEqual:@"error"]) {
                NSString *d = [j objectForKey:@"description"];
                msg = [d isKindOfClass:[NSString class]] && [d length] ? [NSString stringWithFormat:L(@"Mediateka: %@"), d] : L(@"Mediateka zwróciła błąd.");
            } else {
                obj = j;
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{ done(obj, msg); });
    });
}

- (UIImage *)cachedImage:(NSString *)url { return url ? [_cache objectForKey:url] : nil; }

- (void)loadImage:(NSString *)url done:(void (^)(UIImage *))done
{
    if (![url length]) { done(nil); return; }
    UIImage *c = [_cache objectForKey:url];
    if (c) { done(c); return; }
    [_pending addObject:[NSArray arrayWithObjects:url, [done copy], nil]];
    [self pump];
}

- (void)pump
{
    while (_active < 4 && [_pending count]) {
        NSArray *job = [_pending lastObject];           /* najnowsze pierwsze: wiersze, które widać teraz */
        [_pending removeLastObject];
        NSString *url = [job objectAtIndex:0];
        void (^done)(UIImage *) = [job objectAtIndex:1];
        NSURL *u = [NSURL URLWithString:url];
        _active++;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSInteger code = 0;
            NSError *err = nil;
            NSData *data = u ? netSend(u, nil, nil, &code, &err) : nil;
            UIImage *img = (data && code < 400) ? [UIImage imageWithData:data] : nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                _active--;
                if (img) {
                    if ([_cache count] > 120) [_cache removeAllObjects];
                    [_cache setObject:img forKey:url];
                }
                done(img);
                [self pump];
            });
        });
    }
}

@end
