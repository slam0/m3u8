#import "M3URailController.h"
#import "M3UChannelsController.h"
#import "M3UPlaylistsController.h"
#import "M3UTheme.h"
#import "M3UDiag.h"

static const CGFloat kRailW = 110.0f;
static const CGFloat kBtnH = 72.0f;

/* Lista kategorii w dymku (Popover). */
@interface M3UCategoryPicker : UITableViewController
@property (nonatomic, strong) NSArray *items;
@property (nonatomic, copy) void (^picked)(NSInteger row);
@end

@implementation M3UCategoryPicker
- (void)viewDidLoad
{
    [super viewDidLoad];
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
@property (nonatomic, strong) NSArray *buttons;
@property (nonatomic, strong) UIPopoverController *popover;
@end

@implementation M3URailController

M3U_ROTATE_ANY

- (id)initWithNavigation:(UINavigationController *)nav
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) { self.nav = nav; nav.delegate = self; }
    return self;
}

/* Jeden przycisk paska: ikonka nad podpisem; zaznaczony dostaje niebieskie tło jak wiersz listy. */
- (UIButton *)railButton:(NSString *)title glyph:(NSString *)glyph tag:(NSInteger)tag y:(CGFloat)y
{
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.frame = CGRectMake(0, y, kRailW - 1.0f, kBtnH);
    b.tag = tag;
    UIImage *sel = [[UIImage imageNamed:@"cell_sel"] resizableImageWithCapInsets:UIEdgeInsetsMake(3, 0, 3, 0)];
    [b setBackgroundImage:sel forState:UIControlStateHighlighted];
    [b setBackgroundImage:sel forState:UIControlStateSelected];
    [b addTarget:self action:@selector(railTapped:) forControlEvents:UIControlEventTouchUpInside];
    UIImageView *iv = [[UIImageView alloc] initWithImage:[UIImage imageNamed:glyph]];
    iv.frame = CGRectMake((kRailW - 26.0f) / 2.0f, 10, 26, 26);
    iv.userInteractionEnabled = NO;
    [b addSubview:iv];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(0, 42, kRailW - 1.0f, 18)];
    l.userInteractionEnabled = NO;
    l.backgroundColor = [UIColor clearColor];
    l.textAlignment = NSTextAlignmentCenter;
    l.font = [UIFont boldSystemFontOfSize:12.0f];
    l.textColor = M3UTextColor();
    l.shadowColor = [UIColor colorWithWhite:0 alpha:0.8f];
    l.shadowOffset = CGSizeMake(0, -1);
    l.text = title;
    [b addSubview:l];
    return b;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    CGRect b = self.view.bounds;
    [self.view addSubview:M3UBackdropView(b)];

    UIView *rail = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kRailW, b.size.height)];
    rail.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    rail.backgroundColor = [UIColor colorWithRed:0.02f green:0.07f blue:0.24f alpha:0.55f];
    UIView *edge = [[UIView alloc] initWithFrame:CGRectMake(kRailW - 1.0f, 0, 1, b.size.height)];
    edge.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    edge.backgroundColor = [UIColor colorWithRed:0.59f green:0.75f blue:1.0f alpha:0.45f];
    [rail addSubview:edge];
    [self.view addSubview:rail];

    UIImageView *logo = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"setup_icon"]];
    logo.frame = CGRectMake((kRailW - 64.0f) / 2.0f, 14, 64, 64);
    [rail addSubview:logo];
    UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(0, 80, kRailW - 1.0f, 22)];
    name.backgroundColor = [UIColor clearColor];
    name.textAlignment = NSTextAlignmentCenter;
    name.font = [UIFont boldSystemFontOfSize:17.0f];
    name.textColor = M3UTextColor();
    name.shadowColor = [UIColor colorWithWhite:0 alpha:0.8f];
    name.shadowOffset = CGSizeMake(0, -1);
    name.text = @"iSat";
    [rail addSubview:name];
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(14, 110, kRailW - 29.0f, 1)];
    line.backgroundColor = [UIColor colorWithRed:0.59f green:0.75f blue:1.0f alpha:0.4f];
    [rail addSubview:line];

    NSArray *defs = [NSArray arrayWithObjects:
        [NSArray arrayWithObjects:@"Playlisty", @"rail_list", nil],
        [NSArray arrayWithObjects:@"Ulubione", @"rail_star", nil],
        [NSArray arrayWithObjects:@"Kategorie", @"rail_cat", nil],
        [NSArray arrayWithObjects:@"Szukaj", @"rail_search", nil],
        [NSArray arrayWithObjects:@"Układ", @"rail_layout", nil],
        [NSArray arrayWithObjects:@"Odśwież", @"rail_refresh", nil], nil];
    NSMutableArray *btns = [NSMutableArray array];
    CGFloat y = 120.0f;
    for (NSUInteger i = 0; i < [defs count]; i++) {
        NSArray *d = [defs objectAtIndex:i];
        UIButton *bt = [self railButton:[d objectAtIndex:0] glyph:[d objectAtIndex:1] tag:(NSInteger)i y:y];
        [rail addSubview:bt];
        [btns addObject:bt];
        y += kBtnH;
    }
    self.buttons = btns;
    UIButton *add = [self railButton:@"Dodaj" glyph:@"rail_plus" tag:6 y:b.size.height - kBtnH - 10.0f];
    add.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    [rail addSubview:add];

    [self addChildViewController:self.nav];
    self.nav.view.frame = CGRectMake(kRailW, 0, b.size.width - kRailW, b.size.height);
    self.nav.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.nav.view];
    [self.nav didMoveToParentViewController:self];
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
        case 0:
            [self.nav popToRootViewControllerAnimated:YES];
            break;
        case 1: {
            M3UChannelsController *t = [self topChannels];
            if (t && [t isFavoritesScreen]) return;
            [self.nav pushViewController:[[M3UChannelsController alloc] initWithFavorites] animated:YES];
            break;
        }
        case 2: [self showCategories:b]; break;
        case 3: {
            M3UChannelsController *t = [self topChannels];
            if (t) [t focusSearch]; else [self info:@"Wyszukiwarka jest na ekranie z kanałami. Otwórz najpierw playlistę."];
            break;
        }
        case 4: {
            M3UChannelsController *t = [self topChannels];
            if (t) [t toggleLayout]; else [self info:@"Układ (lista lub kafelki) zmienia się na ekranie z kanałami."];
            break;
        }
        case 5: {
            M3UChannelsController *r = [self playlistRoot];
            if (r) [r refreshTapped]; else [self info:@"Odświeżać można playlistę, którą masz otwartą."];
            break;
        }
        case 6: {
            [self.nav popToRootViewControllerAnimated:NO];
            UIViewController *root = [self.nav.viewControllers objectAtIndex:0];
            if ([root isKindOfClass:[M3UPlaylistsController class]]) [(M3UPlaylistsController *)root addTapped];
            break;
        }
    }
}

- (void)showCategories:(UIButton *)from
{
    M3UChannelsController *root = [self playlistRoot];
    NSArray *items = [root categoryItems];
    if (!items) { [self info:@"Ta playlista nie ma kategorii. Kategorie pokażą się, gdy lista ma grupy (group-title)."]; return; }
    M3UCategoryPicker *pk = [[M3UCategoryPicker alloc] initWithStyle:UITableViewStylePlain];
    pk.items = items;
    __weak M3URailController *me = self;
    pk.picked = ^(NSInteger row) {
        M3URailController *s = me;
        if (!s) return;
        [s.popover dismissPopoverAnimated:YES];
        s.popover = nil;
        [s.nav popToViewController:root animated:NO];
        [root openCategoryAtIndex:row];
    };
    CGFloat h = 48.0f * (CGFloat)[items count];
    if (h > 520.0f) h = 520.0f;
    UIPopoverController *pop = [[UIPopoverController alloc] initWithContentViewController:pk];
    pop.popoverContentSize = CGSizeMake(320.0f, h);
    self.popover = pop;
    [pop presentPopoverFromRect:from.frame inView:from.superview permittedArrowDirections:UIPopoverArrowDirectionLeft animated:YES];
}

/* Podświetla przycisk ekranu, na którym jesteśmy. */
- (void)navigationController:(UINavigationController *)nc didShowViewController:(UIViewController *)vc animated:(BOOL)animated
{
    NSInteger on = -1;
    if ([vc isKindOfClass:[M3UPlaylistsController class]]) on = 0;
    else if ([vc isKindOfClass:[M3UChannelsController class]] && [(M3UChannelsController *)vc isFavoritesScreen]) on = 1;
    for (UIButton *b in self.buttons) b.selected = (b.tag == on);
}

@end
