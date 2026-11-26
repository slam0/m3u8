#import "M3UChannelsController.h"
#import "M3UList.h"
#import "M3UStore.h"
#import <MediaPlayer/MediaPlayer.h>

@interface M3UChannelsController () <UISearchBarDelegate, UIActionSheetDelegate>
@property (nonatomic, strong) NSDictionary *playlist;
@property (nonatomic, assign) BOOL favoritesMode;
@property (nonatomic, strong) NSArray *entries;        /* wszystkie kanały */
@property (nonatomic, strong) NSArray *groupNames;     /* nazwy sekcji (gdy brak szukania) */
@property (nonatomic, strong) NSArray *groupRows;      /* tablica tablic M3UEntry */
@property (nonatomic, strong) NSArray *found;          /* wyniki szukania (płaska lista) */
@property (nonatomic, copy) NSString *query;
@property (nonatomic, copy) NSString *message;         /* błąd albo „brak kanałów” pod listą */
@property (nonatomic, strong) UISearchBar *search;
@property (nonatomic, strong) M3UEntry *actionEntry;
@property (nonatomic, strong) MPMoviePlayerViewController *player;
@property (nonatomic, assign) BOOL loading;
@end

@implementation M3UChannelsController

- (id)initWithPlaylist:(NSDictionary *)playlist
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.playlist = playlist;
        self.title = [playlist objectForKey:@"name"];
    }
    return self;
}

- (id)initWithFavorites
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.favoritesMode = YES;
        self.title = @"Ulubione";
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Widok

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.search = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    self.search.delegate = self;
    self.search.placeholder = @"Szukaj kanału";
    self.search.autocorrectionType = UITextAutocorrectionTypeNo;
    self.search.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.search.barStyle = UIBarStyleBlack;
    self.tableView.tableHeaderView = self.search;
    if (!self.favoritesMode) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                               target:self action:@selector(refreshTapped)];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (self.favoritesMode) {
        [self loadFavorites];
    } else if (!self.entries && !self.loading) {
        [self loadPlaylist];
    } else {
        [self.tableView reloadData];   /* gwiazdki mogły się zmienić */
    }
}

#pragma mark - Dane

- (void)setEntriesFromText:(NSString *)text
{
    BOOL hls = NO;
    NSArray *list = M3UParse(text, &hls);
    if (hls) {
        M3UEntry *e = [[M3UEntry alloc] init];
        e.name = [self.playlist objectForKey:@"name"];
        e.url = [self.playlist objectForKey:@"url"] ?: @"";
        e.group = @"";
        e.logo = @"";
        list = [e.url length] ? [NSArray arrayWithObject:e] : [NSArray array];
    }
    [self setEntries:list];
    self.message = [list count] ? nil : @"Nie znalazłem w tej liście żadnych kanałów.";
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
        e.logo = @"";
        [list addObject:e];
    }
    self.entries = list;
    self.message = [list count] ? nil : @"Brak ulubionych. Dotknij strzałki obok kanału i wybierz „Dodaj do ulubionych”.";
    [self rebuild];
}

- (void)loadPlaylist
{
    NSString *file = [self.playlist objectForKey:@"file"];
    if (file) {
        NSData *data = [NSData dataWithContentsOfFile:[M3UDocumentsPath() stringByAppendingPathComponent:file]];
        if (!data) { self.entries = [NSArray array]; self.message = @"Nie mogę odczytać pliku."; [self rebuild]; return; }
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
    if (self.loading) return;
    NSString *file = [self.playlist objectForKey:@"file"];
    if (file) { [self loadPlaylist]; return; }
    [self fetch:[self.playlist objectForKey:@"url"] silent:NO];
}

- (void)fetch:(NSString *)url silent:(BOOL)silent
{
    self.loading = YES;
    UIActivityIndicatorView *spin = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    [spin startAnimating];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:spin];
    if (!silent && ![self.entries count]) { self.message = @"Pobieram listę…"; [self reloadTable]; }
    __weak M3UChannelsController *weakSelf = self;
    M3UFetch(url, ^(NSData *data, NSString *error) {
        M3UChannelsController *me = weakSelf;
        if (!me) return;
        me.loading = NO;
        me.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                              target:me action:@selector(refreshTapped)];
        if (!data) {
            if (![me.entries count]) { me.message = error; [me reloadTable]; }
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
        self.groupNames = nil;
        self.groupRows = nil;
        if ([self.entries count]) self.message = [hits count] ? nil : @"Brak wyników.";
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
        if ([self.entries count]) self.message = nil;
    }
    [self reloadTable];
}

/* Komunikat (błąd, „brak wyników”) pokazujemy pod listą, także gdy nie ma żadnej sekcji. */
- (void)reloadTable
{
    [self.tableView reloadData];
    self.tableView.tableFooterView = self.message ? [self messageView] : nil;
}

- (M3UEntry *)entryAt:(NSIndexPath *)ip
{
    if (self.found) return [self.found objectAtIndex:(NSUInteger)ip.row];
    return [[self.groupRows objectAtIndex:(NSUInteger)ip.section] objectAtIndex:(NSUInteger)ip.row];
}

#pragma mark - Szukanie

- (void)searchBar:(UISearchBar *)bar textDidChange:(NSString *)text
{
    NSString *t = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    self.query = [t length] ? t : nil;
    [self rebuild];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)bar { [bar resignFirstResponder]; }

- (void)scrollViewWillBeginDragging:(UIScrollView *)sv { [self.search resignFirstResponder]; }

#pragma mark - Tabela

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv
{
    return self.found ? 1 : (NSInteger)[self.groupNames count];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s
{
    if (self.found) return (NSInteger)[self.found count];
    return (NSInteger)[[self.groupRows objectAtIndex:(NSUInteger)s] count];
}

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s
{
    if (self.found) return nil;
    NSString *g = [self.groupNames objectAtIndex:(NSUInteger)s];
    /* Jedna, nienazwana grupa nie potrzebuje nagłówka. */
    if ([self.groupNames count] == 1 && ![g length]) return nil;
    return [g length] ? g : @"Bez grupy";
}

- (UIView *)messageView
{
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(20, 10, 280, 70)];
    l.text = self.message;
    l.numberOfLines = 0;
    l.textAlignment = NSTextAlignmentCenter;
    l.textColor = [UIColor grayColor];
    l.backgroundColor = [UIColor clearColor];
    l.font = [UIFont systemFontOfSize:15];
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 90)];
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [v addSubview:l];
    return v;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip
{
    static NSString *ident = @"k";
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:ident];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:ident];
    M3UEntry *e = [self entryAt:ip];
    BOOL fav = M3UIsFavorite(e.url);
    cell.textLabel.text = fav ? [@"★ " stringByAppendingString:e.name] : e.name;
    cell.detailTextLabel.text = (self.found || self.favoritesMode) && [e.group length] ? e.group : nil;
    cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip
{
    [tv deselectRowAtIndexPath:ip animated:YES];
    [self.search resignFirstResponder];
    [self play:[self entryAt:ip]];
}

- (void)tableView:(UITableView *)tv accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)ip
{
    [self.search resignFirstResponder];
    self.actionEntry = [self entryAt:ip];
    BOOL fav = M3UIsFavorite(self.actionEntry.url);
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:self.actionEntry.name delegate:self cancelButtonTitle:@"Anuluj"
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:fav ? @"Usuń z ulubionych" : @"Dodaj do ulubionych", @"Kopiuj adres", nil];
    [sheet showInView:self.view.window];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)i
{
    M3UEntry *e = self.actionEntry;
    if (!e || i == sheet.cancelButtonIndex) return;
    if (i == 0) {
        M3UToggleFavorite(e.name, e.url, e.group);
        if (self.favoritesMode) [self loadFavorites]; else [self.tableView reloadData];
    } else if (i == 1) {
        [UIPasteboard generalPasteboard].string = e.url;
    }
}

#pragma mark - Odtwarzanie

- (void)play:(M3UEntry *)e
{
    NSURL *u = [NSURL URLWithString:e.url];
    NSString *scheme = [[u scheme] lowercaseString];
    if (!u || !([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"])) {
        [self showError:[NSString stringWithFormat:@"iOS 6 odtworzy tylko strumienie HLS przez http lub https. Ten kanał używa „%@”.", scheme ?: @"?"]];
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
        [self showError:@"Nie udało się odtworzyć kanału. iOS 6 obsługuje tylko HLS z obrazem H.264; kanał mógł też wymagać logowania albo być wyłączony."];
    }
}

- (void)showError:(NSString *)msg
{
    [[[UIAlertView alloc] initWithTitle:nil message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
}

@end
