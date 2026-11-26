#import "M3UTheme.h"

static UIImage *img(NSString *name) { return [UIImage imageNamed:name]; }

UIColor *M3UTextColor(void) { return [UIColor colorWithRed:0.93f green:0.95f blue:0.99f alpha:1.0f]; }
UIColor *M3USubtleColor(void) { return [UIColor colorWithRed:0.60f green:0.67f blue:0.80f alpha:1.0f]; }
UIColor *M3UAccentColor(void) { return [UIColor colorWithRed:0.38f green:0.63f blue:1.0f alpha:1.0f]; }
UIImage *M3UBackgroundPattern(void) { return img(@"bg_linen"); }

static UIColor *shadowColor(void) { return [UIColor colorWithWhite:0.0f alpha:0.85f]; }

void M3UThemeApply(void)
{
    NSDictionary *titleAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
        M3UTextColor(), UITextAttributeTextColor,
        shadowColor(), UITextAttributeTextShadowColor,
        [NSValue valueWithUIOffset:UIOffsetMake(0, -1)], UITextAttributeTextShadowOffset,
        [UIFont boldSystemFontOfSize:20.0f], UITextAttributeFont, nil];
    UINavigationBar *bar = [UINavigationBar appearance];
    [bar setBackgroundImage:img(@"nav_bar") forBarMetrics:UIBarMetricsDefault];
    [bar setTitleTextAttributes:titleAttrs];

    NSDictionary *btnAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
        M3UTextColor(), UITextAttributeTextColor,
        shadowColor(), UITextAttributeTextShadowColor,
        [NSValue valueWithUIOffset:UIOffsetMake(0, -1)], UITextAttributeTextShadowOffset,
        [UIFont boldSystemFontOfSize:13.0f], UITextAttributeFont, nil];
    UIBarButtonItem *item = [UIBarButtonItem appearance];
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
    UIView *bg = [[UIView alloc] initWithFrame:tv.bounds];
    bg.backgroundColor = [UIColor colorWithPatternImage:M3UBackgroundPattern()];
    tv.backgroundView = bg;
    tv.backgroundColor = [UIColor clearColor];
    tv.separatorStyle = UITableViewCellSeparatorStyleNone;   /* linie rysuje tło wiersza */
}

void M3UStyleCell(UITableViewCell *cell)
{
    cell.backgroundColor = [UIColor clearColor];
    cell.contentView.backgroundColor = [UIColor clearColor];
    if (![cell.backgroundView isKindOfClass:[UIImageView class]]) {
        cell.backgroundView = [[UIImageView alloc] initWithImage:[img(@"cell_bg") resizableImageWithCapInsets:UIEdgeInsetsMake(3, 0, 3, 0)]];
        cell.selectedBackgroundView = [[UIImageView alloc] initWithImage:[img(@"cell_sel") resizableImageWithCapInsets:UIEdgeInsetsMake(3, 0, 3, 0)]];
    }
    cell.textLabel.backgroundColor = [UIColor clearColor];
    cell.textLabel.textColor = M3UTextColor();
    cell.textLabel.highlightedTextColor = [UIColor whiteColor];
    cell.textLabel.shadowColor = shadowColor();
    cell.textLabel.shadowOffset = CGSizeMake(0, -1);
    cell.detailTextLabel.backgroundColor = [UIColor clearColor];
    cell.detailTextLabel.textColor = M3USubtleColor();
    cell.detailTextLabel.highlightedTextColor = [UIColor colorWithWhite:0.92f alpha:1.0f];
    cell.detailTextLabel.shadowColor = shadowColor();
    cell.detailTextLabel.shadowOffset = CGSizeMake(0, -1);
}

void M3UStyleSearchBar(UISearchBar *bar)
{
    bar.barStyle = UIBarStyleBlack;
    [bar setBackgroundImage:img(@"nav_bar")];
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
    l.textColor = M3UTextColor();
    l.shadowColor = shadowColor();
    l.shadowOffset = CGSizeMake(0, -1);
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
    l.shadowColor = shadowColor();
    l.shadowOffset = CGSizeMake(0, -1);
    l.font = [UIFont systemFontOfSize:13.0f];
    [v addSubview:l];
    return v;
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
