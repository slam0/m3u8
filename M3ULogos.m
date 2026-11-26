#import "M3ULogos.h"

NSString *const M3ULogoDidLoad = @"M3ULogoDidLoad";

static const CGFloat kSide = 46.0f;
static const NSUInteger kMaxBytes = 1500000;

static NSCache *memory;
static NSMutableSet *failed;
static NSMutableSet *inflight;
static NSOperationQueue *queue;
static UIImage *placeholder;
static CGFloat screenScale = 1.0f;

static void setup(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        memory = [[NSCache alloc] init];
        memory.countLimit = 300;
        failed = [[NSMutableSet alloc] init];
        inflight = [[NSMutableSet alloc] init];
        queue = [[NSOperationQueue alloc] init];
        queue.maxConcurrentOperationCount = 3;
        screenScale = [[UIScreen mainScreen] scale];
    });
}

/* Ramka kafelka ze szklanym połyskiem; logo (jeśli jest) wpisane w środek z zachowaniem proporcji. */
static UIImage *composeTile(UIImage *logo)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(kSide, kSide), NO, screenScale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect r = CGRectMake(1.0f, 1.0f, kSide - 2.0f, kSide - 2.0f);
    UIBezierPath *shape = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:8.0f];

    CGContextSaveGState(ctx);
    [shape addClip];
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGFloat colors[8] = { 1.0f, 1.0f, 1.0f, 1.0f,  0.88f, 0.85f, 0.78f, 1.0f };
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, colors, NULL, 2);
    CGContextDrawLinearGradient(ctx, g, CGPointMake(0, 1), CGPointMake(0, kSide - 1.0f), 0);
    CGGradientRelease(g);
    CGColorSpaceRelease(cs);

    if (logo && logo.size.width > 0 && logo.size.height > 0) {
        CGFloat box = kSide - 12.0f;
        CGFloat kx = box / logo.size.width, ky = box / logo.size.height;
        CGFloat k = kx < ky ? kx : ky;
        CGSize sz = CGSizeMake(logo.size.width * k, logo.size.height * k);
        CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
        [logo drawInRect:CGRectMake((kSide - sz.width) / 2.0f, (kSide - sz.height) / 2.0f, sz.width, sz.height)];
    } else {
        /* brak logo: brązowy krążek z trójkątem „play” */
        CGRect disc = CGRectMake(11, 11, kSide - 22.0f, kSide - 22.0f);
        CGContextSetRGBFillColor(ctx, 0.36f, 0.25f, 0.18f, 1.0f);
        CGContextFillEllipseInRect(ctx, disc);
        CGContextSetRGBFillColor(ctx, 0.96f, 0.92f, 0.80f, 1.0f);
        CGContextMoveToPoint(ctx, 20.0f, 17.0f);
        CGContextAddLineToPoint(ctx, 20.0f, 29.0f);
        CGContextAddLineToPoint(ctx, 30.0f, 23.0f);
        CGContextFillPath(ctx);
    }

    /* szklany połysk na górnej połowie */
    CGContextSetRGBFillColor(ctx, 1.0f, 1.0f, 1.0f, 0.30f);
    CGContextFillRect(ctx, CGRectMake(0, 0, kSide, kSide / 2.0f));
    CGContextRestoreGState(ctx);

    [[UIColor colorWithRed:0.43f green:0.34f blue:0.25f alpha:1.0f] setStroke];
    shape.lineWidth = 1.0f;
    [shape stroke];
    UIImage *out = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return out;
}

UIImage *M3UPlaceholderTile(void)
{
    setup();
    if (!placeholder) placeholder = composeTile(nil);
    return placeholder;
}

UIImage *M3UCachedLogoTile(NSString *url)
{
    setup();
    return url ? [memory objectForKey:url] : nil;
}

BOOL M3ULogoFailed(NSString *url)
{
    setup();
    return url && [failed containsObject:url];
}

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

/* Pobiera bajty logo; klasy sieciowe po nazwie (patrz M3UList.m). */
static NSData *download(NSString *urlString)
{
    NSURL *u = [NSURL URLWithString:urlString];
    NSString *scheme = [[u scheme] lowercaseString];
    if (!u || !([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"])) return nil;
    Class reqClass = NSClassFromString(@"NSMutableURLRequest");
    Class connClass = NSClassFromString(@"NSURLConnection");
    if (!reqClass || !connClass) return nil;
    NSMutableURLRequest *req = [reqClass requestWithURL:u cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:15.0];
    NSURLResponse *resp = nil;
    NSError *err = nil;
    NSData *d = [connClass sendSynchronousRequest:req returningResponse:&resp error:&err];
    return (d && [d length] <= kMaxBytes) ? d : nil;
}

void M3URequestLogo(NSString *url, BOOL (^stillNeeded)(void))
{
    setup();
    if (![url length] || [memory objectForKey:url] || [failed containsObject:url] || [inflight containsObject:url]) return;
    [inflight addObject:url];
    [queue addOperationWithBlock:^{
        __block BOOL needed = YES;
        if (stillNeeded) dispatch_sync(dispatch_get_main_queue(), ^{ needed = stillNeeded(); });
        if (!needed) {
            dispatch_async(dispatch_get_main_queue(), ^{ [inflight removeObject:url]; });
            return;
        }
        @autoreleasepool {
            NSString *path = diskPath(url);
            NSData *data = [NSData dataWithContentsOfFile:path];
            if (!data) {
                data = download(url);
                if (data) [data writeToFile:path atomically:YES];
            }
            UIImage *logo = data ? [UIImage imageWithData:data] : nil;
            UIImage *tile = logo ? composeTile(logo) : nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                [inflight removeObject:url];
                if (tile) [memory setObject:tile forKey:url]; else [failed addObject:url];
                [[NSNotificationCenter defaultCenter] postNotificationName:M3ULogoDidLoad object:nil];
            });
        }
    }];
}
