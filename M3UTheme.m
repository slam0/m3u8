#import "M3UTheme.h"

NSString *const M3UThemeDidChange = @"M3UThemeDidChange";
static NSString *const kThemeKey = @"app_theme";
static NSInteger sTheme = -1;

NSInteger M3UThemeCount(void) { return 6; }

NSInteger M3UThemeIndex(void)
{
    if (sTheme < 0) {
        id stored = [[NSUserDefaults standardUserDefaults] objectForKey:kThemeKey];
        NSInteger t = stored ? [stored integerValue] : 5;           /* domyślnie motyw nSat */
        sTheme = (t >= 0 && t < 6) ? t : 5;
    }
    return sTheme;
}

void M3USetTheme(NSInteger index)
{
    if (index < 0 || index >= 6 || index == M3UThemeIndex()) return;
    sTheme = index;
    [[NSUserDefaults standardUserDefaults] setInteger:index forKey:kThemeKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:M3UThemeDidChange object:nil];
}

NSString *M3UThemeName(NSInteger i)
{
    static NSString *const n[6] = { @"Niebieski", @"Srebrny", @"Klasyczny", @"Ciemny", @"Granatowy gradient", @"nSat" };
    return (i >= 0 && i < 6) ? n[i] : @"";
}

/* Motyw nSat (5) ma paletę i grafiki Granatowego (4); inne jest tylko tło. */
static NSInteger variant(void) { NSInteger t = M3UThemeIndex(); return t == 5 ? 4 : t; }

static BOOL themeLight(void) { NSInteger t = M3UThemeIndex(); return t == 1 || t == 2; }

static UIColor *rgb(CGFloat r, CGFloat g, CGFloat b, CGFloat a) { return [UIColor colorWithRed:r / 255.0f green:g / 255.0f blue:b / 255.0f alpha:a]; }

/* Rysowany kodem pasek lub karta dla motywu Klasycznego (bez grafik niestandardowych). */
static UIImage *classicStretch(NSString *key, CGFloat w, CGFloat h, CGFloat r, const CGFloat *t, const CGFloat *b, BOOL border, UIEdgeInsets caps)
{
    static NSMutableDictionary *cache;
    if (!cache) cache = [[NSMutableDictionary alloc] init];
    UIImage *hit = [cache objectForKey:key];
    if (hit) return hit;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(w, h), NO, [[UIScreen mainScreen] scale]);
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect rc = CGRectMake(0, 0, w, h);
    UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:rc cornerRadius:r];
    CGContextSaveGState(c);
    [p addClip];
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGFloat comps[8] = { t[0], t[1], t[2], 1, b[0], b[1], b[2], 1 };
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, comps, NULL, 2);
    CGContextDrawLinearGradient(c, g, CGPointMake(0, 0), CGPointMake(0, h), 0);
    CGGradientRelease(g);
    CGColorSpaceRelease(cs);
    CGContextRestoreGState(c);
    if (border) {
        CGContextSetRGBStrokeColor(c, 0.55f, 0.57f, 0.62f, 1);
        CGContextSetLineWidth(c, 1.0f);
        [[UIBezierPath bezierPathWithRoundedRect:CGRectInset(rc, 0.5f, 0.5f) cornerRadius:r] stroke];
    }
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    img = [img resizableImageWithCapInsets:caps];
    [cache setObject:img forKey:key];
    return img;
}

/* Grafika w wersji bieżącego motywu: pliki z końcówką _t1 (srebrny), _t3 (ciemny), _t4 (granatowy); klasyczny rysujemy kodem. */
UIImage *M3UImg(NSString *name)
{
    NSInteger t = variant();
    if (t == 0) return [UIImage imageNamed:name];
    BOOL icon = [name hasPrefix:@"rail_"] || [name hasPrefix:@"ico_"];
    if (t == 2) {
        if (icon) return [UIImage imageNamed:[name stringByAppendingString:@"_t2"]];
        if ([name isEqualToString:@"tile_card"]) {
            static const CGFloat a[3] = { 1.0f, 1.0f, 1.0f }, b[3] = { 0.93f, 0.94f, 0.96f };
            return classicStretch(@"cl-card", 40, 40, 12, a, b, YES, UIEdgeInsetsMake(14, 14, 14, 14));
        }
        if ([name isEqualToString:@"nav_bar"]) {
            static const CGFloat a[3] = { 0.62f, 0.71f, 0.82f }, b[3] = { 0.33f, 0.46f, 0.63f };
            return classicStretch(@"cl-nav", 8, 44, 0, a, b, NO, UIEdgeInsetsMake(0, 3, 0, 3));
        }
        if ([name isEqualToString:@"header_bar"]) {
            static const CGFloat a[3] = { 0.66f, 0.72f, 0.78f }, b[3] = { 0.55f, 0.62f, 0.70f };
            return classicStretch(@"cl-head", 8, 22, 0, a, b, NO, UIEdgeInsetsMake(8, 3, 8, 3));
        }
        return [UIImage imageNamed:name];
    }
    if (icon && t == 1) return [UIImage imageNamed:[name stringByAppendingString:@"_t1"]];
    if (icon) return [UIImage imageNamed:name];                  /* ciemny i granatowy: jasne ikony zostają */
    UIImage *v = [UIImage imageNamed:[NSString stringWithFormat:@"%@_t%d", name, (int)t]];
    return v ?: [UIImage imageNamed:name];
}

static UIImage *img(NSString *name) { return M3UImg(name); }

UIColor *M3UTextColor(void)
{
    switch (variant()) {
        case 1: return rgb(48, 52, 62, 1);
        case 2: return rgb(0, 0, 0, 1);
        case 3: return rgb(240, 240, 244, 1);
        default: return [UIColor colorWithRed:0.93f green:0.95f blue:0.99f alpha:1.0f];
    }
}

UIColor *M3USubtleColor(void)
{
    switch (variant()) {
        case 1: return rgb(100, 107, 122, 1);
        case 2: return rgb(81, 102, 145, 1);
        case 3: return rgb(150, 150, 162, 1);
        case 4: return rgb(140, 165, 215, 1);
        default: return [UIColor colorWithRed:0.60f green:0.67f blue:0.80f alpha:1.0f];
    }
}

UIColor *M3UAccentColor(void)
{
    switch (variant()) {
        case 1: return rgb(36, 100, 220, 1);
        case 2: return rgb(56, 84, 135, 1);
        case 3: return rgb(92, 160, 255, 1);
        default: return [UIColor colorWithRed:0.38f green:0.63f blue:1.0f alpha:1.0f];
    }
}

UIColor *M3UShadowColor(void)
{
    switch (variant()) {
        case 1: return [UIColor colorWithWhite:1.0f alpha:0.9f];
        case 2: return [UIColor clearColor];
        default: return [UIColor colorWithWhite:0.0f alpha:0.85f];
    }
}

CGSize M3UShadowOffset(void) { return themeLight() ? CGSizeMake(0, 1) : CGSizeMake(0, -1); }

UIColor *M3UPanelColor(CGFloat a)
{
    switch (variant()) {
        case 1: return rgb(206, 210, 218, a);
        case 2: return rgb(214, 220, 230, a);
        case 3: return rgb(20, 20, 24, a);
        case 4: return rgb(5, 13, 40, a);
        default: return [UIColor colorWithRed:0.02f green:0.07f blue:0.24f alpha:a];
    }
}

UIColor *M3UPanelEdgeColor(void)
{
    return themeLight() ? rgb(120, 126, 140, 0.7f) : [UIColor colorWithRed:0.59f green:0.75f blue:1.0f alpha:0.45f];
}

/* Zaznaczona pozycja paska: wersja motywu albo, w Klasycznym, systemowy niebieski. */
UIImage *M3USelectionImage(BOOL tab)
{
    if (M3UThemeIndex() == 2) {
        static const CGFloat a[3] = { 0.66f, 0.81f, 1.00f }, b[3] = { 0.42f, 0.64f, 0.96f };
        return tab ? classicStretch(@"cl-tab", 24, 44, 8, a, b, NO, UIEdgeInsetsMake(10, 10, 10, 10))
                   : classicStretch(@"cl-sel", 8, 44, 0, a, b, NO, UIEdgeInsetsMake(3, 0, 3, 0));
    }
    return tab ? [img(@"tab_sel") resizableImageWithCapInsets:UIEdgeInsetsMake(10, 10, 10, 10)]
               : [img(@"cell_sel") resizableImageWithCapInsets:UIEdgeInsetsMake(3, 0, 3, 0)];
}

UIColor *M3UThemeTint(void)
{
    switch (M3UThemeIndex()) {
        case 1: return rgb(90, 110, 150, 1);
        case 2: return nil;
        default: return nil;
    }
}

/* Kolory odtwarzacza (nad obrazem zawsze ciemne paski, zmienia się akcent): 0 nagłówek, 1 akcent, 2 zaznaczenie. */
void M3UPlayerPalette(int slot, CGFloat *top, CGFloat *bot)
{
    static const CGFloat tab[5][3][6] = {
        { { .43f, .53f, .69f, .20f, .28f, .44f }, { .47f, .63f, .88f, .12f, .31f, .75f }, { .35f, .59f, .94f, .12f, .33f, .80f } },
        { { .74f, .76f, .80f, .43f, .45f, .50f }, { .80f, .82f, .86f, .43f, .46f, .53f }, { .58f, .64f, .74f, .33f, .39f, .52f } },
        { { .62f, .71f, .82f, .33f, .46f, .63f }, { .47f, .62f, .85f, .20f, .35f, .62f }, { .30f, .55f, .92f, .11f, .34f, .78f } },
        { { .36f, .36f, .38f, .09f, .09f, .10f }, { .36f, .60f, .92f, .12f, .31f, .75f }, { .35f, .59f, .94f, .12f, .33f, .80f } },
        { { .23f, .35f, .63f, .05f, .10f, .26f }, { .27f, .47f, .82f, .08f, .24f, .59f }, { .24f, .41f, .78f, .08f, .22f, .55f } }
    };
    const CGFloat *r = tab[variant()][slot];
    for (int i = 0; i < 3; i++) { top[i] = r[i]; bot[i] = r[3 + i]; }
}

/* Tło całego ekranu. Niebieski: obraz z błyskiem. Pozostałe motywy: rysowane kodem (gradient, szczotkowany metal, prążki systemowe). */
@interface M3UBackdrop : UIView
@property (nonatomic) BOOL forceBlue;
@end

static UIImage *gradientImage(CGFloat h, const CGFloat *t, const CGFloat *b, BOOL glow)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(4, h), YES, [[UIScreen mainScreen] scale]);
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGFloat comps[8] = { t[0], t[1], t[2], 1, b[0], b[1], b[2], 1 };
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, comps, NULL, 2);
    CGContextDrawLinearGradient(c, g, CGPointMake(0, 0), CGPointMake(0, h), 0);
    CGGradientRelease(g);
    CGColorSpaceRelease(cs);
    UIImage *i = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [i resizableImageWithCapInsets:UIEdgeInsetsMake(0, 1, 0, 1)];
}

/* Tło motywu nSat: gradient granatowy, jasna poświata za środkiem i ukośne pasy zanikające ku górze. */
static UIImage *isatImage(CGSize sz)
{
    UIGraphicsBeginImageContextWithOptions(sz, YES, [[UIScreen mainScreen] scale]);
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGFloat w = sz.width, h = sz.height;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGFloat lin[8] = { 24 / 255.0f, 42 / 255.0f, 100 / 255.0f, 1, 3 / 255.0f, 6 / 255.0f, 22 / 255.0f, 1 };
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, lin, NULL, 2);
    CGContextDrawLinearGradient(c, g, CGPointMake(0, 0), CGPointMake(0, h), 0);
    CGGradientRelease(g);
    CGFloat rad[8] = { 60 / 255.0f, 120 / 255.0f, 1.0f, 0.40f, 60 / 255.0f, 120 / 255.0f, 1.0f, 0.0f };
    CGGradientRef gl = CGGradientCreateWithColorComponents(cs, rad, NULL, 2);
    CGFloat r = MIN(w, h) * 0.62f;
    CGContextSaveGState(c);
    CGContextTranslateCTM(c, w / 2.0f, h * 0.455f);                /* elipsa: rozciągnięcie w poziomie nieco większe niż w pionie */
    CGContextDrawRadialGradient(c, gl, CGPointZero, 0, CGPointZero, r, 0);
    CGContextRestoreGState(c);
    CGGradientRelease(gl);
    CGFloat y0 = h * 0.616f, step = h * 0.0528f, wd = h * 0.0229f, slant = 0.26f, fade = h * 0.194f;
    CGFloat sc[8] = { 80 / 255.0f, 140 / 255.0f, 1.0f, 0.0f, 80 / 255.0f, 140 / 255.0f, 1.0f, 0.16f };
    CGGradientRef sg = CGGradientCreateWithColorComponents(cs, sc, NULL, 2);
    for (CGFloat x = -(h - y0) * slant - step; x < w + step; x += step) {
        CGContextSaveGState(c);
        CGContextMoveToPoint(c, x, h);
        CGContextAddLineToPoint(c, x + wd, h);
        CGContextAddLineToPoint(c, x + wd + (h - y0) * slant, y0);
        CGContextAddLineToPoint(c, x + (h - y0) * slant, y0);
        CGContextClosePath(c);
        CGContextClip(c);
        CGContextDrawLinearGradient(c, sg, CGPointMake(0, y0), CGPointMake(0, MIN(h, y0 + fade)), kCGGradientDrawsAfterEndLocation);
        CGContextRestoreGState(c);
    }
    CGGradientRelease(sg);
    CGColorSpaceRelease(cs);
    UIImage *i = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return i;
}

/* Płytka ze smugami jak w szczotkowanym metalu (do powtarzania). */
static UIImage *brushedTile(void)
{
    static UIImage *tile;
    if (tile) return tile;
    CGFloat s = 128;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(s, s), NO, 1.0f);
    CGContextRef c = UIGraphicsGetCurrentContext();
    unsigned int seed = 7;
    for (int y = 0; y < (int)s; y++) {
        seed = seed * 1103515245u + 12345u;
        int r = (int)((seed >> 16) & 0xff);
        CGFloat a = (CGFloat)(r % 40) / 400.0f;                 /* 0..0.10 */
        if (r & 0x80) CGContextSetRGBFillColor(c, 1, 1, 1, a); else CGContextSetRGBFillColor(c, 0, 0, 0, a * 0.8f);
        CGContextFillRect(c, CGRectMake(0, y, s, 1));
    }
    for (int i = 0; i < 700; i++) {                              /* drobne rysy w poziomie */
        seed = seed * 1103515245u + 12345u;
        int x = (int)((seed >> 8) % (unsigned)s), y = (int)((seed >> 20) % (unsigned)s), len = 8 + (int)((seed >> 4) % 30);
        CGContextSetRGBFillColor(c, (i & 1) ? 1 : 0, (i & 1) ? 1 : 0, (i & 1) ? 1 : 0, (i & 1) ? 0.10f : 0.07f);
        CGContextFillRect(c, CGRectMake(x, y, len, 1));
    }
    tile = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return tile;
}

@implementation M3UBackdrop {
    UIImageView *_pic;
    UIView *_tex;
    NSString *_name;
    NSInteger _themeShown;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.clipsToBounds = YES;
    self.userInteractionEnabled = NO;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _pic = [[UIImageView alloc] initWithImage:nil];
    _pic.contentMode = UIViewContentModeScaleToFill;     /* ramkę liczymy sami, w layoutSubviews */
    [self addSubview:_pic];
    _tex = [[UIView alloc] initWithFrame:CGRectZero];
    _tex.hidden = YES;
    [self addSubview:_tex];
    _themeShown = -1;
    return self;
}

/* Obraz dobrany do rozmiaru i układu ekranu (pion/poziom, iPad/telefon), żeby nie był rozciągany. */
- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat bw = self.bounds.size.width, bh = self.bounds.size.height;
    NSInteger t = self.forceBlue ? 0 : M3UThemeIndex();
    if (t == 5) {                                               /* nSat: granat, poświata i ukośne pasy u dołu */
        _tex.hidden = YES;
        _pic.hidden = NO;
        _pic.frame = CGRectMake(0, 0, bw, bh);
        self.backgroundColor = [UIColor blackColor];
        if (_themeShown != 5 || fabs(_pic.image.size.height - bh) > 1.0f || fabs(_pic.image.size.width - bw) > 1.0f) _pic.image = isatImage(CGSizeMake(MAX(bw, 8.0f), MAX(bh, 8.0f)));
        _themeShown = 5;
        return;
    }
    if (t != 0) {
        _pic.hidden = NO;
        _tex.hidden = YES;
        _pic.frame = CGRectMake(0, 0, bw, bh);
        if (t == 2) {                                           /* systemowe prążki jak w tabeli grupowanej */
            _pic.hidden = YES;
            self.backgroundColor = [UIColor groupTableViewBackgroundColor];
            return;
        }
        self.backgroundColor = [UIColor blackColor];
        static const CGFloat sT[3] = { 0.86f, 0.87f, 0.89f }, sB[3] = { 0.72f, 0.74f, 0.77f };
        static const CGFloat dT[3] = { 0.18f, 0.18f, 0.20f }, dB[3] = { 0.04f, 0.04f, 0.05f };
        static const CGFloat nT[3] = { 0.10f, 0.20f, 0.45f }, nB[3] = { 0.01f, 0.03f, 0.09f };
        const CGFloat *top = t == 1 ? sT : (t == 3 ? dT : nT), *bot = t == 1 ? sB : (t == 3 ? dB : nB);
        if (t != _themeShown || fabs(_pic.image.size.height - bh) > 1.0f) _pic.image = gradientImage(MAX(bh, 8.0f), top, bot, t == 4);
        if (t == 4) {                                           /* błysk u góry granatowego gradientu */
            _tex.hidden = NO;
            _tex.frame = CGRectMake(0, 0, bw, MIN(bh, 420.0f));
            _tex.backgroundColor = [UIColor clearColor];
            if (_themeShown != 4 || _tex.layer.sublayers.count == 0) {
                CAGradientLayer *g = [CAGradientLayer layer];
                g.colors = [NSArray arrayWithObjects:(id)[UIColor colorWithRed:0.35f green:0.55f blue:0.95f alpha:0.40f].CGColor, (id)[UIColor colorWithRed:0.35f green:0.55f blue:0.95f alpha:0.0f].CGColor, nil];
                g.frame = _tex.bounds;
                g.name = @"glow";
                [_tex.layer addSublayer:g];
            }
            for (CALayer *l in _tex.layer.sublayers) if ([l.name isEqualToString:@"glow"]) l.frame = _tex.bounds;
        } else if (t == 1) {
            _tex.hidden = NO;
            _tex.frame = CGRectMake(0, 0, bw, bh);
            _tex.backgroundColor = [UIColor colorWithPatternImage:brushedTile()];
        }
        _themeShown = t;
        return;
    }
    self.backgroundColor = [UIColor blackColor];
    _pic.hidden = NO;
    _tex.hidden = YES;
    BOOL landscape = bw > bh;
    BOOL pad = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
    NSString *name = pad ? (landscape ? @"bg_pad_l" : @"bg_pad_p") : (landscape ? @"bg_phone_l" : @"bg_main");
    if (![_name isEqualToString:name] || _themeShown != 0) {
        _name = name;
        _pic.image = [UIImage imageNamed:name];
    }
    _themeShown = 0;
    CGSize is = _pic.image.size;
    if (is.width < 1 || is.height < 1) return;
    CGFloat k = MAX(bw / is.width, bh / is.height);            /* wypełnij cały widok, bez zniekształceń */
    CGFloat w = is.width * k, h = is.height * k;
    _pic.frame = CGRectMake((bw - w) / 2.0f, 0, w, h);          /* przypięty do góry, wyśrodkowany */
}

@end

UIView *M3UBackdropView(CGRect frame) { return [[M3UBackdrop alloc] initWithFrame:frame]; }
UIView *M3UBackdropViewBlue(CGRect frame)
{
    M3UBackdrop *b = [[M3UBackdrop alloc] initWithFrame:frame];
    b.forceBlue = YES;
    return b;
}

static UIColor *shadowColor(void) { return M3UShadowColor(); }

void M3UThemeApply(void)
{
    NSInteger t = M3UThemeIndex();
    UINavigationBar *bar = [UINavigationBar appearance];
    UIBarButtonItem *item = [UIBarButtonItem appearance];
    if (t == 2) {                                                 /* Klasyczny: wszystko systemowe */
        [bar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
        [bar setTitleTextAttributes:nil];
        [item setBackgroundImage:nil forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
        [item setBackgroundImage:nil forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
        [item setBackButtonBackgroundImage:nil forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
        [item setBackButtonBackgroundImage:nil forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
        [item setTitleTextAttributes:nil forState:UIControlStateNormal];
        [item setTitleTextAttributes:nil forState:UIControlStateHighlighted];
        return;
    }
    CGSize so = M3UShadowOffset();
    NSDictionary *titleAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
        M3UTextColor(), UITextAttributeTextColor,
        shadowColor(), UITextAttributeTextShadowColor,
        [NSValue valueWithUIOffset:UIOffsetMake(so.width, so.height)], UITextAttributeTextShadowOffset,
        [UIFont boldSystemFontOfSize:20.0f], UITextAttributeFont, nil];
    [bar setBackgroundImage:img(@"nav_bar") forBarMetrics:UIBarMetricsDefault];
    [bar setTitleTextAttributes:titleAttrs];

    NSDictionary *btnAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
        M3UTextColor(), UITextAttributeTextColor,
        shadowColor(), UITextAttributeTextShadowColor,
        [NSValue valueWithUIOffset:UIOffsetMake(so.width, so.height)], UITextAttributeTextShadowOffset,
        [UIFont boldSystemFontOfSize:13.0f], UITextAttributeFont, nil];
    UIEdgeInsets caps = UIEdgeInsetsMake(10, 10, 10, 10);
    [item setBackgroundImage:[img(@"btn_bar") resizableImageWithCapInsets:caps] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [item setBackgroundImage:[img(@"btn_bar_pressed") resizableImageWithCapInsets:caps] forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
    UIEdgeInsets backCaps = UIEdgeInsetsMake(0, 15, 0, 6);
    [item setBackButtonBackgroundImage:[img(@"btn_back") resizableImageWithCapInsets:backCaps] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [item setBackButtonBackgroundImage:[img(@"btn_back_pressed") resizableImageWithCapInsets:backCaps] forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
    [item setTitleTextAttributes:btnAttrs forState:UIControlStateNormal];
    [item setTitleTextAttributes:btnAttrs forState:UIControlStateHighlighted];
}

UIImage *M3UBarIcon(NSString *name) { return img(name); }

void M3UStyleTable(UITableView *tv)
{
    tv.backgroundView = M3UBackdropView(tv.bounds);
    tv.backgroundColor = [UIColor clearColor];
    /* poza Klasycznym linie rysuje tło wiersza */
    tv.separatorStyle = M3UThemeIndex() == 2 ? UITableViewCellSeparatorStyleSingleLine : UITableViewCellSeparatorStyleNone;
}

void M3UStyleCell(UITableViewCell *cell)
{
    NSInteger t = M3UThemeIndex();
    cell.textLabel.backgroundColor = [UIColor clearColor];
    cell.detailTextLabel.backgroundColor = [UIColor clearColor];
    cell.textLabel.textColor = M3UTextColor();
    cell.detailTextLabel.textColor = M3USubtleColor();
    if (t == 2) {                                                 /* Klasyczny: biały wiersz, systemowe zaznaczenie */
        cell.backgroundView = nil;
        cell.selectedBackgroundView = nil;
        cell.backgroundColor = [UIColor whiteColor];
        cell.contentView.backgroundColor = [UIColor clearColor];
        cell.textLabel.highlightedTextColor = [UIColor whiteColor];
        cell.detailTextLabel.highlightedTextColor = [UIColor whiteColor];
        cell.textLabel.shadowColor = nil;
        cell.detailTextLabel.shadowColor = nil;
        return;
    }
    cell.backgroundColor = [UIColor clearColor];
    cell.contentView.backgroundColor = [UIColor clearColor];
    if (![cell.backgroundView isKindOfClass:[UIImageView class]] || ((UIImageView *)cell.backgroundView).tag != (NSInteger)(1000 + t)) {
        UIImageView *bg = [[UIImageView alloc] initWithImage:[img(@"cell_bg") resizableImageWithCapInsets:UIEdgeInsetsMake(3, 0, 3, 0)]];
        bg.tag = (NSInteger)(1000 + t);
        cell.backgroundView = bg;
        cell.selectedBackgroundView = [[UIImageView alloc] initWithImage:[img(@"cell_sel") resizableImageWithCapInsets:UIEdgeInsetsMake(3, 0, 3, 0)]];
    }
    UIColor *hi = (t == 1) ? M3UTextColor() : [UIColor whiteColor];
    cell.textLabel.highlightedTextColor = hi;
    cell.textLabel.shadowColor = shadowColor();
    cell.textLabel.shadowOffset = M3UShadowOffset();
    cell.detailTextLabel.highlightedTextColor = (t == 1) ? M3USubtleColor() : [UIColor colorWithWhite:0.92f alpha:1.0f];
    cell.detailTextLabel.shadowColor = shadowColor();
    cell.detailTextLabel.shadowOffset = M3UShadowOffset();
}

void M3UStyleSearchBar(UISearchBar *bar)
{
    NSInteger t = M3UThemeIndex();
    bar.barStyle = (t == 1 || t == 2) ? UIBarStyleDefault : UIBarStyleBlack;
    [bar setBackgroundImage:(t == 2) ? nil : img(@"nav_bar")];
}

UIView *M3UHeaderView(NSString *title)
{
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 22)];
    UIImageView *bg = [[UIImageView alloc] initWithImage:[img(@"header_bar") resizableImageWithCapInsets:UIEdgeInsetsMake(8, 4, 8, 4)]];
    bg.frame = v.bounds;
    bg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [v addSubview:bg];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, 296, 21)];
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    l.backgroundColor = [UIColor clearColor];
    l.text = title;
    BOOL classic = M3UThemeIndex() == 2;
    l.textColor = classic ? [UIColor whiteColor] : M3UTextColor();
    l.shadowColor = classic ? [UIColor colorWithWhite:0 alpha:0.45f] : shadowColor();
    l.shadowOffset = classic ? CGSizeMake(0, -1) : M3UShadowOffset();
    l.font = [UIFont boldSystemFontOfSize:13.0f];
    [v addSubview:l];
    return v;
}

CGFloat M3UFooterHeight(NSString *text, CGFloat w)
{
    CGSize s = [text sizeWithFont:[UIFont systemFontOfSize:13.0f] constrainedToSize:CGSizeMake(w - 40.0f, 1000.0f)
                    lineBreakMode:NSLineBreakByWordWrapping];
    return s.height + 22.0f;
}

UIView *M3UFooterView(NSString *text, CGFloat w)
{
    CGFloat h = M3UFooterHeight(text, w);
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(20, 10, w - 40.0f, h - 14.0f)];
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    l.backgroundColor = [UIColor clearColor];
    l.text = text;
    l.numberOfLines = 0;
    l.textAlignment = NSTextAlignmentCenter;
    l.textColor = M3USubtleColor();
    l.shadowColor = M3UThemeIndex() == 2 ? [UIColor whiteColor] : shadowColor();
    l.shadowOffset = M3UThemeIndex() == 2 ? CGSizeMake(0, 1) : M3UShadowOffset();
    l.font = [UIFont systemFontOfSize:13.0f];
    [v addSubview:l];
    return v;
}

/* Znacznik ulubionych: niebieska zakładka (wstążka z wcięciem) w stylu reszty aplikacji, rysowana kodem. */
UIImage *M3UFavoriteMark(CGFloat side)
{
    static NSMutableDictionary *cache;
    if (!cache) cache = [[NSMutableDictionary alloc] init];
    NSString *k = [NSString stringWithFormat:@"%d", (int)side];
    UIImage *hit = [cache objectForKey:k];
    if (hit) return hit;
    CGFloat w = (CGFloat)(int)(side * 0.62f), h = side;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(w, h), NO, [[UIScreen mainScreen] scale]);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGFloat inset = 1.0f;
    UIBezierPath *p = [UIBezierPath bezierPath];
    [p moveToPoint:CGPointMake(inset, 0)];
    [p addLineToPoint:CGPointMake(w - inset, 0)];
    [p addLineToPoint:CGPointMake(w - inset, h - inset)];
    [p addLineToPoint:CGPointMake(w / 2.0f, h * 0.72f)];
    [p addLineToPoint:CGPointMake(inset, h - inset)];
    [p closePath];
    CGContextSaveGState(ctx);
    [p addClip];
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGFloat c[8] = { 0.45f, 0.66f, 1.0f, 1.0f,  0.13f, 0.32f, 0.78f, 1.0f };
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, c, NULL, 2);
    CGContextDrawLinearGradient(ctx, g, CGPointMake(0, 0), CGPointMake(0, h), 0);
    CGGradientRelease(g);
    CGColorSpaceRelease(cs);
    CGContextRestoreGState(ctx);
    CGContextSetRGBStrokeColor(ctx, 1.0f, 1.0f, 1.0f, 0.9f);
    CGContextSetLineWidth(ctx, 1.0f);
    [p stroke];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    [cache setObject:img forKey:k];
    return img;
}

/* Płytka z białym symbolem na niebieskim, szklistym tle. */
UIImage *M3UGlyphTile(int kind, CGFloat side)
{
    static NSMutableDictionary *cache;
    if (!cache) cache = [[NSMutableDictionary alloc] init];
    NSString *k = [NSString stringWithFormat:@"%d|%d", kind, (int)side];
    UIImage *hit = [cache objectForKey:k];
    if (hit) return hit;

    UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, [[UIScreen mainScreen] scale]);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect r = CGRectMake(1, 1, side - 2, side - 2);
    UIBezierPath *shape = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:side * 0.2f];
    CGContextSaveGState(ctx);
    [shape addClip];
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGFloat c[8] = { 0.36f, 0.56f, 0.92f, 1.0f,  0.13f, 0.28f, 0.64f, 1.0f };
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, c, NULL, 2);
    CGContextDrawLinearGradient(ctx, g, CGPointMake(0, 0), CGPointMake(0, side), 0);
    CGGradientRelease(g);
    CGColorSpaceRelease(cs);

    CGContextSetRGBFillColor(ctx, 1, 1, 1, 0.96f);
    CGFloat u = side / 40.0f;   /* jednostka: płytka ma 40 jednostek */
    if (kind == 0) {            /* gwiazdka */
        static const CGFloat pts[10][2] = { {0,-1}, {0.2245f,-0.309f}, {0.9511f,-0.309f}, {0.3633f,0.118f}, {0.5878f,0.809f},
                                            {0,0.382f}, {-0.5878f,0.809f}, {-0.3633f,0.118f}, {-0.9511f,-0.309f}, {-0.2245f,-0.309f} };
        CGFloat cx = side / 2.0f, cy = side / 2.0f + 1.0f * u, R = 14.0f * u;
        CGContextSetRGBFillColor(ctx, 1.0f, 0.82f, 0.30f, 1.0f);
        CGContextMoveToPoint(ctx, cx + pts[0][0] * R, cy + pts[0][1] * R);
        for (int i = 1; i < 10; i++) CGContextAddLineToPoint(ctx, cx + pts[i][0] * R, cy + pts[i][1] * R);
        CGContextFillPath(ctx);
    } else if (kind == 1) {     /* lista */
        for (int i = 0; i < 3; i++) {
            CGFloat y = (12 + i * 8) * u;
            CGContextFillEllipseInRect(ctx, CGRectMake(9 * u, y, 4 * u, 4 * u));
            [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(16 * u, y, 16 * u, 4 * u) cornerRadius:2 * u] fill];
        }
    } else {                    /* plik z zagiętym rogiem i liniami */
        CGContextMoveToPoint(ctx, 11 * u, 8 * u);
        CGContextAddLineToPoint(ctx, 24 * u, 8 * u);
        CGContextAddLineToPoint(ctx, 30 * u, 14 * u);
        CGContextAddLineToPoint(ctx, 30 * u, 32 * u);
        CGContextAddLineToPoint(ctx, 11 * u, 32 * u);
        CGContextFillPath(ctx);
        CGContextSetRGBFillColor(ctx, 0.2f, 0.36f, 0.72f, 1.0f);
        for (int i = 0; i < 3; i++) CGContextFillRect(ctx, CGRectMake(14 * u, (18 + i * 5) * u, 13 * u, 2 * u));
    }
    CGContextSetRGBFillColor(ctx, 1, 1, 1, 0.22f);
    CGContextFillRect(ctx, CGRectMake(0, 0, side, side / 2.0f));
    CGContextRestoreGState(ctx);
    [[UIColor colorWithRed:0.03f green:0.05f blue:0.11f alpha:0.95f] setStroke];
    shape.lineWidth = 1.0f;
    [shape stroke];
    UIImage *out = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    [cache setObject:out forKey:k];
    return out;
}
