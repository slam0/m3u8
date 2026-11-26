#import "M3ULogos.h"

NSString *const M3ULogoDidLoad = @"M3ULogoDidLoad";

static const NSUInteger kMaxBytes = 1500000;

/* Słowniki zamiast NSCache: SDK 9.3 wiąże NSCache z CoreFoundation, a w iOS 6 jest w Foundation. */
static NSMutableDictionary *tiles;        /* "bok|url" -> kafelek z logo */
static NSMutableDictionary *monograms;    /* "bok|nazwa" -> płytka z inicjałami */
static NSMutableDictionary *failed;       /* url -> powód błędu */
static NSMutableSet *inflight;            /* "bok|url" */
static NSOperationQueue *queue;
static CGFloat screenScale = 1.0f;

static void setup(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        tiles = [[NSMutableDictionary alloc] init];
        monograms = [[NSMutableDictionary alloc] init];
        failed = [[NSMutableDictionary alloc] init];
        inflight = [[NSMutableSet alloc] init];
        queue = [[NSOperationQueue alloc] init];
        queue.maxConcurrentOperationCount = 3;
        screenScale = [[UIScreen mainScreen] scale];
    });
}

static NSString *key(CGFloat side, NSString *s) { return [NSString stringWithFormat:@"%d|%@", (int)side, s]; }

#pragma mark - Rysowanie

static void gradientFill(CGContextRef ctx, CGRect r, const CGFloat c[8])
{
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, c, NULL, 2);
    CGContextDrawLinearGradient(ctx, g, CGPointMake(0, r.origin.y), CGPointMake(0, r.origin.y + r.size.height), 0);
    CGGradientRelease(g);
    CGColorSpaceRelease(cs);
}

/* Wspólna oprawa: zaokrąglona płytka z gradientem, szklanym połyskiem i ciemnym obrysem. */
static UIImage *drawTile(CGFloat side, const CGFloat grad[8], void (^content)(CGContextRef ctx))
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, screenScale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGFloat radius = side * 0.18f;
    CGRect r = CGRectMake(1.0f, 1.0f, side - 2.0f, side - 2.0f);
    UIBezierPath *shape = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:radius];
    CGContextSaveGState(ctx);
    [shape addClip];
    gradientFill(ctx, r, grad);
    if (content) content(ctx);
    CGContextSetRGBFillColor(ctx, 1.0f, 1.0f, 1.0f, 0.22f);          /* szklany połysk */
    CGContextFillRect(ctx, CGRectMake(0, 0, side, side * 0.5f));
    CGContextRestoreGState(ctx);
    [[UIColor colorWithRed:0.03f green:0.05f blue:0.11f alpha:0.95f] setStroke];
    shape.lineWidth = 1.0f;
    [shape stroke];
    UIImage *out = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return out;
}

static UIImage *composeLogoTile(UIImage *logo, CGFloat side)
{
    static const CGFloat plate[8] = { 1.0f, 1.0f, 1.0f, 1.0f,  0.84f, 0.87f, 0.93f, 1.0f };
    return drawTile(side, plate, ^(CGContextRef ctx) {
        if (logo.size.width <= 0 || logo.size.height <= 0) return;
        CGFloat box = side - side * 0.26f;
        CGFloat kx = box / logo.size.width, ky = box / logo.size.height;
        CGFloat k = kx < ky ? kx : ky;
        CGSize sz = CGSizeMake(logo.size.width * k, logo.size.height * k);
        CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
        [logo drawInRect:CGRectMake((side - sz.width) / 2.0f, (side - sz.height) / 2.0f, sz.width, sz.height)];
    });
}

/* Średnia jasność widocznych pikseli logo (0..1) i jego „pokrycie” (0..1) - do wyboru tła pod logo. */
static void logoStats(UIImage *logo, CGFloat *lum, CGFloat *coverage)
{
    enum { N = 24 };
    unsigned char px[N * N * 4];
    for (int i = 0; i < N * N * 4; i++) px[i] = 0;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef c = CGBitmapContextCreate(px, N, N, 8, N * 4, cs, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(cs);
    *lum = 1.0f; *coverage = 1.0f;
    if (!c) return;
    CGContextDrawImage(c, CGRectMake(0, 0, N, N), logo.CGImage);
    CGContextRelease(c);
    double a = 0, l = 0;
    for (int i = 0; i < N * N; i++) {
        double al = px[i * 4 + 3] / 255.0;
        /* piksele są premultiplikowane, więc suma kanałów to już jasność ważona kryciem */
        l += (0.30 * px[i * 4] + 0.59 * px[i * 4 + 1] + 0.11 * px[i * 4 + 2]) / 255.0;
        a += al;
    }
    *coverage = (CGFloat)(a / (N * N));
    *lum = a > 0.5 ? (CGFloat)(l / a) : 1.0f;
}

/* Logo w swoich proporcjach (bez kwadratowej płytki), do dużych kafelków. Przezroczyste, ciemne logo
 * dostaje jasną podkładkę, żeby było widać na granatowej karcie. */
static UIImage *composeLogoWide(UIImage *logo)
{
    if (logo.size.width <= 0 || logo.size.height <= 0) return nil;
    const CGFloat maxW = 190.0f, maxH = 110.0f;
    CGFloat kx = maxW / logo.size.width, ky = maxH / logo.size.height;
    CGFloat k = kx < ky ? kx : ky;
    if (k > 1.0f) k = 1.0f;
    CGSize sz = CGSizeMake((CGFloat)(int)(logo.size.width * k + 0.5f), (CGFloat)(int)(logo.size.height * k + 0.5f));
    if (sz.width < 1) sz.width = 1;
    if (sz.height < 1) sz.height = 1;

    CGFloat lum, cov;
    logoStats(logo, &lum, &cov);
    BOOL plate = (cov < 0.92f && lum < 0.38f);

    CGFloat pad = plate ? 8.0f : 0.0f;
    CGSize full = CGSizeMake(sz.width + pad * 2.0f, sz.height + pad * 2.0f);
    UIGraphicsBeginImageContextWithOptions(full, NO, screenScale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (plate) {
        static const CGFloat g[8] = { 1.0f, 1.0f, 1.0f, 1.0f,  0.84f, 0.87f, 0.93f, 1.0f };
        CGContextSaveGState(ctx);
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, full.width, full.height) cornerRadius:10.0f] addClip];
        gradientFill(ctx, CGRectMake(0, 0, full.width, full.height), g);
        CGContextRestoreGState(ctx);
    }
    CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
    [logo drawInRect:CGRectMake(pad, pad, sz.width, sz.height)];
    UIImage *out = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return out;
}

static NSString *initials(NSString *name)
{
    NSMutableString *out = [NSMutableString string];
    NSArray *words = [name componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSCharacterSet *alnum = [NSCharacterSet alphanumericCharacterSet];
    NSMutableArray *usable = [NSMutableArray array];
    for (NSString *w in words) {
        for (NSUInteger i = 0; i < [w length]; i++) {
            if ([alnum characterIsMember:[w characterAtIndex:i]]) { [usable addObject:[w substringFromIndex:i]]; break; }
        }
    }
    if ([usable count] >= 2) {
        [out appendString:[[usable objectAtIndex:0] substringToIndex:1]];
        [out appendString:[[usable objectAtIndex:1] substringToIndex:1]];
    } else if ([usable count] == 1) {
        NSString *w = [usable objectAtIndex:0];
        [out appendString:[w substringToIndex:MIN((NSUInteger)2, [w length])]];
    } else {
        [out appendString:@"TV"];
    }
    return [out uppercaseString];
}

UIImage *M3UMonogramTile(NSString *name, CGFloat side)
{
    setup();
    NSString *k = key(side, name ?: @"");
    UIImage *cached = [monograms objectForKey:k];
    if (cached) return cached;

    /* paleta dobrana do granatowego motywu; kolor wynika z nazwy, więc kanał zawsze ma ten sam */
    static const CGFloat palettes[8][8] = {
        { 0.36f, 0.56f, 0.92f, 1.0f,  0.14f, 0.29f, 0.66f, 1.0f },   /* niebieski */
        { 0.22f, 0.68f, 0.72f, 1.0f,  0.07f, 0.38f, 0.46f, 1.0f },   /* turkus */
        { 0.46f, 0.50f, 0.90f, 1.0f,  0.20f, 0.22f, 0.60f, 1.0f },   /* indygo */
        { 0.60f, 0.42f, 0.84f, 1.0f,  0.32f, 0.18f, 0.58f, 1.0f },   /* fiolet */
        { 0.42f, 0.55f, 0.68f, 1.0f,  0.20f, 0.29f, 0.42f, 1.0f },   /* stal */
        { 0.26f, 0.66f, 0.52f, 1.0f,  0.08f, 0.38f, 0.30f, 1.0f },   /* morski */
        { 0.78f, 0.38f, 0.58f, 1.0f,  0.48f, 0.15f, 0.34f, 1.0f },   /* malina */
        { 0.86f, 0.60f, 0.26f, 1.0f,  0.56f, 0.34f, 0.08f, 1.0f },   /* bursztyn */
    };
    unsigned long h = 5381;
    const char *c = [name UTF8String];
    while (c && *c) h = h * 33 + (unsigned char)*c++;
    const CGFloat *pal = palettes[h % 8];
    NSString *text = initials(name);
    UIFont *font = [UIFont boldSystemFontOfSize:side * 0.38f];
    UIImage *img = drawTile(side, pal, ^(CGContextRef ctx) {
        CGSize ts = [text sizeWithFont:font];
        CGRect tr = CGRectMake(0, (side - ts.height) / 2.0f - 1.0f, side, ts.height);
        CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.45f);
        [text drawInRect:CGRectOffset(tr, 0, 1.0f) withFont:font lineBreakMode:NSLineBreakByClipping alignment:NSTextAlignmentCenter];
        CGContextSetRGBFillColor(ctx, 1, 1, 1, 0.96f);
        [text drawInRect:tr withFont:font lineBreakMode:NSLineBreakByClipping alignment:NSTextAlignmentCenter];
    });
    if ([monograms count] >= 400) [monograms removeAllObjects];
    [monograms setObject:img forKey:k];
    return img;
}

#pragma mark - Pamięć i status

UIImage *M3UCachedLogoTile(NSString *url, CGFloat side)
{
    setup();
    return [url length] ? [tiles objectForKey:key(side, url)] : nil;
}

BOOL M3ULogoFailed(NSString *url)
{
    setup();
    return [url length] && [failed objectForKey:url] != nil;
}

NSString *M3ULogoStatus(NSString *url)
{
    setup();
    if (![url length]) return @"ta lista nie podaje logo dla tego kanału";
    NSString *why = [failed objectForKey:url];
    if (why) return [@"nie pobrano: " stringByAppendingString:why];
    for (NSString *k in [tiles allKeys]) if ([k hasSuffix:[@"|" stringByAppendingString:url]]) return @"pobrane";
    for (NSString *k in inflight) if ([k hasSuffix:[@"|" stringByAppendingString:url]]) return @"pobieranie…";
    return @"jeszcze nie pobierano (pojawi się po przewinięciu do kanału)";
}

#pragma mark - Pobieranie

static NSString *diskPath(NSString *url)
{
    unsigned long h = 5381;
    const char *c = [url UTF8String];
    while (c && *c) h = h * 33 + (unsigned char)*c++;
    NSString *dir = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0]
                     stringByAppendingPathComponent:@"logos"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
    return [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%lx.img", h]];
}

/* Jedna próba pobrania. Klasy sieciowe po nazwie (patrz M3UList.m). */
static NSData *attempt(NSString *urlString, NSString **why)
{
    NSURL *u = [NSURL URLWithString:urlString];
    NSString *scheme = [[u scheme] lowercaseString];
    if (!u || !([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"])) { *why = @"adres nie jest http(s)"; return nil; }
    Class reqClass = NSClassFromString(@"NSMutableURLRequest");
    Class connClass = NSClassFromString(@"NSURLConnection");
    Class httpClass = NSClassFromString(@"NSHTTPURLResponse");
    if (!reqClass || !connClass || !httpClass) { *why = @"brak funkcji sieciowych"; return nil; }
    NSMutableURLRequest *req = [reqClass requestWithURL:u cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:15.0];
    NSURLResponse *resp = nil;
    NSError *err = nil;
    NSData *d = [connClass sendSynchronousRequest:req returningResponse:&resp error:&err];
    NSInteger code = [resp isKindOfClass:httpClass] ? [(NSHTTPURLResponse *)resp statusCode] : 0;
    if (!d) {
        NSInteger c = [err code];
        if ([[err domain] isEqualToString:@"NSURLErrorDomain"] && c <= -1200 && c >= -1206) *why = @"połączenie https nie powiodło się (stare SSL w iOS 6)";
        else *why = [err localizedDescription] ?: @"brak odpowiedzi";
        return nil;
    }
    if (code >= 400) { *why = [NSString stringWithFormat:@"serwer zwrócił błąd %d", (int)code]; return nil; }
    if ([d length] > kMaxBytes) { *why = @"plik jest za duży"; return nil; }
    return d;
}

/* Najpierw adres z listy, a przy https dodatkowo wersja http (iOS 6 często nie dogaduje się z nowym SSL). */
static NSData *download(NSString *url, NSString **why)
{
    NSData *d = attempt(url, why);
    if (!d && [[url lowercaseString] hasPrefix:@"https://"]) {
        NSString *w2 = nil;
        d = attempt([@"http://" stringByAppendingString:[url substringFromIndex:8]], &w2);
        if (d) *why = nil;
    }
    return d;
}

void M3URequestLogo(NSString *url, CGFloat side, BOOL (^stillNeeded)(void))
{
    setup();
    NSString *k = key(side, url ?: @"");
    if (![url length] || [tiles objectForKey:k] || [failed objectForKey:url] || [inflight containsObject:k]) return;
    [inflight addObject:k];
    [queue addOperationWithBlock:^{
        __block BOOL needed = YES;
        if (stillNeeded) dispatch_sync(dispatch_get_main_queue(), ^{ needed = stillNeeded(); });
        if (!needed) {
            dispatch_async(dispatch_get_main_queue(), ^{ [inflight removeObject:k]; });
            return;
        }
        @autoreleasepool {
            NSString *path = diskPath(url);
            NSData *data = [NSData dataWithContentsOfFile:path];
            NSString *why = nil;
            if (!data) {
                data = download(url, &why);
                if (data && [UIImage imageWithData:data]) [data writeToFile:path atomically:YES];
            }
            UIImage *logo = data ? [UIImage imageWithData:data] : nil;
            if (data && !logo) why = @"to nie jest obraz obsługiwany przez iOS 6 (np. WebP albo SVG)";
            UIImage *tile = logo ? (side > 0 ? composeLogoTile(logo, side) : composeLogoWide(logo)) : nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                [inflight removeObject:k];
                if (tile) {
                    if ([tiles count] >= 250) [tiles removeAllObjects];
                    [tiles setObject:tile forKey:k];
                } else {
                    [failed setObject:(why ?: @"nieznany błąd") forKey:url];
                }
                [[NSNotificationCenter defaultCenter] postNotificationName:M3ULogoDidLoad object:nil];
            });
        }
    }];
}
