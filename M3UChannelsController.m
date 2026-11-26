#import "M3UChannelsController.h"
#import "M3UList.h"
#import "M3UStore.h"
#import "M3ULogos.h"
#import "M3UTheme.h"
#import "M3UTiles.h"
#import "M3UDiag.h"
#import "M3UPlayerController.h"
#import <MediaPlayer/MediaPlayer.h>
#import "M3ULocalization.h"

static NSString *const kLayoutKey = @"layout_grid";
static const CGFloat kListTile = 46.0f;
static const CGFloat kGridTile = 0.0f;       /* 0 = logo w swoich proporcjach */
static const CGFloat kGridMonogram = 76.0f;

@interface M3UChannelsController () <UITableViewDataSource, UITableViewDelegate, UICollectionViewDataSource,
                                     UICollectionViewDelegateFlowLayout, UISearchBarDelegate, UIActionSheetDelegate>
@property (nonatomic, strong) NSDictionary *playlist;
@property (nonatomic, assign) BOOL favoritesMode;
@property (nonatomic, assign) BOOL gridMode;
@property (nonatomic, strong) NSArray *entries;        /* wszystkie kanały */
@property (nonatomic, strong) NSArray *groupNames;     /* nazwy sekcji (gdy brak szukania) */
@property (nonatomic, strong) NSArray *groupRows;      /* tablica tablic M3UEntry */
@property (nonatomic, strong) NSArray *found;          /* wyniki szukania (płaska lista) */
@property (nonatomic, copy) NSString *query;
@property (nonatomic, copy) NSString *message;         /* komunikat na środku (błąd, „brak wyników”) */
@property (nonatomic, strong) UISearchBar *search;
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) UICollectionView *grid;
@property (nonatomic) CGFloat gridWidth;
@property (nonatomic, strong) NSArray *catNames;      /* wszystkie grupy playlisty (nie znikają przy szukaniu) */
@property (nonatomic, strong) NSArray *catRows;
@property (nonatomic, assign) BOOL categoryMode;    /* pokazujemy listę kategorii, nie kanały */
@property (nonatomic, assign) BOOL presetEntries;    /* kanały podane z góry (kategoria / wszystkie) */
@property (nonatomic, assign) BOOL groupLocked;      /* jedna kategoria: nagłówki zbędne */
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) M3UEntry *actionEntry;
@property (nonatomic, strong) MPMoviePlayerViewController *player;
@property (nonatomic, assign) BOOL loading;
@end

@implementation M3UChannelsController

M3U_ROTATE_ANY

- (id)initWithPlaylist:(NSDictionary *)playlist
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.playlist = playlist;
        self.title = [playlist objectForKey:@"name"];
    }
    return self;
}

- (id)initWithEntries:(NSArray *)entries group:(NSString *)group title:(NSString *)title
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.presetEntries = YES;
        self.title = title;
        if (group) {
            self.groupLocked = YES;
            NSMutableArray *only = [NSMutableArray array];
            for (M3UEntry *e in entries) if ([(e.group ?: @"") isEqualToString:group]) [only addObject:e];
            entries = only;
        }
        self.entries = entries;
        [self rebuild];
    }
    return self;
}

- (id)initWithFavorites
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.favoritesMode = YES;
        self.title = L(@"Ulubione");
    }
    return self;
}

- (void)dealloc
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Widok

- (void)viewDidLoad
{
    [super viewDidLoad];
    M3UBreadcrumb(@"ekran kanałów: viewDidLoad start");
    self.gridMode = [[NSUserDefaults standardUserDefaults] boolForKey:kLayoutKey];
    CGRect b = self.view.bounds;
    [self.view addSubview:M3UBackdropView(b)];
    CGFloat sh = 44.0f;

    self.table = [[UITableView alloc] initWithFrame:CGRectMake(0, sh, b.size.width, b.size.height - sh) style:UITableViewStylePlain];
    self.table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.rowHeight = 58.0f;
    M3UStyleTable(self.table);
    self.table.backgroundView = nil;               /* tło jest jedno, pod całym ekranem */
    [self.view addSubview:self.table];

    UICollectionViewFlowLayout *fl = [[UICollectionViewFlowLayout alloc] init];
    /* duże kafelki: logo w górnej części, nazwa pod spodem; liczba kolumn zależy od szerokości ekranu */
    fl.minimumInteritemSpacing = 10.0f;
    fl.minimumLineSpacing = 10.0f;
    fl.sectionInset = UIEdgeInsetsMake(10, 10, 10, 10);
    [self fitTilesIn:fl width:b.size.width];
    self.grid = [[UICollectionView alloc] initWithFrame:CGRectMake(0, sh, b.size.width, b.size.height - sh) collectionViewLayout:fl];
    self.grid.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.grid.backgroundColor = [UIColor clearColor];
    self.grid.alwaysBounceVertical = YES;
    self.grid.dataSource = self;
    self.grid.delegate = self;
    [self.grid registerClass:[M3UTileCell class] forCellWithReuseIdentifier:@"tile"];
    [self.grid registerClass:[M3UTileHeader class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"head"];
    [self.view addSubview:self.grid];

    self.search = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, b.size.width, sh)];
    self.search.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.search.delegate = self;
    self.search.placeholder = L(@"Szukaj kanału");
    self.search.autocorrectionType = UITextAutocorrectionTypeNo;
    self.search.autocapitalizationType = UITextAutocapitalizationTypeNone;
    /* UISearchBar sam nie ma ustawienia wyglądu klawiatury w iOS 6 (to wywalało aplikację), więc ustawiamy je na jego polu tekstowym */
    for (UIView *v in self.search.subviews) {
        if ([v isKindOfClass:[UITextField class]]) ((UITextField *)v).keyboardAppearance = UIKeyboardAppearanceAlert;
    }
    M3UStyleSearchBar(self.search);
    [self.view addSubview:self.search];

    self.messageLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.messageLabel.backgroundColor = [UIColor clearColor];
    self.messageLabel.numberOfLines = 0;
    self.messageLabel.textAlignment = NSTextAlignmentCenter;
    self.messageLabel.textColor = M3USubtleColor();
    self.messageLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.85f];
    self.messageLabel.shadowOffset = CGSizeMake(0, -1);
    self.messageLabel.font = [UIFont systemFontOfSize:15.0f];
    self.messageLabel.hidden = YES;
    [self.view addSubview:self.messageLabel];

    for (UIView *v in [NSArray arrayWithObjects:self.table, self.grid, nil]) {
        UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressed:)];
        lp.minimumPressDuration = 0.6;
        [v addGestureRecognizer:lp];
    }

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(logoLoaded) name:M3ULogoDidLoad object:nil];
    [nc addObserver:self selector:@selector(keyboardChanged:) name:UIKeyboardWillShowNotification object:nil];
    [nc addObserver:self selector:@selector(keyboardChanged:) name:UIKeyboardWillHideNotification object:nil];

    [self applyLayoutMode];
    [self updateNavItems];
    M3UBreadcrumb([NSString stringWithFormat:@"ekran kanałów: viewDidLoad koniec (kafelki=%d)", (int)self.gridMode]);
}

/* Dobiera szerokość kafelków do szerokości ekranu: 2 kolumny w pionie, 3 w poziomie na telefonie, więcej na iPadzie. */
- (void)fitTilesIn:(UICollectionViewFlowLayout *)fl width:(CGFloat)w
{
    int cols = w >= 900.0f ? 5 : (w >= 600.0f ? 4 : (w >= 400.0f ? 3 : 2));
    CGFloat gap = 10.0f;
    CGFloat tw = (CGFloat)(int)((w - gap * (cols + 1)) / cols);
    fl.itemSize = CGSizeMake(tw, 150.0f);
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    UICollectionViewFlowLayout *fl = (UICollectionViewFlowLayout *)self.grid.collectionViewLayout;
    CGFloat w = self.grid.bounds.size.width;
    if (fl && w > 0 && w != self.gridWidth) {
        self.gridWidth = w;
        [self fitTilesIn:fl width:w];
        [fl invalidateLayout];
    }
    [self layoutMessage];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    BOOL grid = [[NSUserDefaults standardUserDefaults] boolForKey:kLayoutKey];      /* mógł się zmienić w Ustawieniach */
    if (grid != self.gridMode) { self.gridMode = grid; [self applyLayoutMode]; [self updateNavItems]; }
    if (self.favoritesMode) {
        [self loadFavorites];
    } else if (!self.entries && !self.loading) {
        [self loadPlaylist];
    } else {
        [self reloadContent];   /* gwiazdki mogły się zmienić */
    }
}

#pragma mark - Układ: lista albo kafelki

- (BOOL)gridActive { return self.gridMode && !self.categoryMode; }

- (void)applyLayoutMode
{
    self.table.hidden = [self gridActive];
    self.grid.hidden = ![self gridActive];
}

- (void)toggleLayout
{
    self.gridMode = !self.gridMode;
    [[NSUserDefaults standardUserDefaults] setBool:self.gridMode forKey:kLayoutKey];
    [self applyLayoutMode];
    [self reloadContent];
    [self updateNavItems];
}

- (void)updateNavItems
{
    /* Ikona pokazuje układ, na który przełączymy (jak w aplikacjach z iOS 6). */
    UIBarButtonItem *layout = [[UIBarButtonItem alloc] initWithImage:M3UBarIcon(self.gridMode ? @"ico_list" : @"ico_grid")
                                                               style:UIBarButtonItemStyleBordered
                                                              target:self action:@selector(toggleLayout)];
    if (self.favoritesMode || self.presetEntries) {
        self.navigationItem.rightBarButtonItem = layout;
        return;
    }
    UIBarButtonItem *second;
    if (self.loading) {
        UIActivityIndicatorView *spin = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        [spin startAnimating];
        second = [[UIBarButtonItem alloc] initWithCustomView:spin];
    } else {
        second = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshTapped)];
    }
    self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:second, layout, nil];
}

#pragma mark - Dane

- (void)setEntriesFromText:(NSString *)text
{
    BOOL hls = NO;
    M3UBreadcrumb([NSString stringWithFormat:@"parsowanie tekstu, znaków: %d", (int)[text length]]);
    NSArray *list = M3UParse(text, &hls);
    M3UBreadcrumb([NSString stringWithFormat:@"sparsowano kanałów: %d (HLS=%d)", (int)[list count], (int)hls]);
    if (hls) {
        M3UEntry *e = [[M3UEntry alloc] init];
        e.name = [self.playlist objectForKey:@"name"];
        e.url = [self.playlist objectForKey:@"url"] ?: @"";
        e.group = @"";
        e.logo = @"";
        list = [e.url length] ? [NSArray arrayWithObject:e] : [NSArray array];
    }
    self.entries = list;
    self.message = [list count] ? nil : L(@"Nie znalazłem w tej liście żadnych kanałów.");
    [self rebuild];
}

- (void)loadFavorites
{
    NSMutableArray *list = [NSMutableArray array];
    for (NSDictionary *d in M3UFavorites()) {
        M3UEntry *e = [[M3UEntry alloc] init];
        e.name = [d objectForKey:@"name"];
        e.url = [d objectForKey:@"url"];
        e.group = [d objectForKey:@"group"] ?: @"";
        e.logo = [d objectForKey:@"logo"] ?: @"";
        [list addObject:e];
    }
    self.entries = list;
    self.message = [list count] ? nil : L(@"Brak ulubionych. Przytrzymaj kanał albo dotknij strzałki obok niego i wybierz „Dodaj do ulubionych”.");
    [self rebuild];
}

- (void)loadPlaylist
{
    NSString *file = [self.playlist objectForKey:@"file"];
    M3UBreadcrumb([NSString stringWithFormat:@"wczytuję playlistę (plik: %@)", file ?: @"nie, adres"]);
    if (file) {
        NSData *data = [NSData dataWithContentsOfFile:[M3UDocumentsPath() stringByAppendingPathComponent:file]];
        if (!data) { self.entries = [NSArray array]; self.message = L(@"Nie mogę odczytać pliku."); [self rebuild]; return; }
        [self setEntriesFromText:M3UDecode(data)];
        return;
    }
    NSString *url = [self.playlist objectForKey:@"url"];
    NSString *cached = M3UCachedText(url);
    if (cached) [self setEntriesFromText:cached];
    [self fetch:url silent:cached != nil];
}

- (void)refreshTapped
{
    if (self.loading || self.favoritesMode || self.presetEntries) return;
    NSString *file = [self.playlist objectForKey:@"file"];
    if (file) { [self loadPlaylist]; return; }
    [self fetch:[self.playlist objectForKey:@"url"] silent:NO];
}

- (void)fetch:(NSString *)url silent:(BOOL)silent
{
    self.loading = YES;
    [self updateNavItems];
    if (!silent && ![self.entries count]) { self.message = L(@"Pobieram listę…"); [self reloadContent]; }
    __weak M3UChannelsController *weakSelf = self;
    M3UFetch(url, ^(NSData *data, NSString *error) {
        M3UChannelsController *me = weakSelf;
        if (!me) return;
        me.loading = NO;
        [me updateNavItems];
        if (!data) {
            if (![me.entries count]) { me.message = error; [me reloadContent]; }
            else if (!silent) [[[UIAlertView alloc] initWithTitle:nil message:error delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
            return;
        }
        NSString *text = M3UDecode(data);
        M3USaveCachedText(url, text);
        [me setEntriesFromText:text];
    });
}

/* Dzieli kanały na grupy albo filtruje po wpisanym tekście (bez polskich znaków i wielkości liter). */
- (void)rebuild
{
    NSString *q = self.query;
    if ([q length] >= 1) {
        NSStringCompareOptions o = NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch;
        NSMutableArray *hits = [NSMutableArray array];
        for (M3UEntry *e in self.entries) {
            if ([e.name rangeOfString:q options:o].location != NSNotFound ||
                [e.group rangeOfString:q options:o].location != NSNotFound) {
                [hits addObject:e];
                if ([hits count] >= 300) break;
            }
        }
        self.found = hits;
        self.categoryMode = NO;
        self.groupNames = nil;
        self.groupRows = nil;
        if ([self.entries count]) self.message = [hits count] ? nil : L(@"Brak wyników.");
    } else {
        self.found = nil;
        NSMutableArray *names = [NSMutableArray array];
        NSMutableDictionary *byName = [NSMutableDictionary dictionary];
        for (M3UEntry *e in self.entries) {
            NSString *g = [e.group length] ? e.group : @"";
            NSMutableArray *rows = [byName objectForKey:g];
            if (!rows) { rows = [NSMutableArray array]; [byName setObject:rows forKey:g]; [names addObject:g]; }
            [rows addObject:e];
        }
        NSMutableArray *rowsList = [NSMutableArray array];
        for (NSString *g in names) [rowsList addObject:[byName objectForKey:g]];
        self.groupNames = names;
        self.groupRows = rowsList;
        self.catNames = names;
        self.catRows = rowsList;
        self.categoryMode = !self.favoritesMode && !self.presetEntries && [names count] >= 2;
        if ([self.entries count]) self.message = nil;
    }
    M3UBreadcrumb([NSString stringWithFormat:@"grupy: %d, odświeżam widok", (int)[self.groupNames count]]);
    [self reloadContent];
    M3UBreadcrumb(@"widok odświeżony");
}

/* Odświeża tylko widok, który jest teraz na ekranie. */
- (void)reloadContent
{
    if (!self.isViewLoaded) return;
    [self applyLayoutMode];
    if ([self gridActive]) [self.grid reloadData]; else [self.table reloadData];
    [self layoutMessage];
}

- (void)layoutMessage
{
    if (!self.messageLabel) return;
    self.messageLabel.hidden = ![self.message length];
    if (self.messageLabel.hidden) return;
    self.messageLabel.text = self.message;
    CGFloat w = self.view.bounds.size.width - 40.0f;
    CGSize s = [self.messageLabel sizeThatFits:CGSizeMake(w, 400.0f)];
    self.messageLabel.frame = CGRectMake(20, 44.0f + 36.0f, w, s.height);
}

- (NSInteger)sectionCount { return (self.found || self.categoryMode) ? 1 : (NSInteger)[self.groupNames count]; }

- (NSArray *)rowsInSection:(NSInteger)s
{
    if (self.found) return self.found;
    return (s >= 0 && s < (NSInteger)[self.groupRows count]) ? [self.groupRows objectAtIndex:(NSUInteger)s] : nil;
}

- (M3UEntry *)entryAtSection:(NSInteger)s row:(NSInteger)r
{
    NSArray *rows = [self rowsInSection:s];
    return (r >= 0 && r < (NSInteger)[rows count]) ? [rows objectAtIndex:(NSUInteger)r] : nil;
}

- (NSString *)headerText:(NSInteger)s
{
    if (self.found || self.categoryMode || self.groupLocked || s >= (NSInteger)[self.groupNames count]) return nil;
    NSString *g = [self.groupNames objectAtIndex:(NSUInteger)s];
    /* Jedna, nienazwana grupa nie potrzebuje nagłówka. */
    if ([self.groupNames count] == 1 && ![g length]) return nil;
    return [g length] ? g : L(@"Bez grupy");
}

#pragma mark - Ikonki kanałów

/* Logo, gdy jest; do czasu pobrania (albo gdy go brak) płytka z inicjałami. */
- (UIImage *)tileFor:(M3UEntry *)e side:(CGFloat)side
{
    if ([e.logo length]) {
        UIImage *t = M3UCachedLogoTile(e.logo, side);
        if (t) return t;
        if (!M3ULogoFailed(e.logo)) {
            NSString *url = e.logo;
            __weak M3UChannelsController *weakSelf = self;
            M3URequestLogo(url, side, ^BOOL{
                M3UChannelsController *me = weakSelf;
                if (!me || !me.isViewLoaded || !me.view.window) return NO;
                return [me isLogoVisible:url];
            });
        }
    }
    return M3UMonogramTile(e.name, side > 0 ? side : kGridMonogram);
}

- (BOOL)isLogoVisible:(NSString *)url
{
    if (self.categoryMode) return NO;
    if (self.gridMode) {
        for (NSIndexPath *ip in [self.grid indexPathsForVisibleItems])
            if ([[self entryAtSection:ip.section row:ip.item].logo isEqualToString:url]) return YES;
    } else {
        for (NSIndexPath *ip in [self.table indexPathsForVisibleRows])
            if ([[self entryAtSection:ip.section row:ip.row].logo isEqualToString:url]) return YES;
    }
    return NO;
}

/* Gdy któreś logo się pobierze, podmieniamy ikonki w widocznych wierszach (bez przeładowania listy). */
- (void)logoLoaded
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshVisibleLogos) object:nil];
    [self performSelector:@selector(refreshVisibleLogos) withObject:nil afterDelay:0.1];
}

- (void)refreshVisibleLogos
{
    if (!self.isViewLoaded || self.categoryMode) return;
    if (self.gridMode) {
        for (UICollectionViewCell *c in [self.grid visibleCells]) {
            NSIndexPath *ip = [self.grid indexPathForCell:c];
            M3UEntry *e = ip ? [self entryAtSection:ip.section row:ip.item] : nil;
            UIImage *t = [e.logo length] ? M3UCachedLogoTile(e.logo, kGridTile) : nil;
            if (t) [(M3UTileCell *)c setPlate:t];
        }
    } else {
        for (UITableViewCell *c in [self.table visibleCells]) {
            NSIndexPath *ip = [self.table indexPathForCell:c];
            M3UEntry *e = ip ? [self entryAtSection:ip.section row:ip.row] : nil;
            UIImage *t = [e.logo length] ? M3UCachedLogoTile(e.logo, kListTile) : nil;
            if (t && c.imageView.image != t) c.imageView.image = t;
        }
    }
}

#pragma mark - Szukanie i klawiatura

- (void)searchBar:(UISearchBar *)bar textDidChange:(NSString *)text
{
    NSString *t = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    self.query = [t length] ? t : nil;
    [self rebuild];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)bar { [bar resignFirstResponder]; }

- (void)scrollViewWillBeginDragging:(UIScrollView *)sv { [self.search resignFirstResponder]; }

/* Klawiatura zasłaniałaby dół listy, więc dodajemy margines. */
- (void)keyboardChanged:(NSNotification *)n
{
    if (!self.view.window) return;
    CGFloat h = 0;
    if ([[n name] isEqualToString:UIKeyboardWillShowNotification]) {
        CGRect kb = [[[n userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
        CGRect inView = [self.view convertRect:[self.view.window convertRect:kb fromWindow:nil] fromView:nil];
        h = MAX(0.0f, CGRectGetMaxY(self.view.bounds) - inView.origin.y);
    }
    UIEdgeInsets in = UIEdgeInsetsMake(0, 0, h, 0);
    self.table.contentInset = in;
    self.table.scrollIndicatorInsets = in;
    self.grid.contentInset = in;
    self.grid.scrollIndicatorInsets = in;
}

#pragma mark - Lista (tabela)

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return [self sectionCount]; }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s
{
    if (self.categoryMode) return 2 + (NSInteger)[self.groupNames count];
    return (NSInteger)[[self rowsInSection:s] count];
}

#pragma mark - Kategorie

/* Dla paska bocznego na iPadzie. */
- (BOOL)isFavoritesScreen { return self.favoritesMode; }
- (BOOL)isPlaylistRoot { return !self.favoritesMode && !self.presetEntries; }

- (NSArray *)categoryItems
{
    if (![self isPlaylistRoot] || [self.catNames count] < 2) return nil;
    NSMutableArray *out = [NSMutableArray array];
    for (NSInteger r = 0; r < 2 + (NSInteger)[self.catNames count]; r++)
        [out addObject:[NSDictionary dictionaryWithObjectsAndKeys:[self categoryName:r], @"name",
                        [NSNumber numberWithInteger:[self categoryCount:r]], @"count", nil]];
    return out;
}

- (void)openCategoryAtIndex:(NSInteger)r
{
    if (r >= 0 && r < 2 + (NSInteger)[self.catNames count]) [self openCategory:r];
}

- (void)focusSearch { [self.search becomeFirstResponder]; }

/* Nazwa, liczba kanałów i płytka wiersza kategorii: 0 = Ulubione, 1 = Wszystkie, dalej grupy z playlisty. */
- (NSString *)categoryName:(NSInteger)r
{
    if (r == 0) return L(@"Ulubione");
    if (r == 1) return L(@"Wszystkie kanały");
    NSString *g = [self.catNames objectAtIndex:(NSUInteger)(r - 2)];
    return [g length] ? g : L(@"Bez grupy");
}

- (NSInteger)categoryCount:(NSInteger)r
{
    if (r == 0) return (NSInteger)[M3UFavorites() count];
    if (r == 1) return (NSInteger)[self.entries count];
    return (NSInteger)[[self.catRows objectAtIndex:(NSUInteger)(r - 2)] count];
}

- (void)openCategory:(NSInteger)r
{
    UIViewController *vc;
    if (r == 0) {
        vc = [[M3UChannelsController alloc] initWithFavorites];
    } else if (r == 1) {
        vc = [[M3UChannelsController alloc] initWithEntries:self.entries group:nil title:L(@"Wszystkie kanały")];
    } else {
        NSString *g = [self.catNames objectAtIndex:(NSUInteger)(r - 2)];
        vc = [[M3UChannelsController alloc] initWithEntries:self.entries group:g title:[self categoryName:r]];
    }
    M3UBreadcrumb([NSString stringWithFormat:@"otwieram kategorię: %@", [self categoryName:r]]);
    [self.navigationController pushViewController:vc animated:YES];
}


- (UIView *)tableView:(UITableView *)tv viewForHeaderInSection:(NSInteger)s
{
    NSString *t = [self headerText:s];
    return t ? M3UHeaderView(t) : nil;
}

- (CGFloat)tableView:(UITableView *)tv heightForHeaderInSection:(NSInteger)s
{
    return [self headerText:s] ? 22.0f : 0.0f;
}

- (CGFloat)tableView:(UITableView *)tv heightForFooterInSection:(NSInteger)s { return 0.0f; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip
{
    if (self.categoryMode) {
        UITableViewCell *cc = [tv dequeueReusableCellWithIdentifier:@"cat"];
        if (!cc) cc = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cat"];
        M3UStyleCell(cc);
        NSString *nm = [self categoryName:ip.row];
        cc.imageView.image = ip.row == 0 ? M3UGlyphTile(1, kListTile) : M3UMonogramTile(nm, kListTile);
        cc.textLabel.text = nm;
        cc.detailTextLabel.text = [NSString stringWithFormat:@"%d", (int)[self categoryCount:ip.row]];
        cc.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cc;
    }
    if (ip.row == 0) M3UBreadcrumb([NSString stringWithFormat:@"wiersz listy: sekcja %d, pierwszy", (int)ip.section]);
    static NSString *ident = @"k";
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:ident];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:ident];
    M3UEntry *e = [self entryAtSection:ip.section row:ip.row];
    M3UStyleCell(cell);
    cell.imageView.image = [self tileFor:e side:kListTile];
    BOOL fav = M3UIsFavorite(e.url);
    cell.textLabel.text = e.name;
    UIImageView *star = (UIImageView *)[cell.contentView viewWithTag:79];
    if (!star) {                                    /* znacznik ulubionych: rysowana zakładka przy prawej krawędzi */
        star = [[UIImageView alloc] initWithImage:M3UFavoriteMark(22.0f)];
        star.tag = 79;
        star.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        star.frame = CGRectMake(cell.contentView.bounds.size.width - 22.0f, 0.0f, 13.0f, 22.0f);
        [cell.contentView addSubview:star];
    }
    star.hidden = !fav;
    cell.detailTextLabel.text = (self.found || self.favoritesMode) && [e.group length] ? e.group : nil;
    cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip
{
    [tv deselectRowAtIndexPath:ip animated:YES];
    [self.search resignFirstResponder];
    if (self.categoryMode) { [self openCategory:ip.row]; return; }
    M3UEntry *e = [self entryAtSection:ip.section row:ip.row];
    if (e) [self play:e];
}

- (void)tableView:(UITableView *)tv accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)ip
{
    M3UEntry *e = [self entryAtSection:ip.section row:ip.row];
    if (e) [self showActions:e];
}

#pragma mark - Kafelki (siatka)

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)cv { return [self sectionCount]; }

- (NSInteger)collectionView:(UICollectionView *)cv numberOfItemsInSection:(NSInteger)s { return (NSInteger)[[self rowsInSection:s] count]; }

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)ip
{
    if (ip.item == 0) M3UBreadcrumb([NSString stringWithFormat:@"kafelek: sekcja %d, pierwszy", (int)ip.section]);
    M3UTileCell *cell = [cv dequeueReusableCellWithReuseIdentifier:@"tile" forIndexPath:ip];
    M3UEntry *e = [self entryAtSection:ip.section row:ip.item];
    [cell setTitle:e.name plate:[self tileFor:e side:kGridTile] favorite:M3UIsFavorite(e.url)];
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)cv viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)ip
{
    M3UTileHeader *h = [cv dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"head" forIndexPath:ip];
    [h setTitle:[self headerText:ip.section] ?: @""];
    return h;
}

- (CGSize)collectionView:(UICollectionView *)cv layout:(UICollectionViewLayout *)layout referenceSizeForHeaderInSection:(NSInteger)s
{
    return [self headerText:s] ? CGSizeMake(cv.bounds.size.width, 22.0f) : CGSizeZero;
}

- (void)collectionView:(UICollectionView *)cv didSelectItemAtIndexPath:(NSIndexPath *)ip
{
    [self.search resignFirstResponder];
    M3UEntry *e = [self entryAtSection:ip.section row:ip.item];
    if (e) [self play:e];
}

#pragma mark - Menu kanału

- (void)longPressed:(UILongPressGestureRecognizer *)g
{
    if (g.state != UIGestureRecognizerStateBegan || self.categoryMode) return;
    CGPoint p = [g locationInView:g.view];
    M3UEntry *e = nil;
    if (g.view == self.table) {
        NSIndexPath *ip = [self.table indexPathForRowAtPoint:p];
        if (ip) e = [self entryAtSection:ip.section row:ip.row];
    } else {
        NSIndexPath *ip = [self.grid indexPathForItemAtPoint:p];
        if (ip) e = [self entryAtSection:ip.section row:ip.item];
    }
    if (e) [self showActions:e];
}

- (void)showActions:(M3UEntry *)e
{
    [self.search resignFirstResponder];
    self.actionEntry = e;
    BOOL fav = M3UIsFavorite(e.url);
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:e.name delegate:self cancelButtonTitle:L(@"Anuluj")
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:fav ? L(@"Usuń z ulubionych") : L(@"Dodaj do ulubionych"),
                                                                L(@"Kopiuj adres"), L(@"Szczegóły"), nil];
    sheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;
    [sheet showInView:self.view.window];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)i
{
    M3UEntry *e = self.actionEntry;
    if (!e || i == sheet.cancelButtonIndex) return;
    if (i == 0) {
        M3UToggleFavorite(e.name, e.url, e.group, e.logo);
        if (self.favoritesMode) [self loadFavorites]; else [self reloadContent];
    } else if (i == 1) {
        [UIPasteboard generalPasteboard].string = e.url;
    } else if (i == 2) {
        NSString *msg = [NSString stringWithFormat:L(@"Grupa: %@\n\nAdres:\n%@\n\nLogo:\n%@\n%@"),
                         [e.group length] ? e.group : L(@"brak"), e.url,
                         [e.logo length] ? e.logo : L(@"brak"), M3ULogoStatus(e.logo)];
        [[[UIAlertView alloc] initWithTitle:e.name message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    }
}

#pragma mark - Odtwarzanie

- (void)play:(M3UEntry *)e
{
    NSURL *u = [NSURL URLWithString:e.url];
    NSString *scheme = [[u scheme] lowercaseString];
    if (!u || !([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"])) {
        [self showError:[NSString stringWithFormat:L(@"iOS 6 odtworzy tylko strumienie HLS przez http lub https. Ten kanał używa „%@”."), scheme ?: @"?"]];
        return;
    }
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {          /* iPad: własny odtwarzacz z panelami (lista kanałów, program) */
        NSArray *flat = self.found;
        if (!flat) {
            NSMutableArray *all = [NSMutableArray array];
            for (NSArray *r in self.groupRows) [all addObjectsFromArray:r];
            flat = all;
        }
        if (![flat count]) flat = [NSArray arrayWithObject:e];
        M3UPlayerController *pc = [[M3UPlayerController alloc] initWithEntries:flat current:e];
        [self presentViewController:pc animated:YES completion:nil];
        return;
    }
    MPMoviePlayerViewController *mp = [[MPMoviePlayerViewController alloc] initWithContentURL:u];
    mp.moviePlayer.movieSourceType = MPMovieSourceTypeStreaming;
    self.player = mp;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackFinished:)
                                                 name:MPMoviePlayerPlaybackDidFinishNotification object:mp.moviePlayer];
    [self presentMoviePlayerViewControllerAnimated:mp];
}

- (void)playbackFinished:(NSNotification *)n
{
    NSNumber *reason = [[n userInfo] objectForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerPlaybackDidFinishNotification object:nil];
    self.player = nil;
    if ([reason intValue] == MPMovieFinishReasonPlaybackError) {
        [self dismissMoviePlayerViewControllerAnimated];
        [self showError:L(@"Nie udało się odtworzyć kanału. iOS 6 obsługuje tylko HLS z obrazem H.264; kanał mógł też wymagać logowania albo być wyłączony.")];
    }
}

- (void)showError:(NSString *)msg
{
    [[[UIAlertView alloc] initWithTitle:nil message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
}

@end
