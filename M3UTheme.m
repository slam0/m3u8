#import "M3UTheme.h"

static UIImage *img(NSString *name) { return [UIImage imageNamed:name]; }

UIColor *M3UBrown(void) { return [UIColor colorWithRed:0.24f green:0.17f blue:0.12f alpha:1.0f]; }
UIColor *M3USubtleBrown(void) { return [UIColor colorWithRed:0.47f green:0.38f blue:0.29f alpha:1.0f]; }

static UIColor *cream(void) { return [UIColor colorWithRed:0.96f green:0.92f blue:0.80f alpha:1.0f]; }
static UIColor *gold(void) { return [UIColor colorWithRed:0.93f green:0.82f blue:0.55f alpha:1.0f]; }

void M3UThemeApply(void)
{
    NSDictionary *titleAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
        cream(), UITextAttributeTextColor,
        [UIColor colorWithWhite:0.0f alpha:0.85f], UITextAttributeTextShadowColor,
        [NSValue valueWithUIOffset:UIOffsetMake(0, -1)], UITextAttributeTextShadowOffset,
        [UIFont boldSystemFontOfSize:20.0f], UITextAttributeFont, nil];
    UINavigationBar *bar = [UINavigationBar appearance];
    [bar setBackgroundImage:img(@"nav_leather") forBarMetrics:UIBarMetricsDefault];
    [bar setTitleTextAttributes:titleAttrs];

    NSDictionary *btnAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
        cream(), UITextAttributeTextColor,
        [UIColor colorWithWhite:0.0f alpha:0.85f], UITextAttributeTextShadowColor,
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

void M3UStyleTable(UITableView *tv)
{
    UIView *bg = [[UIView alloc] initWithFrame:tv.bounds];
    bg.backgroundColor = [UIColor colorWithPatternImage:img(@"bg_linen")];
    tv.backgroundView = bg;
    tv.backgroundColor = [UIColor clearColor];
    tv.separatorColor = [UIColor colorWithRed:0.78f green:0.71f blue:0.55f alpha:1.0f];
}

void M3UPaperCell(UITableViewCell *cell)
{
    cell.backgroundColor = [UIColor colorWithPatternImage:img(@"bg_paper")];
}

void M3UStyleCell(UITableViewCell *cell)
{
    UIColor *shadow = [UIColor colorWithWhite:1.0f alpha:0.9f];
    cell.textLabel.backgroundColor = [UIColor clearColor];
    cell.textLabel.textColor = M3UBrown();
    cell.textLabel.highlightedTextColor = M3UBrown();
    cell.textLabel.shadowColor = shadow;
    cell.textLabel.shadowOffset = CGSizeMake(0, 1);
    cell.detailTextLabel.backgroundColor = [UIColor clearColor];
    cell.detailTextLabel.textColor = M3USubtleBrown();
    cell.detailTextLabel.highlightedTextColor = M3USubtleBrown();
    cell.detailTextLabel.shadowColor = shadow;
    cell.detailTextLabel.shadowOffset = CGSizeMake(0, 1);
    if (!cell.selectedBackgroundView) {
        UIView *sel = [[UIView alloc] init];
        sel.backgroundColor = [UIColor colorWithRed:0.90f green:0.74f blue:0.40f alpha:1.0f];
        cell.selectedBackgroundView = sel;
    }
}

void M3UStyleSearchBar(UISearchBar *bar)
{
    bar.barStyle = UIBarStyleBlack;
    [bar setBackgroundImage:img(@"nav_leather")];
}

UIView *M3UHeaderView(NSString *title)
{
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 22)];
    UIImageView *bg = [[UIImageView alloc] initWithImage:[img(@"header_leather") resizableImageWithCapInsets:UIEdgeInsetsMake(8, 4, 8, 4)]];
    bg.frame = v.bounds;
    bg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [v addSubview:bg];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, 296, 21)];
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    l.backgroundColor = [UIColor clearColor];
    l.text = title;
    l.textColor = gold();
    l.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.9f];
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
    l.textColor = M3USubtleBrown();
    l.shadowColor = [UIColor colorWithWhite:1.0f alpha:0.8f];
    l.shadowOffset = CGSizeMake(0, 1);
    l.font = [UIFont systemFontOfSize:13.0f];
    [v addSubview:l];
    return v;
}
