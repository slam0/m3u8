#import "M3UPlayerController.h"
#import "M3UTheme.h"
#import "M3ULogos.h"
#import "M3UEpg.h"
#import "M3ULocalization.h"
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>

static BOOL isPhone(void) { return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone; }
static const CGFloat kEdge = 44.0f;        /* szerokość pasków przy krawędziach, od których zaczyna się przesunięcie */
static const CGFloat kRow = 62.0f;
static const double kLiveGap = 30.0;       /* bliżej „teraz” niż tyle sekund = transmisja na żywo */
static const double kArchiveDepth = 7.0 * 86400.0;

/* Ikony przycisków rysowane kodem: pauza (dwie kreski) i odtwarzanie (trójkąt). */
static UIImage *playIcon(BOOL pause)
{
    CGFloat s = 28.0f;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(s, s), NO, [[UIScreen mainScreen] scale]);
    CGContextRef c = UIGraphicsGetCurrentContext();
    for (int pass = 0; pass < 2; pass++) {
        CGFloat dy = pass == 0 ? 1.0f : 0.0f;
        if (pass == 0) CGContextSetRGBFillColor(c, 0, 0, 0, 0.6f); else CGContextSetRGBFillColor(c, 1, 1, 1, 1);
        if (pause) {
            CGContextFillRect(c, CGRectMake(6, 4 + dy, 6, 20));
            CGContextFillRect(c, CGRectMake(16, 4 + dy, 6, 20));
        } else {
            CGContextMoveToPoint(c, 7, 3 + dy);
            CGContextAddLineToPoint(c, 24, 14 + dy);
            CGContextAddLineToPoint(c, 7, 25 + dy);
            CGContextClosePath(c);
            CGContextFillPath(c);
        }
    }
    UIImage *i = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return i;
}


/* ---- wygląd w stylu iOS 6: gradienty z połyskiem rysowane kodem ---- */
enum { GS_BLUE, GS_GRAY, GS_NAV, GS_DARK, GS_SEL, GS_STRIP, GS_TOOL };
static void gsColors(int st, CGFloat *t, CGFloat *b, CGFloat *gloss)
{
    static const CGFloat tab[7][9] = {
        { 0.47f, 0.63f, 0.88f, 0.12f, 0.31f, 0.75f, 1, 1, 0.24f },   /* niebieski przycisk */
        { 0.51f, 0.55f, 0.63f, 0.18f, 0.20f, 0.27f, 1, 1, 0.22f },   /* szary przycisk */
        { 0.43f, 0.53f, 0.69f, 0.20f, 0.28f, 0.44f, 1, 1, 0.22f },   /* pasek nagłówka */
        { 0.13f, 0.14f, 0.16f, 0.00f, 0.00f, 0.00f, 0.86f, 0.90f, 0.10f },   /* czarny pasek (półprzezroczysty) */
        { 0.35f, 0.59f, 0.94f, 0.12f, 0.33f, 0.80f, 1, 1, 0.20f },   /* zaznaczony wiersz */
        { 0.16f, 0.19f, 0.26f, 0.09f, 0.11f, 0.17f, 1, 1, 0.08f },   /* pasek zakładek */
        { 0.27f, 0.31f, 0.41f, 0.11f, 0.13f, 0.20f, 1, 1, 0.15f }    /* dolny pasek narzędzi */
    };
    const CGFloat *r = tab[st];
    t[0] = r[0]; t[1] = r[1]; t[2] = r[2]; t[3] = r[6];
    b[0] = r[3]; b[1] = r[4]; b[2] = r[5]; b[3] = r[7];
    *gloss = r[8];
    int slot = (st == GS_NAV) ? 0 : (st == GS_BLUE ? 1 : (st == GS_SEL ? 2 : -1));
    if (slot >= 0 && M3UThemeIndex() != 0) M3UPlayerPalette(slot, t, b);       /* akcenty z wybranego motywu */
}

/* Obraz rozciągliwy w poziomie, o wysokości h. r = promień rogów, border = czarna ramka z jasnym wnętrzem. */
static UIImage *glossImage(int st, CGFloat h, CGFloat r, BOOL border, BOOL pressed)
{
    static NSMutableDictionary *cache;
    if (!cache) cache = [[NSMutableDictionary alloc] init];
    NSString *key = [NSString stringWithFormat:@"%d-%g-%g-%d-%d-%d", st, h, r, border, pressed, (int)M3UThemeIndex()];
    UIImage *hit = [cache objectForKey:key];
    if (hit) return hit;
    CGFloat t[4], b[4], gl;
    gsColors(st, t, b, &gl);
    if (pressed) for (int i = 0; i < 3; i++) { t[i] *= 0.7f; b[i] *= 0.7f; }
    CGFloat w = MAX(8.0f, 2.0f * r + 4.0f);
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(w, h), NO, [[UIScreen mainScreen] scale]);
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect rc = CGRectMake(0, 0, w, h);
    UIBezierPath *clip = [UIBezierPath bezierPathWithRoundedRect:rc cornerRadius:r];
    CGContextSaveGState(c);
    [clip addClip];
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGFloat comps[8] = { t[0], t[1], t[2], t[3], b[0], b[1], b[2], b[3] };
    CGFloat loc[2] = { 0.0f, 1.0f };
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, comps, loc, 2);
    CGContextDrawLinearGradient(c, g, CGPointMake(0, 0), CGPointMake(0, h), 0);
    CGGradientRelease(g);
    CGColorSpaceRelease(cs);
    CGContextSetRGBFillColor(c, 1, 1, 1, pressed ? gl * 0.5f : gl);
    CGContextFillRect(c, CGRectMake(0, 0, w, h / 2.0f));              /* połysk na górnej połowie */
    CGContextRestoreGState(c);
    if (border) {
        CGContextSetRGBStrokeColor(c, 1, 1, 1, 0.24f);
        [[UIBezierPath bezierPathWithRoundedRect:CGRectInset(rc, 1.5f, 1.5f) cornerRadius:MAX(0.0f, r - 1.0f)] stroke];
        CGContextSetRGBStrokeColor(c, 0.03f, 0.05f, 0.11f, 1);
        CGContextSetLineWidth(c, 2.0f);
        [[UIBezierPath bezierPathWithRoundedRect:CGRectInset(rc, 1.0f, 1.0f) cornerRadius:r] stroke];
    }
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    CGFloat cap = w / 2.0f - 0.5f;
    img = [img resizableImageWithCapInsets:UIEdgeInsetsMake(0, cap, 0, cap)];
    [cache setObject:img forKey:key];
    return img;
}

/* Ikona kalendarza (wybór momentu w archiwum): jednokolorowa, jak ikony paska narzędzi iOS 6, z dzisiejszym dniem. */
static UIImage *calendarIcon(void)
{
    CGFloat sz = 26.0f;
    NSInteger day = [[NSCalendar currentCalendar] components:NSDayCalendarUnit fromDate:[NSDate date]].day;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(sz, sz), NO, [[UIScreen mainScreen] scale]);
    CGContextRef c = UIGraphicsGetCurrentContext();
    UIBezierPath *shape = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(2, 4, 22, 20.6f) cornerRadius:4];
    [shape appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(7, 1, 3, 5.5f) cornerRadius:1.5f]];
    [shape appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(16, 1, 3, 5.5f) cornerRadius:1.5f]];
    shape.usesEvenOddFillRule = NO;
    CGContextSaveGState(c);                                       /* cień pod ikoną */
    CGContextTranslateCTM(c, 0, 1);
    CGContextSetRGBFillColor(c, 0, 0, 0, 0.85f);
    [shape fill];
    CGContextRestoreGState(c);
    CGContextSaveGState(c);                                       /* biały gradient */
    [shape addClip];
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGFloat comps[8] = { 0.99f, 0.99f, 1.0f, 1.0f, 0.67f, 0.69f, 0.75f, 1.0f };
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, comps, NULL, 2);
    CGContextDrawLinearGradient(c, g, CGPointMake(0, 1), CGPointMake(0, 25), 0);
    CGGradientRelease(g);
    CGColorSpaceRelease(cs);
    CGContextRestoreGState(c);
    CGContextSetBlendMode(c, kCGBlendModeClear);                  /* wycięcie: kreska pod nagłówkiem i numer dnia */
    CGContextFillRect(c, CGRectMake(2, 9.6f, 22, 0.9f));
    NSString *num = [NSString stringWithFormat:@"%d", (int)day];
    UIFont *f = [UIFont boldSystemFontOfSize:11.5f];
    CGSize ts = [num sizeWithFont:f];
    [num drawAtPoint:CGPointMake(13 - ts.width / 2.0f, 11.0f + (13.0f - ts.height) / 2.0f) withFont:f];
    UIImage *i = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return i;
}

/* Segment przycisku jak w UISegmentedControl: pos 0 lewy, 1 środkowy, 2 prawy (zaokrąglone tylko zewnętrzne rogi). */
static UIImage *segImage(int pos, BOOL pressed)
{
    static NSMutableDictionary *cache;
    if (!cache) cache = [[NSMutableDictionary alloc] init];
    NSString *key = [NSString stringWithFormat:@"%d-%d", pos, pressed];
    UIImage *hit = [cache objectForKey:key];
    if (hit) return hit;
    CGFloat t[4], b[4], gl, r = 6.0f, w = 2.0f * r + 4.0f, h = 30.0f;
    gsColors(GS_GRAY, t, b, &gl);
    if (pressed) for (int i = 0; i < 3; i++) { t[i] *= 0.7f; b[i] *= 0.7f; }
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(w, h), NO, [[UIScreen mainScreen] scale]);
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect rc = CGRectMake(0, 0, w, h);
    UIRectCorner corners = pos == 0 ? (UIRectCornerTopLeft | UIRectCornerBottomLeft) : (pos == 2 ? (UIRectCornerTopRight | UIRectCornerBottomRight) : (UIRectCorner)0);
    UIBezierPath *clip = [UIBezierPath bezierPathWithRoundedRect:rc byRoundingCorners:corners cornerRadii:CGSizeMake(r, r)];
    CGContextSaveGState(c);
    [clip addClip];
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGFloat comps[8] = { t[0], t[1], t[2], 1, b[0], b[1], b[2], 1 };
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, comps, NULL, 2);
    CGContextDrawLinearGradient(c, g, CGPointMake(0, 0), CGPointMake(0, h), 0);
    CGGradientRelease(g);
    CGColorSpaceRelease(cs);
    CGContextSetRGBFillColor(c, 1, 1, 1, pressed ? gl * 0.5f : gl);
    CGContextFillRect(c, CGRectMake(0, 0, w, h / 2.0f));
    CGContextRestoreGState(c);
    CGContextSetRGBStrokeColor(c, 0.03f, 0.05f, 0.11f, 1);
    CGContextSetLineWidth(c, 1.0f);
    [[UIBezierPath bezierPathWithRoundedRect:CGRectInset(rc, 0.5f, 0.5f) byRoundingCorners:corners cornerRadii:CGSizeMake(r, r)] stroke];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    CGFloat cap = w / 2.0f - 0.5f;
    img = [img resizableImageWithCapInsets:UIEdgeInsetsMake(0, cap, 0, cap)];
    [cache setObject:img forKey:key];
    return img;
}

/* Dolny pasek na telefonie: czarny, półprzezroczysty jak UIToolbar, z jasną linią u góry. */
static UIImage *toolbarImage(void)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(8, 112), NO, [[UIScreen mainScreen] scale]);
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGFloat comps[8] = { 0.235f, 0.243f, 0.263f, 0.94f, 0.047f, 0.047f, 0.059f, 0.97f };
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, comps, NULL, 2);
    CGContextDrawLinearGradient(c, g, CGPointMake(0, 0), CGPointMake(0, 112), 0);
    CGGradientRelease(g);
    CGColorSpaceRelease(cs);
    CGContextSetRGBFillColor(c, 0, 0, 0, 1);
    CGContextFillRect(c, CGRectMake(0, 0, 8, 1));
    CGContextSetRGBFillColor(c, 0.67f, 0.68f, 0.73f, 0.47f);
    CGContextFillRect(c, CGRectMake(0, 1, 8, 1));
    UIImage *i = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [i resizableImageWithCapInsets:UIEdgeInsetsMake(3, 3, 3, 3)];
}

/* Adres archiwum: ten sam adres kanału z dopiskiem utc=<początek>&lutc=<teraz> (serwer sam przelicza przesunięcie). */
static NSString *archiveURL(NSString *live, double start, double now)
{
    NSString *sep = [live rangeOfString:@"?"].location == NSNotFound ? @"?" : @"&";
    return [NSString stringWithFormat:@"%@%@utc=%lld&lutc=%lld", live, sep, (long long)start, (long long)now];
}

static NSString *dateTimeText(double t)
{
    static NSDateFormatter *f;
    if (!f) { f = [[NSDateFormatter alloc] init]; f.dateFormat = @"d.MM HH:mm"; }
    return [f stringFromDate:[NSDate dateWithTimeIntervalSince1970:t]];
}

@interface M3UPlayerController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) NSArray *entries;
@property (nonatomic, strong) M3UEntry *current;
@property (nonatomic, strong) MPMoviePlayerController *mp;
@property (nonatomic, strong) UIView *edgeL, *edgeR, *catcher, *listPanel, *epgPanel, *topBar, *bar, *touchLayer, *listEdge, *epgEdge, *dayStrip, *epgTool, *tabBox, *liveDot;
@property (nonatomic, strong) UITableView *listTable, *epgTable;
@property (nonatomic, strong) UILabel *epgHeader, *epgEmpty, *toast;
@property (nonatomic, strong) UILabel *barTitle, *barBadge, *barProg, *loLabel, *hiLabel, *knobLabel;
@property (nonatomic, strong) UISlider *slider;
@property (nonatomic, strong) UIImageView *topBg, *barBg;
@property (nonatomic, strong) UIButton *calBtn;
@property (nonatomic) NSInteger calDay;
@property (nonatomic, strong) UIButton *clockChip;           /* godzina w Moskwie (tylko kanały rosyjskie) */
@property (nonatomic, strong) MPVolumeView *routeView;       /* przycisk AirPlay (system pokazuje go tylko, gdy jest odbiornik) */
@property (nonatomic, strong) UIButton *closeButton, *backBtn, *fwdBtn, *playBtn, *liveBtn, *pickBtn;
@property (nonatomic, strong) NSArray *dayTabs;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) NSArray *epgRows;            /* program wybranego dnia */
@property (nonatomic) NSInteger dayIndex;                  /* 0 wczoraj, 1 dziś, 2 jutro */
@property (nonatomic) BOOL listOpen, epgOpen, overlayVisible, paused, archiveMode, dragging, pickerOpen;
@property (nonatomic) double posBase, baseWall, frozenPos, pausedWall, sLo, sHi;
@property (nonatomic) float sDown;                         /* wartość suwaka przy dotknięciu */
@property (nonatomic, strong) NSTimer *hideTimer, *tick;
@property (nonatomic, strong) UIView *pickerView;
@property (nonatomic, strong) UIDatePicker *picker;
@end

/* Kanał rosyjski: cyrylica w nazwie bez liter ukraińskich i białoruskich, albo grupa z nazwą Rosji. */
static BOOL isRussianChannel(M3UEntry *e)
{
    NSString *n = e.name ?: @"";
    BOOL cyr = NO;
    for (NSUInteger i = 0; i < [n length]; i++) {
        unichar c = [n characterAtIndex:i];
        if (c == 0x0456 || c == 0x0457 || c == 0x0454 || c == 0x0491 || c == 0x0406 || c == 0x0407 || c == 0x0404 || c == 0x0490 || c == 0x045E || c == 0x040E) return NO;
        if (c >= 0x0400 && c <= 0x04FF) cyr = YES;
    }
    if (cyr) return YES;
    NSString *g = [(e.group ?: @"") lowercaseString];
    return [g rangeOfString:@"росси"].location != NSNotFound || [g rangeOfString:@"russia"].location != NSNotFound || [g rangeOfString:@"rosja"].location != NSNotFound;
}

/* Czas w Moskwie: stałe UTC+3 (stare dane stref w iOS 6 nadal dodają Moskwie czas letni). */
static NSString *moscowTime(void)
{
    static NSDateFormatter *f;
    if (!f) { f = [[NSDateFormatter alloc] init]; f.dateFormat = @"HH:mm"; f.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:3 * 3600]; }
    return [f stringFromDate:[NSDate date]];
}

@implementation M3UPlayerController

M3U_ROTATE_ANY

- (id)initWithEntries:(NSArray *)entries current:(M3UEntry *)current
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.entries = entries;
        self.current = current;
        self.dayIndex = 1;
        self.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    return self;
}

- (void)dealloc
{
    [self.hideTimer invalidate];
    [self.tick invalidate];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (double)nowEpoch { return [[NSDate date] timeIntervalSince1970]; }

#pragma mark - Budowa widoku

- (UIView *)darkPanel
{
    UIView *p = [[UIView alloc] initWithFrame:CGRectZero];
    p.backgroundColor = [UIColor colorWithRed:0.055f green:0.07f blue:0.12f alpha:0.93f];
    p.hidden = YES;
    return p;
}

- (UIView *)edgeLineIn:(UIView *)panel
{
    UIView *l = [[UIView alloc] initWithFrame:CGRectZero];
    l.backgroundColor = [UIColor blackColor];
    UIView *h = [[UIView alloc] initWithFrame:CGRectZero];
    h.tag = 5;
    h.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.16f];
    [l addSubview:h];
    [panel addSubview:l];
    return l;
}

/* Pasek nagłówka jak UINavigationBar z iOS 6: stalowy gradient z połyskiem, tytuł z cieniem. */
- (UILabel *)headerIn:(UIView *)panel text:(NSString *)t
{
    UIImageView *bar = [[UIImageView alloc] initWithImage:glossImage(GS_NAV, 56.0f, 0, NO, NO)];
    bar.frame = CGRectMake(0, 0, 10, 56);
    bar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [panel addSubview:bar];
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 55, 10, 1)];
    line.backgroundColor = [UIColor colorWithRed:0.03f green:0.07f blue:0.16f alpha:1.0f];
    line.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [panel addSubview:line];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, 280, 56)];
    l.backgroundColor = [UIColor clearColor];
    l.textColor = [UIColor whiteColor];
    l.shadowColor = [UIColor colorWithWhite:0 alpha:0.75f];
    l.shadowOffset = CGSizeMake(0, -1);
    l.font = [UIFont boldSystemFontOfSize:21.0f];
    l.lineBreakMode = NSLineBreakByTruncatingTail;
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    l.text = t;
    [panel addSubview:l];
    return l;
}

- (UITableView *)tableIn:(UIView *)panel
{
    UITableView *t = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    t.backgroundColor = [UIColor clearColor];
    t.separatorColor = [UIColor blackColor];
    t.dataSource = self;
    t.delegate = self;
    t.rowHeight = kRow;
    [panel addSubview:t];
    return t;
}

- (UISwipeGestureRecognizer *)swipe:(UISwipeGestureRecognizerDirection)dir on:(UIView *)v action:(SEL)a
{
    UISwipeGestureRecognizer *g = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:a];
    g.direction = dir;
    [v addGestureRecognizer:g];
    return g;
}

/* Szklany przycisk w stylu iOS 6 (niebieski lub szary) o wysokości h. */
- (UIButton *)glossButton:(NSString *)title style:(int)st h:(CGFloat)h radius:(CGFloat)r border:(BOOL)border size:(CGFloat)size action:(SEL)a
{
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    [b setBackgroundImage:glossImage(st, h, r, border, NO) forState:UIControlStateNormal];
    [b setBackgroundImage:glossImage(st, h, r, border, YES) forState:UIControlStateHighlighted];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:size];
    b.titleLabel.shadowOffset = CGSizeMake(0, -1);
    [b setTitleShadowColor:[UIColor colorWithWhite:0 alpha:0.6f] forState:UIControlStateNormal];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [b addTarget:self action:a forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (UILabel *)smallLabel:(CGFloat)size color:(UIColor *)c align:(NSTextAlignment)al
{
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectZero];
    l.backgroundColor = [UIColor clearColor];
    l.textColor = c;
    l.font = [UIFont systemFontOfSize:size];
    l.textAlignment = al;
    l.lineBreakMode = NSLineBreakByTruncatingTail;
    return l;
}

- (UIImageView *)stripImage:(int)st h:(CGFloat)h
{
    UIImageView *v = [[UIImageView alloc] initWithImage:glossImage(st, h, 0, NO, NO)];
    return v;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    MPMoviePlayerController *mp = [[MPMoviePlayerController alloc] init];
    mp.controlStyle = MPMovieControlStyleNone;
    mp.movieSourceType = MPMovieSourceTypeStreaming;
    mp.scalingMode = MPMovieScalingModeAspectFit;
    mp.view.backgroundColor = [UIColor blackColor];
    mp.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    mp.view.frame = self.view.bounds;
    [self.view addSubview:mp.view];
    self.mp = mp;

    /* warstwa dotyku nad obrazem: odtwarzacz sam połyka dotknięcia, więc nasłuchujemy tutaj */
    self.touchLayer = [[UIView alloc] initWithFrame:self.view.bounds];
    self.touchLayer.backgroundColor = [UIColor clearColor];
    self.touchLayer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.touchLayer addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(videoTapped)]];
    [self swipe:UISwipeGestureRecognizerDirectionUp on:self.touchLayer action:@selector(nextChannel)];
    [self swipe:UISwipeGestureRecognizerDirectionDown on:self.touchLayer action:@selector(prevChannel)];
    [self.view addSubview:self.touchLayer];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.spinner.hidesWhenStopped = YES;
    self.spinner.userInteractionEnabled = NO;
    [self.view addSubview:self.spinner];

    /* paski przy krawędziach: od nich zaczyna się przesunięcie (w poziomie) */
    self.edgeR = [[UIView alloc] initWithFrame:CGRectZero];
    [self swipe:UISwipeGestureRecognizerDirectionLeft on:self.edgeR action:@selector(openList)];
    [self.view addSubview:self.edgeR];
    self.edgeL = [[UIView alloc] initWithFrame:CGRectZero];
    [self swipe:UISwipeGestureRecognizerDirectionRight on:self.edgeL action:@selector(openEpg)];
    [self.view addSubview:self.edgeL];

    /* przyciemnienie: dotknięcie poza panelem go zamyka */
    self.catcher = [[UIView alloc] initWithFrame:CGRectZero];
    self.catcher.backgroundColor = [UIColor colorWithWhite:0 alpha:0.30f];
    self.catcher.hidden = YES;
    [self.catcher addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closePanels)]];
    [self.view addSubview:self.catcher];

    /* lista kanałów (z prawej) */
    self.listPanel = [self darkPanel];
    [self headerIn:self.listPanel text:L(@"Kanały")];
    self.listTable = [self tableIn:self.listPanel];
    self.listEdge = [self edgeLineIn:self.listPanel];
    [self swipe:UISwipeGestureRecognizerDirectionRight on:self.listPanel action:@selector(closePanels)];
    [self.view addSubview:self.listPanel];

    /* program i archiwum (z lewej) */
    self.epgPanel = [self darkPanel];
    self.epgTable = [self tableIn:self.epgPanel];
    self.dayStrip = [self stripImage:GS_STRIP h:48.0f];
    [self.epgPanel addSubview:self.dayStrip];
    self.epgHeader = [self headerIn:self.epgPanel text:L(@"Program")];
    self.tabBox = [[UIView alloc] initWithFrame:CGRectZero];
    self.tabBox.layer.cornerRadius = 7.0f;
    self.tabBox.layer.borderWidth = 2.0f;
    self.tabBox.layer.borderColor = [UIColor colorWithRed:0.03f green:0.05f blue:0.11f alpha:1.0f].CGColor;
    self.tabBox.clipsToBounds = YES;
    self.tabBox.backgroundColor = [UIColor blackColor];
    [self.epgPanel addSubview:self.tabBox];
    NSMutableArray *tabs = [NSMutableArray array];
    NSArray *tn = [NSArray arrayWithObjects:L(@"Wczoraj"), L(@"Dziś"), L(@"Jutro"), nil];
    for (NSInteger i = 0; i < 3; i++) {
        UIButton *b = [self glossButton:[tn objectAtIndex:(NSUInteger)i] style:GS_GRAY h:26.0f radius:0 border:NO size:15.0f action:@selector(dayTapped:)];
        b.tag = i;
        [self.tabBox addSubview:b];
        [tabs addObject:b];
    }
    self.dayTabs = tabs;
    self.epgEmpty = [self smallLabel:16.0f color:M3USubtleColor() align:NSTextAlignmentCenter];
    self.epgEmpty.numberOfLines = 0;
    self.epgEmpty.text = L(@"Brak programu dla tego kanału.");
    [self.epgPanel addSubview:self.epgEmpty];
    self.epgTool = [self stripImage:GS_TOOL h:68.0f];
    [self.epgPanel addSubview:self.epgTool];
    self.pickBtn = [self glossButton:L(@"Wybierz dzień i godzinę") style:GS_GRAY h:46.0f radius:9.0f border:YES size:17.0f action:@selector(showPicker)];
    [self.epgPanel addSubview:self.pickBtn];
    self.epgEdge = [self edgeLineIn:self.epgPanel];
    [self swipe:UISwipeGestureRecognizerDirectionLeft on:self.epgPanel action:@selector(closePanels)];
    [self.view addSubview:self.epgPanel];

    /* górny pasek: Zamknij, nazwa kanału, NA ŻYWO z migającą kropką / ARCHIWUM */
    self.topBar = [[UIView alloc] initWithFrame:CGRectZero];
    self.topBg = [self stripImage:GS_DARK h:isPhone() ? 44.0f : 48.0f];
    self.topBg.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.topBar addSubview:self.topBg];
    self.closeButton = [self glossButton:L(@"Zamknij") style:GS_BLUE h:isPhone() ? 30.0f : 32.0f radius:7.0f border:YES size:isPhone() ? 13.0f : 15.0f action:@selector(closePlayer)];
    [self.topBar addSubview:self.closeButton];
    self.barTitle = [self smallLabel:19.0f color:[UIColor whiteColor] align:NSTextAlignmentLeft];
    self.barTitle.font = [UIFont boldSystemFontOfSize:19.0f];
    self.barTitle.shadowColor = [UIColor colorWithWhite:0 alpha:0.8f];
    self.barTitle.shadowOffset = CGSizeMake(0, -1);
    [self.topBar addSubview:self.barTitle];
    self.liveDot = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    self.liveDot.backgroundColor = [UIColor colorWithRed:1.0f green:0.12f blue:0.10f alpha:1.0f];
    self.liveDot.layer.cornerRadius = 5.0f;
    self.liveDot.layer.shadowColor = [UIColor redColor].CGColor;
    self.liveDot.layer.shadowOpacity = 1.0f;
    self.liveDot.layer.shadowRadius = 4.0f;
    self.liveDot.layer.shadowOffset = CGSizeZero;
    [self.topBar addSubview:self.liveDot];
    self.barBadge = [self smallLabel:14.0f color:[UIColor whiteColor] align:NSTextAlignmentCenter];
    self.barBadge.font = [UIFont boldSystemFontOfSize:14.0f];
    self.barBadge.layer.cornerRadius = 6.0f;
    self.barBadge.clipsToBounds = YES;
    [self.topBar addSubview:self.barBadge];
    [self.view addSubview:self.topBar];

    /* dolny pasek: audycja, oś czasu, przyciski */
    self.bar = [[UIView alloc] initWithFrame:CGRectZero];
    self.barBg = isPhone() ? [[UIImageView alloc] initWithImage:toolbarImage()] : [self stripImage:GS_DARK h:132.0f];     /* rozciągany do wysokości paska */
    self.barBg.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.bar addSubview:self.barBg];
    self.barProg = [self smallLabel:15.0f color:[UIColor whiteColor] align:NSTextAlignmentLeft];
    self.barProg.font = [UIFont boldSystemFontOfSize:15.0f];
    self.barProg.shadowColor = [UIColor colorWithWhite:0 alpha:0.8f];
    self.barProg.shadowOffset = CGSizeMake(0, -1);
    self.loLabel = [self smallLabel:14.0f color:M3USubtleColor() align:NSTextAlignmentLeft];
    self.hiLabel = [self smallLabel:14.0f color:M3USubtleColor() align:NSTextAlignmentRight];
    self.knobLabel = [self smallLabel:12.0f color:[UIColor whiteColor] align:NSTextAlignmentCenter];
    self.knobLabel.font = [UIFont boldSystemFontOfSize:12.0f];
    self.knobLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8f];
    self.knobLabel.layer.cornerRadius = 5.0f;
    self.knobLabel.layer.borderWidth = 1.0f;
    self.knobLabel.layer.borderColor = [UIColor colorWithWhite:1.0f alpha:0.35f].CGColor;
    self.slider = [[UISlider alloc] initWithFrame:CGRectZero];
    self.slider.minimumValue = 0.0f;
    self.slider.maximumValue = 1.0f;
    [self.slider addTarget:self action:@selector(sliderDown) forControlEvents:UIControlEventTouchDown];
    [self.slider addTarget:self action:@selector(sliderMoved) forControlEvents:UIControlEventValueChanged];
    [self.slider addTarget:self action:@selector(sliderUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    CGFloat bhh = isPhone() ? 30.0f : 40.0f, bfs = isPhone() ? 12.0f : 15.0f, brd = isPhone() ? 6.0f : 8.0f;
    self.backBtn = [self glossButton:L(@"-10 min") style:GS_GRAY h:bhh radius:8.0f border:YES size:bfs action:@selector(skipBack)];
    self.fwdBtn = [self glossButton:L(@"+10 min") style:GS_GRAY h:bhh radius:8.0f border:YES size:bfs action:@selector(skipForward)];
    self.liveBtn = [self glossButton:L(@"Na żywo") style:GS_BLUE h:bhh radius:brd border:YES size:bfs action:@selector(goLive)];
    self.playBtn = [self glossButton:nil style:GS_GRAY h:bhh radius:8.0f border:YES size:bfs action:@selector(togglePause)];
    [self.playBtn setImage:playIcon(YES) forState:UIControlStateNormal];
    self.calBtn = [self glossButton:nil style:GS_GRAY h:bhh radius:8.0f border:YES size:bfs action:@selector(showPicker)];   /* telefon: wybór momentu w archiwum */
    [self.calBtn setImage:calendarIcon() forState:UIControlStateNormal];
    self.calBtn.hidden = !isPhone();
    if (isPhone()) {                                              /* segmentowy przycisk -10 | pauza | +10 i kalendarz bez ramki, jak w UIKit */
        UIButton *segs[3] = { self.backBtn, self.playBtn, self.fwdBtn };
        for (int k = 0; k < 3; k++) {
            [segs[k] setBackgroundImage:segImage(k, NO) forState:UIControlStateNormal];
            [segs[k] setBackgroundImage:segImage(k, YES) forState:UIControlStateHighlighted];
        }
        [self.calBtn setBackgroundImage:nil forState:UIControlStateNormal];
        [self.calBtn setBackgroundImage:nil forState:UIControlStateHighlighted];
    }
    if (M3UThemeIndex() != 0) {
        CGFloat ta[4], tb[4];
        M3UPlayerPalette(1, ta, tb);
        self.slider.minimumTrackTintColor = [UIColor colorWithRed:ta[0] green:ta[1] blue:ta[2] alpha:1.0f];
    }
    for (UIView *v in [NSArray arrayWithObjects:self.barProg, self.loLabel, self.hiLabel, self.slider, self.knobLabel, self.backBtn, self.playBtn, self.fwdBtn, self.calBtn, self.liveBtn, nil])
        [self.bar addSubview:v];
    [self.view addSubview:self.bar];

    self.clockChip = [self glossButton:@"" style:GS_GRAY h:30.0f radius:8.0f border:YES size:13.0f action:@selector(noop)];
    self.clockChip.userInteractionEnabled = NO;
    self.clockChip.hidden = YES;
    [self.view addSubview:self.clockChip];
    mp.allowsAirPlay = YES;
    self.routeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(0, 0, 50, 30)];
    self.routeView.showsVolumeSlider = NO;
    self.routeView.showsRouteButton = YES;
    [self.view addSubview:self.routeView];

    self.toast = [self smallLabel:16.0f color:M3UTextColor() align:NSTextAlignmentCenter];
    self.toast.backgroundColor = [UIColor colorWithWhite:0 alpha:0.75f];
    self.toast.numberOfLines = 2;
    self.toast.layer.cornerRadius = 10.0f;
    self.toast.clipsToBounds = YES;
    self.toast.hidden = YES;
    [self.view addSubview:self.toast];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(playbackFinished:) name:MPMoviePlayerPlaybackDidFinishNotification object:mp];
    [nc addObserver:self selector:@selector(loadStateChanged:) name:MPMoviePlayerLoadStateDidChangeNotification object:mp];
    [nc addObserver:self selector:@selector(logoLoaded) name:M3ULogoDidLoad object:nil];
    [nc addObserver:self selector:@selector(epgUpdated) name:M3UEpgDidUpdate object:nil];
    [nc addObserver:self selector:@selector(updateLiveDot) name:UIApplicationDidBecomeActiveNotification object:nil];

    self.overlayVisible = YES;
    [self playLive];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];
    [self.tick invalidate];
    self.tick = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(tickFired) userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.hideTimer invalidate];
    self.hideTimer = nil;
    [self.tick invalidate];
    self.tick = nil;
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationNone];
}

#pragma mark - Układ

- (BOOL)isLandscape { return !isPhone() && self.view.bounds.size.width > self.view.bounds.size.height; }       /* panele boczne tylko na iPadzie w poziomie */

- (CGFloat)panelWidth { return MIN(340.0f, (CGFloat)(int)(self.view.bounds.size.width * 0.42f)); }

- (void)layoutBar
{
    CGRect b = self.view.bounds;
    CGFloat w = b.size.width;
    BOOL phone = isPhone(), portrait = b.size.width < b.size.height;
    CGFloat topH = phone ? 44.0f : 48.0f, bh = phone ? (portrait ? 112.0f : 100.0f) : 132.0f;
    /* górny pasek na całą szerokość */
    self.topBar.frame = CGRectMake(0, 0, w, topH);
    {   /* godzina kanału i AirPlay: prawy górny róg obrazu, pod górnym paskiem */
        CGFloat cy0 = topH + 8.0f, cwid = phone ? 104.0f : 120.0f, rx = w - 8.0f;
        self.clockChip.titleLabel.font = [UIFont boldSystemFontOfSize:phone ? 13.0f : 15.0f];
        if (!self.clockChip.hidden) { self.clockChip.frame = CGRectMake(rx - cwid, cy0, cwid, 30); rx -= cwid + 8.0f; }
        self.routeView.frame = CGRectMake(rx - 50.0f, cy0, 50, 30);
    }
    self.topBg.frame = self.topBar.bounds;
    self.closeButton.frame = phone ? CGRectMake(6, 7, 66, 30) : CGRectMake(8, 8, 92, 32);
    BOOL live = !self.archiveMode;
    CGFloat leftEdge = phone ? 82.0f : 112.0f;
    CGSize ts = [self.barTitle.text ?: @"" sizeWithFont:self.barTitle.font];
    CGFloat dotW = live ? 18.0f : 0.0f, badgeW = phone ? 84.0f : 96.0f;
    CGFloat availT = w - leftEdge - 12.0f - dotW - badgeW - 8.0f;
    CGFloat tw = MAX(40.0f, MIN(ts.width, MIN(availT, w * 0.38f + (phone ? 40.0f : 0.0f))));
    CGFloat groupW = tw + 12.0f + dotW + badgeW;
    CGFloat x0 = MAX(leftEdge, (CGFloat)(int)((w - groupW) / 2.0f));
    self.barTitle.frame = CGRectMake(x0, phone ? 9 : 11, tw, 26);
    self.liveDot.frame = CGRectMake(x0 + tw + 12.0f, topH / 2.0f - 5.0f, 10, 10);
    self.barBadge.frame = CGRectMake(x0 + tw + 12.0f + dotW, topH / 2.0f - 10.0f, badgeW, 20);
    self.barBadge.font = [UIFont boldSystemFontOfSize:phone ? 12.0f : 14.0f];
    self.barTitle.font = [UIFont boldSystemFontOfSize:phone ? 16.0f : 19.0f];
    /* dolny pasek na całą szerokość */
    self.bar.frame = CGRectMake(0, b.size.height - bh, w, bh);
    self.barBg.frame = self.bar.bounds;
    CGFloat sideM = phone ? 44.0f : 74.0f, cy = phone ? 42.0f : 60.0f, bt = phone ? bh - 41.0f : 86.0f, bhh = phone ? 30.0f : 40.0f;
    self.barProg.frame = CGRectMake(phone ? 12 : 18, phone ? 6 : 8, w - (phone ? 24 : 36), 20);
    self.loLabel.frame = CGRectMake(phone ? 6 : 14, cy - 10.0f, sideM - 6.0f, 20);
    self.hiLabel.frame = CGRectMake(w - sideM, cy - 10.0f, sideM - 6.0f, 20);
    self.slider.frame = CGRectMake(sideM, cy - 15.0f, w - 2.0f * sideM, 30);
    CGFloat bw[5], gp[5];
    gp[0] = 0; gp[1] = 0; gp[2] = 0; gp[3] = 0; gp[4] = 0;
    NSArray *btns;
    if (phone) {
        CGFloat pw[5] = { 60, 66, 60, 40, 64 }, lw[5] = { 76, 84, 76, 44, 84 };
        for (int i = 0; i < 5; i++) bw[i] = portrait ? pw[i] : lw[i];
        gp[0] = -1.0f; gp[1] = -1.0f; gp[2] = portrait ? 10.0f : 16.0f; gp[3] = portrait ? 8.0f : 16.0f;      /* trzy segmenty stykają się */
        btns = [NSArray arrayWithObjects:self.backBtn, self.playBtn, self.fwdBtn, self.calBtn, self.liveBtn, nil];
    } else {
        gp[0] = 12.0f; gp[1] = 12.0f; gp[2] = 12.0f; gp[3] = 12.0f;                  /* (bez pętli: kompilator zamieniłby ją na memset_pattern16, którego nie ma w iOS 6) */
        bw[0] = 82; bw[1] = 90; bw[2] = 82; bw[3] = 110; bw[4] = 0;
        btns = [NSArray arrayWithObjects:self.backBtn, self.playBtn, self.fwdBtn, self.liveBtn, nil];
    }
    NSUInteger n = [btns count];
    CGFloat total = 0;
    for (NSUInteger i = 0; i < n; i++) total += bw[i] + (i + 1 < n ? gp[i] : 0);
    CGFloat x = (CGFloat)(int)((w - total) / 2.0f), bt0 = bt;
    for (NSUInteger i = 0; i < n; i++) {
        UIButton *bt = [btns objectAtIndex:i];
        bt.frame = CGRectMake(x, bt0, bw[i], bhh);
        x += bw[i] + gp[i];
    }
}

- (void)layoutPanelsAnimated:(BOOL)animated
{
    CGRect b = self.view.bounds;
    CGFloat pw = [self panelWidth];
    BOOL land = [self isLandscape];
    if (!land) { self.listOpen = NO; self.epgOpen = NO; }
    self.edgeR.frame = CGRectMake(b.size.width - kEdge, 0, kEdge, b.size.height);
    self.edgeL.frame = CGRectMake(0, 0, kEdge, b.size.height);
    self.edgeR.hidden = self.edgeL.hidden = !land;
    CGRect listOn = CGRectMake(b.size.width - pw, 0, pw, b.size.height), listOff = CGRectMake(b.size.width, 0, pw, b.size.height);
    CGRect epgOn = CGRectMake(0, 0, pw, b.size.height), epgOff = CGRectMake(-pw, 0, pw, b.size.height);
    self.catcher.frame = b;
    self.listPanel.hidden = NO;
    self.epgPanel.hidden = NO;
    void (^apply)(void) = ^{
        self.listPanel.frame = self.listOpen ? listOn : listOff;
        self.epgPanel.frame = self.epgOpen ? epgOn : epgOff;
    };
    void (^done)(BOOL) = ^(BOOL f) {
        self.listPanel.hidden = !self.listOpen;
        self.epgPanel.hidden = !self.epgOpen;
    };
    self.catcher.hidden = !(self.listOpen || self.epgOpen);
    if (animated) [UIView animateWithDuration:0.25 animations:apply completion:done];
    else { apply(); done(YES); }

    self.listTable.frame = CGRectMake(0, 56, pw, b.size.height - 56);
    self.listEdge.frame = CGRectMake(0, 0, 1, b.size.height);
    self.epgEdge.frame = CGRectMake(pw - 1.0f, 0, 1, b.size.height);
    [self.listEdge viewWithTag:5].frame = CGRectMake(1, 0, 1, b.size.height);
    [self.epgEdge viewWithTag:5].frame = CGRectMake(-1, 0, 1, b.size.height);
    self.dayStrip.frame = CGRectMake(0, 56, pw, 48);
    CGFloat boxW = pw - 28.0f, segW = (CGFloat)(int)((boxW - 4.0f) / 3.0f);
    self.tabBox.frame = CGRectMake(14, 66, boxW, 30);
    CGFloat inner = boxW - 4.0f;
    for (UIButton *t in self.dayTabs) t.frame = CGRectMake(t.tag * segW, 0, t.tag == 2 ? inner - 2.0f * segW : segW - 1.0f, 26);
    self.epgTable.frame = CGRectMake(0, 104, pw, b.size.height - 104 - 68);
    self.epgEmpty.frame = CGRectMake(20, 140, pw - 40, 60);
    self.epgTool.frame = CGRectMake(0, b.size.height - 68, pw, 68);
    self.pickBtn.frame = CGRectMake(12, b.size.height - 57, pw - 24, 46);
    [self layoutBar];
    self.spinner.center = CGPointMake(b.size.width / 2.0f, b.size.height / 2.0f);
    if (self.pickerView) self.pickerView.center = CGPointMake(b.size.width / 2.0f, b.size.height / 2.0f);
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self layoutPanelsAnimated:NO];
}

#pragma mark - Odtwarzanie: na żywo i archiwum

- (void)loadURL:(NSString *)s
{
    NSURL *u = [NSURL URLWithString:s];
    NSString *scheme = [[u scheme] lowercaseString];
    if (!u || !([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"])) {
        [self showToast:[NSString stringWithFormat:L(@"iOS 6 odtworzy tylko strumienie HLS przez http lub https. Ten kanał używa „%@”."), scheme ?: @"?"]];
        return;
    }
    [self.mp stop];
    self.mp.contentURL = u;
    [self.spinner startAnimating];
    [self.mp prepareToPlay];
    [self.mp play];
}

/* Kanał na żywo. */
- (void)playLive
{
    self.archiveMode = NO;
    self.paused = NO;
    [self refreshAll];
    [self.listTable reloadData];
    [self scrollListToCurrent];
    [self loadURL:self.current.url];
    [self showOverlay];
}

/* Archiwum od podanej chwili (sekundy UTC). Gdy chwila jest prawie „teraz”, odtwarzamy na żywo. */
- (void)playArchiveFrom:(double)t
{
    double now = [self nowEpoch];
    if (t > now - kLiveGap) { [self playLive]; return; }
    if (t < now - kArchiveDepth) t = now - kArchiveDepth;
    self.archiveMode = YES;
    self.paused = NO;
    self.posBase = t;
    self.baseWall = now;
    [self refreshAll];
    [self loadURL:archiveURL(self.current.url, t, now)];
    [self showOverlay];
}

/* Która chwila jest teraz na ekranie. */
- (double)position
{
    double now = [self nowEpoch];
    if (self.paused) return self.frozenPos;
    return self.archiveMode ? self.posBase + (now - self.baseWall) : now;
}

- (void)togglePause
{
    double now = [self nowEpoch];
    if (!self.paused) {
        self.frozenPos = [self position];
        self.paused = YES;
        self.pausedWall = now;
        [self.mp pause];
    } else if (now - self.pausedWall < 8.0) {            /* krótka pauza: po prostu dalej */
        self.paused = NO;
        if (self.archiveMode) { self.posBase = self.frozenPos; self.baseWall = now; }
        [self.mp play];
    } else {                                             /* długa pauza: okno strumienia już minęło - wracamy do miejsca pauzy z archiwum */
        double p = self.frozenPos;
        self.paused = NO;
        [self playArchiveFrom:p];
    }
    [self refreshAll];
    [self showOverlay];
}

- (void)skipBack { [self playArchiveFrom:[self position] - 600.0]; }

- (void)skipForward
{
    if (!self.archiveMode) return;
    [self playArchiveFrom:[self position] + 600.0];
}

- (void)goLive { if (self.archiveMode || self.paused) [self playLive]; }

- (void)loadStateChanged:(NSNotification *)n
{
    if (self.mp.loadState & (MPMovieLoadStatePlayable | MPMovieLoadStatePlaythroughOK)) [self.spinner stopAnimating];
}

- (void)playbackFinished:(NSNotification *)n
{
    NSNumber *reason = [[n userInfo] objectForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey];
    if ([reason intValue] != MPMovieFinishReasonPlaybackError) return;
    [self.spinner stopAnimating];
    if (self.archiveMode) {
        [self showToast:L(@"Archiwum jest niedostępne dla tego kanału lub momentu. Wracam na żywo.")];
        [self playLive];
    } else {
        [self showToast:isPhone() ? L(@"Nie udało się odtworzyć kanału. Przesuń palcem w górę lub w dół, aby wybrać inny.")
                                  : L(@"Nie udało się odtworzyć kanału. Wybierz inny z listy (przesuń palcem od prawej krawędzi).")];
    }
}

- (void)closePlayer
{
    [self.mp stop];
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Zmiana kanału przesunięciem w górę i w dół

- (void)stepChannel:(NSInteger)d
{
    if ([self.entries count] < 2 || self.listOpen || self.epgOpen || self.pickerOpen) return;
    NSUInteger i = [self.entries indexOfObjectPassingTest:^BOOL(M3UEntry *e, NSUInteger k, BOOL *stop) { return [e.url isEqualToString:self.current.url]; }];
    if (i == NSNotFound) i = 0;
    NSInteger n = (NSInteger)[self.entries count];
    NSInteger j = (((NSInteger)i + d) % n + n) % n;
    self.current = [self.entries objectAtIndex:(NSUInteger)j];
    [self playLive];
}

- (void)nextChannel { [self stepChannel:1]; }
- (void)prevChannel { [self stepChannel:-1]; }

#pragma mark - Pasek: oś czasu, etykiety, przyciski

/* Zakres osi czasu dla chwili pos: trwająca audycja, a gdy programu nie ma - ostatnie 2 godziny do „teraz”. */
- (void)rangeFor:(double)pos lo:(double *)lo hi:(double *)hi prog:(NSDictionary **)prog
{
    double now = [self nowEpoch];
    NSDictionary *ep = M3UEpgEnabled() ? M3UEpgAt(self.current.name, pos) : nil;
    if (ep) {
        *lo = [[ep objectForKey:@"start"] doubleValue];
        *hi = [[ep objectForKey:@"end"] doubleValue];
        *prog = ep;
    } else {
        *lo = now - 7200.0;
        if (pos < *lo) *lo = pos - 600.0;
        *hi = now;
        *prog = nil;
    }
    if (*hi <= *lo) *hi = *lo + 1.0;
}

- (void)refreshAll
{
    self.barTitle.text = self.current.name;
    if ([self.current.url length]) [[NSUserDefaults standardUserDefaults] setObject:self.current.url forKey:@"last_channel_url"];
    [self updateClock];
    BOOL live = !self.archiveMode;
    self.barBadge.text = live ? L(@"NA ŻYWO") : L(@"ARCHIWUM");
    self.barBadge.backgroundColor = live ? [UIColor colorWithRed:0.16f green:0.40f blue:0.86f alpha:1.0f] : [UIColor colorWithRed:0.78f green:0.31f blue:0.16f alpha:1.0f];
    self.liveDot.hidden = !live;
    [self updateLiveDot];
    [self.playBtn setImage:playIcon(!self.paused) forState:UIControlStateNormal];
    self.fwdBtn.alpha = self.archiveMode ? 1.0f : 0.4f;
    self.liveBtn.alpha = (self.archiveMode || self.paused) ? 1.0f : 0.4f;
    [self layoutBar];
    [self reloadEpgPanel];
    [self updateTimeline];
}

/* Czerwona kropka przy NA ŻYWO miga; animacje znikają po wyjściu z aplikacji, więc dokładamy ją na nowo. */
- (void)updateLiveDot
{
    if (self.archiveMode) { [self.liveDot.layer removeAnimationForKey:@"blink"]; return; }
    if ([self.liveDot.layer animationForKey:@"blink"]) return;
    CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"opacity"];
    a.fromValue = [NSNumber numberWithFloat:1.0f];
    a.toValue = [NSNumber numberWithFloat:0.15f];
    a.duration = 0.7;
    a.autoreverses = YES;
    a.repeatCount = HUGE_VALF;
    [self.liveDot.layer addAnimation:a forKey:@"blink"];
}

- (void)updateTimeline
{
    double pos = [self position], lo, hi;
    NSDictionary *prog;
    if (!self.dragging) {
        [self rangeFor:pos lo:&lo hi:&hi prog:&prog];
        self.sLo = lo;
        self.sHi = hi;
    } else {
        lo = self.sLo; hi = self.sHi; prog = nil;
    }
    self.loLabel.text = M3UEpgClock(lo);
    self.hiLabel.text = M3UEpgClock(hi);
    if (!self.dragging) {
        float v = (float)((pos - lo) / (hi - lo));
        self.slider.value = MIN(1.0f, MAX(0.0f, v));
        NSString *pt = nil;
        if (prog) pt = [NSString stringWithFormat:@"%@  %@–%@", [prog objectForKey:@"title"], M3UEpgClock(lo), M3UEpgClock(hi)];
        else if (self.archiveMode) pt = dateTimeText(pos);
        self.barProg.text = pt;
    }
    [self updateKnobLabel:pos];
}

- (void)updateKnobLabel:(double)pos
{
    BOOL phone = isPhone();
    self.knobLabel.text = (phone && self.dragging) ? dateTimeText(pos) : M3UEpgClock(pos);
    CGFloat kw = (phone && self.dragging) ? 86.0f : 56.0f;
    CGRect tr = [self.slider trackRectForBounds:self.slider.bounds];
    CGRect th = [self.slider thumbRectForBounds:self.slider.bounds trackRect:tr value:self.slider.value];
    CGFloat cx = self.slider.frame.origin.x + CGRectGetMidX(th);
    cx = MAX(kw / 2.0f + 2.0f, MIN(self.bar.bounds.size.width - kw / 2.0f - 2.0f, cx));
    self.knobLabel.frame = CGRectMake(cx - kw / 2.0f, phone ? 7.0f : 27.0f, kw, 17);
    self.knobLabel.hidden = phone && !self.dragging;           /* na telefonie etykieta gałki tylko przy przeciąganiu (nie zasłania tytułu audycji) */
}

- (void)sliderDown { self.dragging = YES; self.sDown = self.slider.value; [self.hideTimer invalidate]; self.barProg.hidden = isPhone(); }

- (void)sliderMoved
{
    double t = self.sLo + (self.sHi - self.sLo) * self.slider.value;
    [self updateKnobLabel:t];
    self.barProg.text = dateTimeText(t);
}

- (void)sliderUp
{
    double t = self.sLo + (self.sHi - self.sLo) * self.slider.value;
    self.dragging = NO;
    self.barProg.hidden = NO;
    if (fabsf(self.slider.value - self.sDown) < 0.004f) { [self showOverlay]; return; }      /* samo dotknięcie nic nie zmienia */
    [self playArchiveFrom:t];                      /* blisko „teraz” przechodzi na żywo */
}

- (void)noop {}

/* Znaczek z godziną w Moskwie: tylko dla kanałów rosyjskich. */
- (void)updateClock
{
    NSInteger today = [[NSCalendar currentCalendar] components:NSDayCalendarUnit fromDate:[NSDate date]].day;
    if (today != self.calDay) { self.calDay = today; [self.calBtn setImage:calendarIcon() forState:UIControlStateNormal]; }
    BOOL show = self.current && isRussianChannel(self.current);
    self.clockChip.hidden = !show;
    if (show) [self.clockChip setTitle:[NSString stringWithFormat:@"%@  %@", L(@"Moskwa"), moscowTime()] forState:UIControlStateNormal];
}

- (void)tickFired
{
    [self updateClock];
    [self updateTimeline];
    [self updateLiveDot];
    if (!self.archiveMode || self.paused) return;
    /* archiwum dogoniło „teraz” - to już transmisja na żywo */
    if ([self position] > [self nowEpoch] - 5.0) [self playLive];
}

#pragma mark - Nakładka (zamknij, pasek)

- (void)setOverlayAlpha:(CGFloat)a
{
    self.topBar.alpha = a;
    self.bar.alpha = a;
    self.clockChip.alpha = a;
    self.routeView.alpha = a;
    self.routeView.userInteractionEnabled = (a > 0.5f);
    self.topBar.userInteractionEnabled = (a > 0.5f);
    self.bar.userInteractionEnabled = (a > 0.5f);
}

- (void)showOverlay
{
    [self.hideTimer invalidate];
    self.overlayVisible = YES;
    [UIView animateWithDuration:0.2 animations:^{ [self setOverlayAlpha:1.0f]; }];
    self.hideTimer = [NSTimer scheduledTimerWithTimeInterval:6.0 target:self selector:@selector(hideOverlay) userInfo:nil repeats:NO];
}

- (void)hideOverlay
{
    if (self.dragging || self.paused || self.pickerOpen) return;      /* przy pauzie pasek zostaje */
    self.overlayVisible = NO;
    [UIView animateWithDuration:0.3 animations:^{ [self setOverlayAlpha:0.0f]; }];
}

- (void)videoTapped
{
    if (self.listOpen || self.epgOpen || self.pickerOpen) return;
    if (self.overlayVisible && !self.paused) { [self.hideTimer invalidate]; [self hideOverlay]; } else [self showOverlay];
}

- (void)showToast:(NSString *)t
{
    self.toast.text = t;
    CGRect b = self.view.bounds;
    CGFloat w = MIN(460.0f, b.size.width - 60.0f);
    self.toast.frame = CGRectMake((b.size.width - w) / 2.0f, b.size.height / 2.0f + 50.0f, w, 56);
    self.toast.hidden = NO;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideToast) object:nil];
    [self performSelector:@selector(hideToast) withObject:nil afterDelay:3.5];
}

- (void)hideToast { self.toast.hidden = YES; }

#pragma mark - Panele

- (void)hideBarForPanel
{
    [self.hideTimer invalidate];
    BOOL wasPaused = self.paused;
    self.paused = NO;                       /* hideOverlay przy pauzie nie chowa paska - tu chcemy schować mimo to */
    [self hideOverlay];
    self.paused = wasPaused;
    self.overlayVisible = NO;
    [UIView animateWithDuration:0.3 animations:^{ [self setOverlayAlpha:0.0f]; }];
}

- (void)openList
{
    if (![self isLandscape] || self.pickerOpen) return;
    self.epgOpen = NO;
    self.listOpen = YES;
    [self hideBarForPanel];
    [self.listTable reloadData];
    [self scrollListToCurrent];
    [self layoutPanelsAnimated:YES];
}

- (void)openEpg
{
    if (![self isLandscape] || self.pickerOpen) return;
    self.dayIndex = 1;
    [self reloadEpgPanel];
    self.listOpen = NO;
    self.epgOpen = YES;
    [self hideBarForPanel];
    [self layoutPanelsAnimated:YES];
    [self scrollEpgToCurrent];
}

- (void)closePanels
{
    self.listOpen = NO;
    self.epgOpen = NO;
    [self layoutPanelsAnimated:YES];
    if (self.paused) [self showOverlay];
}

- (void)scrollListToCurrent
{
    NSUInteger i = [self.entries indexOfObjectPassingTest:^BOOL(M3UEntry *e, NSUInteger k, BOOL *stop) { return [e.url isEqualToString:self.current.url]; }];
    if (i != NSNotFound && i < [self.entries count]) [self.listTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:(NSInteger)i inSection:0] atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
}

- (void)scrollEpgToCurrent
{
    double now = [self nowEpoch];
    for (NSUInteger i = 0; i < [self.epgRows count]; i++) {
        NSArray *r = [self.epgRows objectAtIndex:i];
        if ([[r objectAtIndex:1] doubleValue] > now) {
            [self.epgTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:(NSInteger)i inSection:0] atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
            return;
        }
    }
}

- (double)dayStart:(NSInteger)offsetDays
{
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDate *start = nil;
    NSTimeInterval iv = 0;
    [cal rangeOfUnit:NSDayCalendarUnit startDate:&start interval:&iv forDate:[NSDate date]];
    return [start timeIntervalSince1970] + (double)offsetDays * 86400.0;
}

- (void)reloadEpgPanel
{
    NSMutableArray *rows = [NSMutableArray array];
    if (M3UEpgEnabled()) {
        double from = [self dayStart:self.dayIndex - 1], to = from + 86400.0;
        for (NSArray *e in M3UEpgAll(self.current.name)) {
            double s = [[e objectAtIndex:0] doubleValue];
            if (s >= from && s < to) [rows addObject:e];
        }
    }
    self.epgRows = rows;
    self.epgHeader.text = [NSString stringWithFormat:@"%@: %@", L(@"Program"), self.current.name];
    self.epgEmpty.hidden = [rows count] > 0;
    self.epgEmpty.text = M3UEpgEnabled() ? L(@"Brak programu dla tego kanału.") : L(@"Program TV jest wyłączony w Ustawieniach.");
    for (UIButton *b in self.dayTabs) {
        int st = (b.tag == self.dayIndex) ? GS_BLUE : GS_GRAY;
        [b setBackgroundImage:glossImage(st, 26.0f, 0, NO, NO) forState:UIControlStateNormal];
        [b setBackgroundImage:glossImage(st, 26.0f, 0, NO, YES) forState:UIControlStateHighlighted];
    }
    [self.epgTable reloadData];
}

- (void)dayTapped:(UIButton *)b
{
    self.dayIndex = b.tag;
    [self reloadEpgPanel];
    if (self.dayIndex == 1) [self scrollEpgToCurrent];
}

- (void)epgUpdated
{
    [self refreshAll];
    if (self.listOpen) [self.listTable reloadData];
}

- (void)logoLoaded
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reloadListRows) object:nil];
    [self performSelector:@selector(reloadListRows) withObject:nil afterDelay:0.15];
}

- (void)reloadListRows { if (self.listOpen) [self.listTable reloadData]; }

#pragma mark - Wybór dnia i godziny

- (void)showPicker
{
    if (self.pickerOpen) return;
    self.pickerOpen = YES;
    CGRect b = self.view.bounds;
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 340, 304)];
    v.backgroundColor = [UIColor colorWithRed:0.055f green:0.07f blue:0.12f alpha:0.98f];
    v.layer.cornerRadius = 12.0f;
    v.layer.borderWidth = 2.0f;
    v.layer.borderColor = [UIColor blackColor].CGColor;
    v.clipsToBounds = YES;
    UIImageView *hd = [self stripImage:GS_NAV h:38.0f];
    hd.frame = CGRectMake(0, 0, 340, 38);
    [v addSubview:hd];
    UILabel *t = [self smallLabel:18.0f color:M3UTextColor() align:NSTextAlignmentCenter];
    t.textColor = [UIColor whiteColor];
    t.shadowColor = [UIColor colorWithWhite:0 alpha:0.75f];
    t.shadowOffset = CGSizeMake(0, -1);
    t.font = [UIFont boldSystemFontOfSize:18.0f];
    t.frame = CGRectMake(10, 5, 320, 28);
    t.text = L(@"Archiwum: wybierz moment");
    [v addSubview:t];
    UIDatePicker *p = [[UIDatePicker alloc] initWithFrame:CGRectMake(10, 40, 320, 216)];
    p.datePickerMode = UIDatePickerModeDateAndTime;
    double now = [self nowEpoch];
    p.minimumDate = [NSDate dateWithTimeIntervalSince1970:now - kArchiveDepth];
    p.maximumDate = [NSDate dateWithTimeIntervalSince1970:now - 60.0];
    p.date = [NSDate dateWithTimeIntervalSince1970:MAX(now - kArchiveDepth, MIN(now - 3600.0, [self position]))];
    [v addSubview:p];
    self.picker = p;
    UIButton *no = [self glossButton:L(@"Anuluj") style:GS_GRAY h:38.0f radius:9.0f border:YES size:16.0f action:@selector(hidePicker)];
    no.frame = CGRectMake(14, 258, 148, 38);
    [v addSubview:no];
    UIButton *go = [self glossButton:L(@"Odtwórz") style:GS_BLUE h:38.0f radius:9.0f border:YES size:16.0f action:@selector(pickerGo)];
    go.frame = CGRectMake(178, 258, 148, 38);
    [v addSubview:go];
    v.center = CGPointMake(b.size.width / 2.0f, b.size.height / 2.0f);
    self.pickerView = v;
    [self.view addSubview:v];
}

- (void)hidePicker
{
    [self.pickerView removeFromSuperview];
    self.pickerView = nil;
    self.picker = nil;
    self.pickerOpen = NO;
}

- (void)pickerGo
{
    double t = [self.picker.date timeIntervalSince1970];
    [self hidePicker];
    [self closePanels];
    [self playArchiveFrom:t];
}

#pragma mark - Tabele

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s
{
    return tv == self.listTable ? (NSInteger)[self.entries count] : (NSInteger)[self.epgRows count];
}

- (UIImage *)tileFor:(M3UEntry *)e
{
    if ([e.logo length]) {
        UIImage *t = M3UCachedLogoTile(e.logo, 42.0f);
        if (t) return t;
        if (!M3ULogoFailed(e.logo)) {
            __weak M3UPlayerController *weak = self;
            M3URequestLogo(e.logo, 42.0f, ^BOOL{ M3UPlayerController *me = weak; return me && me.listOpen; });
        }
    }
    return M3UMonogramTile(e.name, 42.0f);
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip
{
    BOOL channels = (tv == self.listTable);
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:channels ? @"c" : @"e"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:channels ? @"c" : @"e"];
        cell.textLabel.font = [UIFont boldSystemFontOfSize:17.0f];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:13.0f];
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
        cell.textLabel.shadowOffset = CGSizeMake(0, -1);
        cell.textLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.75f];
        UIView *hl = [[UIView alloc] initWithFrame:CGRectMake(0, kRow - 3.0f, 600, 1)];       /* jasna kreska pod czarnym separatorem */
        hl.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.11f];
        hl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [cell.contentView addSubview:hl];
        UIView *track = [[UIView alloc] initWithFrame:CGRectZero];            /* pasek postępu audycji jak suwak iOS 6 */
        track.tag = 77;
        track.backgroundColor = [UIColor colorWithRed:0.03f green:0.05f blue:0.12f alpha:1.0f];
        track.layer.cornerRadius = 4.0f;
        track.layer.borderWidth = 1.0f;
        track.layer.borderColor = [UIColor colorWithRed:0.59f green:0.69f blue:0.90f alpha:1.0f].CGColor;
        track.clipsToBounds = YES;
        UIView *fill = [[UIView alloc] initWithFrame:CGRectZero];
        fill.tag = 78;
        fill.backgroundColor = [UIColor colorWithRed:0.59f green:0.78f blue:1.0f alpha:1.0f];
        [track addSubview:fill];
        [cell.contentView addSubview:track];
    }
    UIView *track = [cell.contentView viewWithTag:77];
    track.hidden = YES;
    cell.textLabel.textColor = M3UTextColor();
    cell.detailTextLabel.textColor = M3USubtleColor();
    if (channels) {
        M3UEntry *e = [self.entries objectAtIndex:(NSUInteger)ip.row];
        cell.imageView.image = [self tileFor:e];
        cell.textLabel.text = e.name;
        NSDictionary *ep = M3UEpgEnabled() ? M3UEpgFor(e.name) : nil;
        cell.detailTextLabel.text = [ep objectForKey:@"now"] ? [NSString stringWithFormat:L(@"Teraz: %@"), [ep objectForKey:@"now"]] : nil;
    } else {
        NSArray *r = [self.epgRows objectAtIndex:(NSUInteger)ip.row];
        double s = [[r objectAtIndex:0] doubleValue], t = [[r objectAtIndex:1] doubleValue], now = [self nowEpoch];
        BOOL past = t <= now, cur = (s <= now && now < t);
        cell.imageView.image = nil;
        cell.textLabel.text = [NSString stringWithFormat:@"%@   %@", M3UEpgClock(s), [r objectAtIndex:2]];
        cell.detailTextLabel.text = past ? L(@"Archiwum") : @" ";
        if (!past && !cur) cell.textLabel.textColor = [UIColor colorWithWhite:1.0f alpha:0.45f];
        if (past) cell.detailTextLabel.textColor = [UIColor colorWithRed:0.51f green:0.75f blue:1.0f alpha:1.0f];
        if (cur) {
            track.hidden = NO;
            track.frame = CGRectMake(16, kRow - 17, tv.bounds.size.width - 32, 8);
            UIView *fill = [track viewWithTag:78];
            float pr = t > s ? (float)((now - s) / (t - s)) : 0.0f;
            fill.frame = CGRectMake(0, 0, (CGFloat)(int)(track.bounds.size.width * MIN(1.0f, MAX(0.0f, pr))), 8);
        }
    }
    return cell;
}

- (BOOL)rowIsOn:(UITableView *)tv at:(NSIndexPath *)ip
{
    if (tv == self.listTable) return [((M3UEntry *)[self.entries objectAtIndex:(NSUInteger)ip.row]).url isEqualToString:self.current.url];
    NSArray *r = [self.epgRows objectAtIndex:(NSUInteger)ip.row];
    double pos = [self position];
    return [[r objectAtIndex:0] doubleValue] <= pos && pos < [[r objectAtIndex:1] doubleValue];
}

- (void)tableView:(UITableView *)tv willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)ip
{
    cell.backgroundColor = [UIColor clearColor];
    cell.backgroundView = [self rowIsOn:tv at:ip] ? [[UIImageView alloc] initWithImage:glossImage(GS_SEL, kRow, 0, NO, NO)] : nil;       /* zaznaczony wiersz: szklany niebieski pas */
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip
{
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (tv == self.listTable) {
        self.current = [self.entries objectAtIndex:(NSUInteger)ip.row];
        [self closePanels];
        [self playLive];
        return;
    }
    NSArray *r = [self.epgRows objectAtIndex:(NSUInteger)ip.row];
    double s = [[r objectAtIndex:0] doubleValue];
    if (s > [self nowEpoch]) { [self showToast:L(@"Ta audycja jeszcze się nie zaczęła.")]; return; }
    [self closePanels];
    [self playArchiveFrom:s];                       /* od początku audycji */
}

@end
