#import "M3UEpg.h"
#import "M3UList.h"
#import "M3ULocalization.h"

NSString *const M3UEpgDidUpdate = @"M3UEpgDidUpdate";
NSString *const M3UEpgDefaultURL = @"https://github.com/slam0/m3u8/releases/download/epg/epg.json";

static NSString *const kEnabledKey = @"epg_enabled";
static NSString *const kURLKey = @"epg_url";
static const NSTimeInterval kMaxAge = 6 * 3600;

static NSDictionary *gIndex;       /* klucz nazwy -> tablica programów [[start, stop, tytuł], ...] */
static NSUInteger gCount;
static NSString *gStatus;
static BOOL gBusy, gLoadingCache;

BOOL M3UEpgEnabled(void)
{
    id v = [[NSUserDefaults standardUserDefaults] objectForKey:kEnabledKey];
    return v ? [v boolValue] : YES;
}

void M3UEpgSetEnabled(BOOL on)
{
    [[NSUserDefaults standardUserDefaults] setBool:on forKey:kEnabledKey];
    if (on) M3UEpgRefresh(NO);
    [[NSNotificationCenter defaultCenter] postNotificationName:M3UEpgDidUpdate object:nil];
}

NSString *M3UEpgURL(void)
{
    NSString *u = [[NSUserDefaults standardUserDefaults] stringForKey:kURLKey];
    return [u length] ? u : M3UEpgDefaultURL;
}

void M3UEpgSetURL(NSString *url)
{
    NSString *t = [url stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (![t length] || [t isEqualToString:M3UEpgDefaultURL]) [[NSUserDefaults standardUserDefaults] removeObjectForKey:kURLKey];
    else [[NSUserDefaults standardUserDefaults] setObject:t forKey:kURLKey];
}

NSString *M3UEpgStatus(void) { return gStatus; }
NSUInteger M3UEpgChannelCount(void) { return gCount; }

#pragma mark - Dopasowanie nazw

/* Kanał z playlisty i kanał z programu muszą dać ten sam klucz: małe litery, ё=е, tylko litery, cyfry i "+",
 * pomijamy słowa HD / FHD / SD / UHD / 4K, resztę sklejamy. "Первый канал (+2)" -> "первыйканал+2". */
static NSString *normalize(NSString *s)
{
    if (![s length]) return @"";
    NSString *l = [[s lowercaseString] stringByReplacingOccurrencesOfString:@"ё" withString:@"е"];
    NSUInteger n = [l length];
    NSMutableString *flat = [NSMutableString stringWithCapacity:n];
    /* nawiasy z miastem, np. "(Омск)", pomijamy; nawias zaczynający się od "+" (np. "(+2)") zostaje */
    for (NSUInteger i = 0; i < n; i++) {
        unichar c = [l characterAtIndex:i];
        if (c == '(') {
            NSUInteger j = i + 1;
            while (j < n && [l characterAtIndex:j] == ' ') j++;
            if (!(j < n && [l characterAtIndex:j] == '+')) {
                while (i < n && [l characterAtIndex:i] != ')') i++;
                [flat appendString:@" "];
                continue;
            }
        }
        [flat appendFormat:@"%C", c];
    }
    NSCharacterSet *alnum = [NSCharacterSet alphanumericCharacterSet];
    NSMutableString *out = [NSMutableString string], *tok = [NSMutableString string];
    n = [flat length];
    for (NSUInteger i = 0; i <= n; i++) {
        unichar c = i < n ? [flat characterAtIndex:i] : ' ';
        if ([alnum characterIsMember:c] || c == '+') {
            [tok appendFormat:@"%C", c];
        } else if ([tok length]) {
            if (!([tok isEqualToString:@"hd"] || [tok isEqualToString:@"fhd"] || [tok isEqualToString:@"sd"] ||
                  [tok isEqualToString:@"uhd"] || [tok isEqualToString:@"4k"] || [tok isEqualToString:@"orig"] ||
                  [tok isEqualToString:@"original"] || [tok isEqualToString:@"+0"])) [out appendString:tok];
            [tok setString:@""];
        }
    }
    return out;
}

#pragma mark - Wczytywanie

static NSString *cachePath(void)
{
    return [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"epg.json"];
}

static NSDate *cacheDate(void)
{
    NSDictionary *a = [[NSFileManager defaultManager] attributesOfItemAtPath:cachePath() error:NULL];
    return [a objectForKey:NSFileModificationDate];
}

/* Parsowanie poza głównym wątkiem; do pamięci trafia tylko indeks nazw, reszta zostaje zwolniona. */
static void parseAndInstall(NSData *data, NSString *statusOnOK)
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSDictionary *root = nil;
        @try { root = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]; } @catch (NSException *e) { root = nil; }
        NSArray *chans = [root isKindOfClass:[NSDictionary class]] ? [root objectForKey:@"c"] : nil;
        NSMutableDictionary *idx = nil;
        NSUInteger count = 0;
        if ([chans isKindOfClass:[NSArray class]]) {
            idx = [NSMutableDictionary dictionaryWithCapacity:[chans count] * 2];
            for (NSDictionary *c in chans) {
                NSArray *p = [c objectForKey:@"p"];
                if (![p count]) continue;
                count++;
                for (NSString *name in [c objectForKey:@"n"]) {
                    NSString *k = normalize(name);
                    if ([k length] && ![idx objectForKey:k]) [idx setObject:p forKey:k];
                }
            }
        }
        root = nil; chans = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (idx && count) {
                gIndex = idx;
                gCount = count;
                gStatus = statusOnOK;
            } else {
                gStatus = [NSString stringWithFormat:L(@"Nie udało się pobrać programu: %@"), L(@"nieznany błąd")];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:M3UEpgDidUpdate object:nil];
        });
    });
}

void M3UEpgRefresh(BOOL force)
{
    if (!M3UEpgEnabled() || gBusy) return;
    NSDate *saved = cacheDate();
    if (!gIndex && saved && !gLoadingCache) {
        gLoadingCache = YES;
        NSData *d = [NSData dataWithContentsOfFile:cachePath()];
        if (d) parseAndInstall(d, nil);
    }
    BOOL stale = !saved || [[NSDate date] timeIntervalSinceDate:saved] > kMaxAge;
    if (!force && !stale) return;
    gBusy = YES;
    gStatus = L(@"Pobieram…");
    [[NSNotificationCenter defaultCenter] postNotificationName:M3UEpgDidUpdate object:nil];
    M3UFetch(M3UEpgURL(), ^(NSData *data, NSString *error) {
        gBusy = NO;
        if (!data) {
            gStatus = [NSString stringWithFormat:L(@"Nie udało się pobrać programu: %@"), error ?: @"?"];
            [[NSNotificationCenter defaultCenter] postNotificationName:M3UEpgDidUpdate object:nil];
            return;
        }
        [data writeToFile:cachePath() atomically:YES];
        parseAndInstall(data, nil);
    });
}

#pragma mark - Zapytania

NSString *M3UEpgClock(NSTimeInterval t)
{
    static NSDateFormatter *f;
    if (!f) { f = [[NSDateFormatter alloc] init]; f.dateFormat = @"HH:mm"; }
    return [f stringFromDate:[NSDate dateWithTimeIntervalSince1970:t]];
}

NSDictionary *M3UEpgFor(NSString *channelName)
{
    if (!gIndex) return nil;
    NSArray *p = [gIndex objectForKey:normalize(channelName)];
    if (![p count]) return nil;
    double now = [[NSDate date] timeIntervalSince1970];
    NSMutableDictionary *r = [NSMutableDictionary dictionary];
    for (NSUInteger i = 0; i < [p count]; i++) {
        NSArray *e = [p objectAtIndex:i];
        if ([e count] < 3) continue;
        double s = [[e objectAtIndex:0] doubleValue], t = [[e objectAtIndex:1] doubleValue];
        if (t <= now) continue;
        if (s <= now) {
            [r setObject:[e objectAtIndex:2] forKey:@"now"];
            [r setObject:[NSNumber numberWithDouble:s] forKey:@"start"];
            [r setObject:[NSNumber numberWithDouble:t] forKey:@"end"];
            if (i + 1 < [p count]) {
                NSArray *n = [p objectAtIndex:i + 1];
                if ([n count] >= 3) {
                    [r setObject:[n objectAtIndex:2] forKey:@"next"];
                    [r setObject:[n objectAtIndex:0] forKey:@"nextStart"];
                    [r setObject:[n objectAtIndex:1] forKey:@"nextEnd"];
                }
            }
        } else {                                                  /* przerwa w ramówce: pokazujemy tylko następny */
            [r setObject:[e objectAtIndex:2] forKey:@"next"];
            [r setObject:[e objectAtIndex:0] forKey:@"nextStart"];
            [r setObject:[e objectAtIndex:1] forKey:@"nextEnd"];
        }
        break;
    }
    return [r count] ? r : nil;
}
