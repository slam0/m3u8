#import "M3URailController.h"
#import "M3UChannelsController.h"
#import "M3UPlaylistsController.h"
#import "M3USettingsController.h"
#import "M3UMediaController.h"
#import "M3UTheme.h"
#import "M3UDiag.h"
#import "M3ULocalization.h"

static const CGFloat kRailW = 110.0f;
static const CGFloat kBtnH = 72.0f;

enum { kTagPlaylists = 0, kTagFavorites, kTagCategories, kTagSearch, kTagLayout, kTagRefresh, kTagAdd, kTagSettings };

/* Lista kategorii: w dymku (iPad) albo na osobnym ekranie (iPhone). */
@interface M3UCategoryPicker : UITableViewController
@property (nonatomic, strong) NSArray *items;
@property (nonatomic, copy) void (^picked)(NSInteger row);
@end

@implementation M3UCategoryPicker
- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = L(@"Kategorie");
    M3UStyleTable(self.tableView);
    self.tableView.rowHeight = 48.0f;
}
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return (NSInteger)[self.items count]; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip
{
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"p"];
    if (!c) c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"p"];
    M3UStyleCell(c);
    NSDictionary *d = [self.items objectAtIndex:(NSUInteger)ip.row];
    c.textLabel.text = [d objectForKey:@"name"];
    c.detailTextLabel.text = [NSString stringWithFormat:@"%d", [[d objectForKey:@"count"] intValue]];
    return c;
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip
{
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (self.picked) self.picked(ip.row);
}
@end

@interface M3URailController () <UINavigationControllerDelegate>
@property (nonatomic, strong) UINavigationController *nav;
@property (nonatomic, strong) NSMutableArray *buttons;
@property (nonatomic, strong) UIView *panel;          /* pasek boczny (iPad) albo dolny (iPhone) */
@property (nonatomic, strong) UIButton *addButton;
@property (nonatomic, strong) UIPopoverController *popover;
@property (nonatomic, assign) BOOL bottom;            /* iPhone: pasek na dole */
@end

@implementation M3URailController

M3U_ROTATE_ANY

- (id)initWithNavigation:(UINavigationController *)nav
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.nav = nav;
        nav.delegate = self;
        self.bottom = UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad;
    }
    return self;
}

/* Jeden przycisk: ikonka nad podpisem; zaznaczony dostaje niebieskie tło. Ułożenie ustawia layoutPanes. */
- (UIButton *)makeButton:(NSString *)title glyph:(NSString *)glyph tag:(NSInteger)tag
{
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.tag = tag;
    UIImage *sel = M3USelectionImage(self.bottom);
    [b setBackgroundImage:sel forState:UIControlStateHighlighted];
    [b setBackgroundImage:sel forState:UIControlStateSelected];
    [b addTarget:self action:@selector(railTapped:) forControlEvents:UIControlEventTouchUpInside];
    UIImageView *iv = [[UIImageView alloc] initWithImage:M3UImg(glyph)];
    iv.tag = 101;
    iv.userInteractionEnabled = NO;
    iv.contentMode = UIViewContentModeScaleAspectFit;
    [b addSubview:iv];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectZero];
    l.tag = 102;
    l.userInteractionEnabled = NO;
    l.backgroundColor = [UIColor clearColor];
    l.textAlignment = NSTextAlignmentCenter;
    l.font = [UIFont boldSystemFontOfSize:self.bottom ? 10.0f : 12.0f];
    l.adjustsFontSizeToFitWidth = YES;
    l.minimumFontSize = 8.0f;
    l.textColor = M3UTextColor();
    l.shadowColor = M3UShadowColor();
    l.shadowOffset = M3UShadowOffset();
    l.text = title;
    [b addSubview:l];
    return b;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    CGRect b = self.view.bounds;
    [self.view addSubview:M3UBackdropView(b)];

    self.panel = [[UIView alloc] initWithFrame:CGRectZero];
    self.buttons = [NSMutableArray array];
    NSArray *defs;
    if (self.bottom) {
        self.panel.backgroundColor = M3UPanelColor(1.0f);
        UIImageView *bg = [[UIImageView alloc] initWithImage:M3UImg(@"nav_bar")];
        bg.tag = 200;
        bg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.panel addSubview:bg];
        defs = [NSArray arrayWithObjects:
            [NSArray arrayWithObjects:@"Playlisty", @"rail_list", [NSNumber numberWithInt:kTagPlaylists], nil],
            [NSArray arrayWithObjects:@"Ulubione", @"rail_star", [NSNumber numberWithInt:kTagFavorites], nil],
            [NSArray arrayWithObjects:@"Kategorie", @"rail_cat", [NSNumber numberWithInt:kTagCategories], nil],
            [NSArray arrayWithObjects:@"Szukaj", @"rail_search", [NSNumber numberWithInt:kTagSearch], nil],
            [NSArray arrayWithObjects:@"Ustawienia", @"rail_gear", [NSNumber numberWithInt:kTagSettings], nil], nil];
    } else {
        self.panel.backgroundColor = M3UPanelColor(0.55f);
        UIView *edge = [[UIView alloc] initWithFrame:CGRectMake(kRailW - 1.0f, 0, 1, 2000)];
        edge.backgroundColor = M3UPanelEdgeColor();
        [self.panel addSubview:edge];
        UIImageView *logo = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"setup_icon"]];
        logo.frame = CGRectMake((kRailW - 64.0f) / 2.0f, 14, 64, 64);
        [self.panel addSubview:logo];
        UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(0, 80, kRailW - 1.0f, 22)];
        name.backgroundColor = [UIColor clearColor];
        name.textAlignment = NSTextAlignmentCenter;
        name.font = [UIFont boldSystemFontOfSize:17.0f];
        name.textColor = M3UTextColor();
        name.shadowColor = M3UShadowColor();
        name.shadowOffset = M3UShadowOffset();
        name.text = @"nSat";
        [self.panel addSubview:name];
        UIView *line = [[UIView alloc] initWithFrame:CGRectMake(14, 110, kRailW - 29.0f, 1)];
        line.backgroundColor = M3UPanelEdgeColor();
        [self.panel addSubview:line];
        defs = [NSArray arrayWithObjects:
            [NSArray arrayWithObjects:@"Playlisty", @"rail_list", [NSNumber numberWithInt:kTagPlaylists], nil],
            [NSArray arrayWithObjects:@"Ulubione", @"rail_star", [NSNumber numberWithInt:kTagFavorites], nil],
            [NSArray arrayWithObjects:@"Kategorie", @"rail_cat", [NSNumber numberWithInt:kTagCategories], nil],
            [NSArray arrayWithObjects:@"Szukaj", @"rail_search", [NSNumber numberWithInt:kTagSearch], nil],
            [NSArray arrayWithObjects:@"Układ", @"rail_layout", [NSNumber numberWithInt:kTagLayout], nil],
            [NSArray arrayWithObjects:@"Odśwież", @"rail_refresh", [NSNumber numberWithInt:kTagRefresh], nil],
            [NSArray arrayWithObjects:@"Ustawienia", @"rail_gear", [NSNumber numberWithInt:kTagSettings], nil], nil];
        self.addButton = [self makeButton:L(@"Dodaj") glyph:@"rail_plus" tag:kTagAdd];
        [self.panel addSubview:self.addButton];
    }
    for (NSArray *d in defs) {
        UIButton *bt = [self makeButton:L([d objectAtIndex:0]) glyph:[d objectAtIndex:1] tag:[[d objectAtIndex:2] integerValue]];
        [self.panel addSubview:bt];
        [self.buttons addObject:bt];
    }
    [self.view addSubview:self.panel];

    [self addChildViewController:self.nav];
    [self.view addSubview:self.nav.view];
    [self.nav didMoveToParentViewController:self];
    [self layoutPanes];
    [self updateHighlight];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self layoutPanes];
}

/* Układ ręczny: przy obrocie ekranu pasek dolny robi się niższy (same ikonki), boczny zostaje bez zmian. */
- (void)layoutPanes
{
    CGRect b = self.view.bounds;
    if (self.bottom) {
        BOOL compact = b.size.width > b.size.height;
        CGFloat h = compact ? 38.0f : 49.0f;
        self.panel.frame = CGRectMake(0, b.size.height - h, b.size.width, h);
        self.nav.view.frame = CGRectMake(0, 0, b.size.width, b.size.height - h);
        CGFloat bw = b.size.width / (CGFloat)[self.buttons count];
        for (NSUInteger i = 0; i < [self.buttons count]; i++) {
            UIButton *bt = [self.buttons objectAtIndex:i];
            bt.frame = CGRectMake(bw * (CGFloat)i + 2.0f, 3.0f, bw - 4.0f, h - 6.0f);
            UIView *iv = [bt viewWithTag:101], *lb = [bt viewWithTag:102];
            CGFloat bh = h - 6.0f;
            if (compact) {
                iv.frame = CGRectMake((bw - 4.0f - 22.0f) / 2.0f, (bh - 22.0f) / 2.0f, 22, 22);
                lb.hidden = YES;
            } else {
                iv.frame = CGRectMake((bw - 4.0f - 24.0f) / 2.0f, 3, 24, 24);
                lb.frame = CGRectMake(0, 28, bw - 4.0f, 14);
                lb.hidden = NO;
            }
        }
    } else {
        self.panel.frame = CGRectMake(0, 0, kRailW, b.size.height);
        self.nav.view.frame = CGRectMake(kRailW, 0, b.size.width - kRailW, b.size.height);
        CGFloat y = 120.0f;
        for (UIButton *bt in self.buttons) {
            [self placeRailButton:bt y:y];
            y += kBtnH;
        }
        [self placeRailButton:self.addButton y:b.size.height - kBtnH - 10.0f];
    }
}

- (void)placeRailButton:(UIButton *)bt y:(CGFloat)y
{
    bt.frame = CGRectMake(0, y, kRailW - 1.0f, kBtnH);
    [bt viewWithTag:101].frame = CGRectMake((kRailW - 26.0f) / 2.0f, 10, 26, 26);
    [bt viewWithTag:102].frame = CGRectMake(0, 42, kRailW - 1.0f, 18);
}

#pragma mark - Pomocnicze

- (M3UChannelsController *)topChannels
{
    UIViewController *t = self.nav.topViewController;
    return [t isKindOfClass:[M3UChannelsController class]] ? (M3UChannelsController *)t : nil;
}

/* Ekran kanałów playlisty, z której teraz korzystamy (też gdy jesteśmy głębiej, w kategorii). */
- (M3UChannelsController *)playlistRoot
{
    for (UIViewController *vc in [self.nav.viewControllers reverseObjectEnumerator])
        if ([vc isKindOfClass:[M3UChannelsController class]] && [(M3UChannelsController *)vc isPlaylistRoot]) return (M3UChannelsController *)vc;
    return nil;
}

- (void)info:(NSString *)msg
{
    [[[UIAlertView alloc] initWithTitle:nil message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
}

#pragma mark - Przyciski

- (void)railTapped:(UIButton *)b
{
    [self.popover dismissPopoverAnimated:NO];
    self.popover = nil;
    M3UBreadcrumb([NSString stringWithFormat:@"pasek: przycisk %d", (int)b.tag]);
    switch (b.tag) {
        case kTagPlaylists:
            [self.nav popToRootViewControllerAnimated:YES];
            break;
        case kTagFavorites: {
            M3UChannelsController *t = [self topChannels];
            if (t && [t isFavoritesScreen]) return;
            [self.nav pushViewController:[[M3UChannelsController alloc] initWithFavorites] animated:YES];
            break;
        }
        case kTagCategories: [self showCategories:b]; break;
        case kTagSearch: {
            M3UChannelsController *t = [self topChannels];
            if (t) [t focusSearch]; else [self info:L(@"Wyszukiwarka jest na ekranie z kanałami. Otwórz najpierw playlistę.")];
            break;
        }
        case kTagLayout: {
            M3UChannelsController *t = [self topChannels];
            if (t) [t toggleLayout]; else [self info:L(@"Układ (lista lub kafelki) zmienia się na ekranie z kanałami.")];
            break;
        }
        case kTagRefresh: {
            M3UChannelsController *r = [self playlistRoot];
            if (r) [r refreshTapped]; else [self info:L(@"Odświeżać można playlistę, którą masz otwartą.")];
            break;
        }
        case kTagAdd: {
            [self.nav popToRootViewControllerAnimated:NO];
            UIViewController *root = [self.nav.viewControllers objectAtIndex:0];
            if ([root isKindOfClass:[M3UPlaylistsController class]]) [(M3UPlaylistsController *)root addTapped];
            break;
        }
        case kTagSettings:
            if (![self.nav.topViewController isKindOfClass:[M3USettingsController class]])
                [self.nav pushViewController:[[M3USettingsController alloc] init] animated:YES];
            break;
    }
}

- (void)showCategories:(UIButton *)from
{
    M3UChannelsController *root = [self playlistRoot];
    NSArray *items = [root categoryItems];
    if (!items) { [self info:L(@"Ta playlista nie ma kategorii. Kategorie pokażą się, gdy lista ma grupy (group-title).")]; return; }
    M3UCategoryPicker *pk = [[M3UCategoryPicker alloc] initWithStyle:UITableViewStylePlain];
    pk.items = items;
    __weak M3URailController *me = self;
    __weak M3UCategoryPicker *wpk = pk;
    pk.picked = ^(NSInteger row) {
        M3URailController *s = me;
        if (!s) return;
        [s.popover dismissPopoverAnimated:YES];
        s.popover = nil;
        [s.nav popToViewController:root animated:NO];    /* na iPhonie zdejmuje też ekran wyboru */
        [root openCategoryAtIndex:row];
        (void)wpk;
    };
    if (self.bottom) {                                   /* iPhone: osobny ekran */
        [self.nav pushViewController:pk animated:YES];
        return;
    }
    CGFloat h = 48.0f * (CGFloat)[items count];
    if (h > 520.0f) h = 520.0f;
    UIPopoverController *pop = [[UIPopoverController alloc] initWithContentViewController:pk];
    pop.popoverContentSize = CGSizeMake(320.0f, h);
    self.popover = pop;
    [pop presentPopoverFromRect:from.frame inView:from.superview permittedArrowDirections:UIPopoverArrowDirectionLeft animated:YES];
}

/* Podświetla przycisk ekranu, na którym jesteśmy. */
- (void)updateHighlight
{
    UIViewController *vc = self.nav.topViewController;
    NSInteger on = -1;
    if ([vc isKindOfClass:[M3UPlaylistsController class]] || [vc isKindOfClass:[M3UMediaController class]]) on = kTagPlaylists;
    else if ([vc isKindOfClass:[M3USettingsController class]]) on = kTagSettings;
    else if ([vc isKindOfClass:[M3UCategoryPicker class]]) on = kTagCategories;
    else if ([vc isKindOfClass:[M3UChannelsController class]] && [(M3UChannelsController *)vc isFavoritesScreen]) on = kTagFavorites;
    for (UIButton *b in self.buttons) b.selected = (b.tag == on);
}

- (void)navigationController:(UINavigationController *)nc didShowViewController:(UIViewController *)vc animated:(BOOL)animated
{
    [self updateHighlight];
}

@end
