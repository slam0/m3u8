#import "M3UMediaController.h"
#import "M3UPortal.h"
#import "M3UTheme.h"
#import "M3ULocalization.h"
#import "M3UDiag.h"
#import <MediaPlayer/MediaPlayer.h>

#pragma mark - Kafelek z plakatem

@interface M3UPosterCell : UICollectionViewCell
- (void)setTitle:(NSString *)title year:(NSString *)year poster:(UIImage *)poster;
- (void)setPoster:(UIImage *)poster;
@end

@implementation M3UPosterCell {
    UIImageView *_card, *_poster;
    UILabel *_title, *_year;
}

- (id)initWithFrame:(CGRect)f
{
    self = [super initWithFrame:f];
    if (!self) return nil;
    self.backgroundColor = [UIColor clearColor];
    _card = [[UIImageView alloc] initWithImage:[M3UImg(@"tile_card") resizableImageWithCapInsets:UIEdgeInsetsMake(14, 14, 14, 14)]];
    [self.contentView addSubview:_card];
    _poster = [[UIImageView alloc] initWithFrame:CGRectZero];
    _poster.contentMode = UIViewContentModeScaleAspectFill;
    _poster.clipsToBounds = YES;
    _poster.backgroundColor = [UIColor colorWithRed:0.05f green:0.12f blue:0.30f alpha:1.0f];
    [self.contentView addSubview:_poster];
    _title = [[UILabel alloc] initWithFrame:CGRectZero];
    _title.backgroundColor = [UIColor clearColor];
    _title.textColor = M3UTextColor();
    _title.shadowColor = M3UShadowColor();
    _title.shadowOffset = M3UShadowOffset();
    _title.font = [UIFont boldSystemFontOfSize:12.0f];
    _title.textAlignment = NSTextAlignmentCenter;
    _title.numberOfLines = 2;
    _title.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.contentView addSubview:_title];
    _year = [[UILabel alloc] initWithFrame:CGRectZero];
    _year.backgroundColor = [UIColor clearColor];
    _year.textColor = M3USubtleColor();
    _year.font = [UIFont systemFontOfSize:11.0f];
    _year.textAlignment = NSTextAlignmentCenter;
    [self.contentView addSubview:_year];
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect b = self.contentView.bounds;
    _card.frame = b;
    CGFloat pw = b.size.width - 16.0f;
    _poster.frame = CGRectMake(8, 8, pw, (CGFloat)(int)(pw * 1.45f));
    _title.frame = CGRectMake(6, CGRectGetMaxY(_poster.frame) + 4, b.size.width - 12, 30);
    _year.frame = CGRectMake(6, b.size.height - 22, b.size.width - 12, 14);
}

- (void)setTitle:(NSString *)title year:(NSString *)year poster:(UIImage *)poster
{
    _title.text = title;
    _year.text = year;
    _poster.image = poster;
}

- (void)setPoster:(UIImage *)poster { _poster.image = poster; }

- (void)setHighlighted:(BOOL)h
{
    [super setHighlighted:h];
    self.contentView.alpha = h ? 0.65f : 1.0f;
}

@end

#pragma mark - Kontroler

@interface M3UMediaController () <UITableViewDataSource, UITableViewDelegate, UICollectionViewDataSource, UICollectionViewDelegate, UISearchBarDelegate>
@property (nonatomic, strong) M3UPortal *portal;
@property (nonatomic, copy) NSDictionary *baseReq;          /* polecenie tego ekranu (bez klucza) */
@property (nonatomic, copy) NSDictionary *searchTemplate;   /* polecenie szukania z ekranu głównego, {USERINPUT} = fraza */
@property (nonatomic, copy) NSDictionary *detail;           /* odpowiedź „film”: ekran z opisem i odcinkami */
@property (nonatomic, strong) NSMutableArray *items;
@property (nonatomic, copy) NSDictionary *nextReq;
@property (nonatomic) BOOL loading, exhausted, loadedOnce, gridMode, busy;
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) UICollectionView *grid;
@property (nonatomic, strong) UISearchBar *search;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIView *header;
@property (nonatomic, strong) UIImageView *headerPoster;
@property (nonatomic) CGFloat laidOutWidth;
@property (nonatomic, strong) MPMoviePlayerViewController *player;
@end

@implementation M3UMediaController

M3U_ROTATE_ANY

- (id)initWithPortal:(M3UPortal *)portal request:(NSDictionary *)req title:(NSString *)title search:(NSDictionary *)tpl detail:(NSDictionary *)detail
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self) return nil;
    self.portal = portal;
    self.baseReq = req ?: [NSDictionary dictionary];
    self.searchTemplate = tpl;
    self.detail = detail;
    self.title = title;
    self.items = [NSMutableArray array];
    return self;
}

- (id)initWithPlaylist:(NSDictionary *)pl
{
    M3UPortal *p = [M3UPortal portalFromLink:[pl objectForKey:@"url"]];
    self = [self initWithPortal:p request:nil title:[pl objectForKey:@"name"] search:nil detail:nil];
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
    CGRect b = self.view.bounds;
    [self.view addSubview:M3UBackdropView(b)];
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:L(@"Wstecz") style:UIBarButtonItemStyleBordered target:nil action:nil];
    CGFloat sh = self.detail ? 0.0f : 44.0f;

    self.table = [[UITableView alloc] initWithFrame:CGRectMake(0, sh, b.size.width, b.size.height - sh) style:UITableViewStylePlain];
    self.table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.rowHeight = 56.0f;
    M3UStyleTable(self.table);
    self.table.backgroundView = nil;
    [self.view addSubview:self.table];

    UICollectionViewFlowLayout *fl = [[UICollectionViewFlowLayout alloc] init];
    fl.minimumInteritemSpacing = 10.0f;
    fl.minimumLineSpacing = 10.0f;
    fl.sectionInset = UIEdgeInsetsMake(10, 10, 10, 10);
    self.grid = [[UICollectionView alloc] initWithFrame:CGRectMake(0, sh, b.size.width, b.size.height - sh) collectionViewLayout:fl];
    self.grid.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.grid.backgroundColor = [UIColor clearColor];
    self.grid.alwaysBounceVertical = YES;
    self.grid.dataSource = self;
    self.grid.delegate = self;
    self.grid.hidden = YES;
    [self.grid registerClass:[M3UPosterCell class] forCellWithReuseIdentifier:@"poster"];
    [self.view addSubview:self.grid];

    if (!self.detail) {
        self.search = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, b.size.width, sh)];
        self.search.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.search.delegate = self;
        self.search.placeholder = L(@"Szukaj filmu");
        self.search.autocorrectionType = UITextAutocorrectionTypeNo;
        self.search.autocapitalizationType = UITextAutocapitalizationTypeNone;
        for (UIView *v in self.search.subviews)
            if ([v isKindOfClass:[UITextField class]]) ((UITextField *)v).keyboardAppearance = UIKeyboardAppearanceAlert;
        M3UStyleSearchBar(self.search);
        [self.view addSubview:self.search];
    }

    self.messageLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.messageLabel.backgroundColor = [UIColor clearColor];
    self.messageLabel.numberOfLines = 0;
    self.messageLabel.textAlignment = NSTextAlignmentCenter;
    self.messageLabel.textColor = M3USubtleColor();
    self.messageLabel.shadowColor = M3UShadowColor();
    self.messageLabel.shadowOffset = M3UShadowOffset();
    self.messageLabel.font = [UIFont systemFontOfSize:15.0f];
    self.messageLabel.hidden = YES;
    [self.view addSubview:self.messageLabel];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];

    if (!self.portal) {
        [self showMessage:L(@"To nie jest poprawny link mediateki.")];
        return;
    }
    if (self.detail) {
        self.items = [NSMutableArray arrayWithArray:[self.detail objectForKey:@"items"] ?: [NSArray array]];
        self.loadedOnce = YES;
        self.exhausted = YES;
        [self buildHeader];
        [self.table reloadData];
    } else {
        [self loadMore];
    }
}

- (void)fitGrid
{
    UICollectionViewFlowLayout *fl = (UICollectionViewFlowLayout *)self.grid.collectionViewLayout;
    CGFloat w = self.grid.bounds.size.width;
    int cols = w >= 900.0f ? 6 : (w >= 440.0f ? 5 : 3);
    CGFloat gap = 10.0f;
    CGFloat tw = (CGFloat)(int)((w - gap * (cols + 1)) / cols);
    CGFloat ph = (CGFloat)(int)((tw - 16.0f) * 1.45f);
    fl.itemSize = CGSizeMake(tw, 8 + ph + 4 + 30 + 28);
    [fl invalidateLayout];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;
    if (w > 0 && w != self.laidOutWidth) {
        self.laidOutWidth = w;
        [self fitGrid];
        if (self.detail) [self buildHeader];
    }
    self.spinner.center = CGPointMake(w / 2.0f, self.view.bounds.size.height / 2.0f);
    self.messageLabel.frame = CGRectMake(20, 120, w - 40, 120);
}

- (void)showMessage:(NSString *)msg
{
    self.messageLabel.text = msg;
    self.messageLabel.hidden = (msg == nil);
}

- (void)alert:(NSString *)msg
{
    [[[UIAlertView alloc] initWithTitle:nil message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
}

#pragma mark - Ekran filmu (nagłówek z opisem)

- (void)buildHeader
{
    NSDictionary *d = self.detail;
    CGFloat w = self.table.bounds.size.width;
    if (w <= 0) w = self.view.bounds.size.width;
    UIView *h = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 100)];
    NSString *imgURL = [d objectForKey:@"img"];
    BOOL hasPoster = [imgURL length] > 0;
    CGFloat pw = 100.0f, ph = 145.0f, x = hasPoster ? 12 + pw + 12 : 12;
    if (hasPoster) {
        UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(12, 12, pw, ph)];
        iv.contentMode = UIViewContentModeScaleAspectFill;
        iv.clipsToBounds = YES;
        iv.backgroundColor = [UIColor colorWithRed:0.05f green:0.12f blue:0.30f alpha:1.0f];
        UIImage *c = [self.portal cachedImage:imgURL];
        iv.image = c;
        if (!c) [self.portal loadImage:imgURL done:^(UIImage *i) { if (i) iv.image = i; }];
        [h addSubview:iv];
    }
    CGFloat tw = w - x - 12;
    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(x, 12, tw, 20)];
    t.backgroundColor = [UIColor clearColor];
    t.textColor = M3UTextColor();
    t.shadowColor = M3UShadowColor();
    t.shadowOffset = M3UShadowOffset();
    t.font = [UIFont boldSystemFontOfSize:17.0f];
    t.numberOfLines = 0;
    t.text = [d objectForKey:@"title"] ?: self.title;
    CGSize ts = [t.text sizeWithFont:t.font constrainedToSize:CGSizeMake(tw, 200) lineBreakMode:NSLineBreakByWordWrapping];
    t.frame = CGRectMake(x, 12, tw, ts.height);
    [h addSubview:t];
    NSMutableArray *meta = [NSMutableArray array];
    if ([[d objectForKey:@"year"] intValue] > 0) [meta addObject:[NSString stringWithFormat:@"%d", [[d objectForKey:@"year"] intValue]]];
    if ([[d objectForKey:@"4k"] boolValue]) [meta addObject:@"4K"]; else if ([[d objectForKey:@"fhd"] boolValue]) [meta addObject:@"FHD"];
    if ([[d objectForKey:@"hdr"] boolValue]) [meta addObject:@"HDR"];
    [meta addObject:[NSString stringWithFormat:L(@"odcinków: %lu"), (unsigned long)[self.items count]]];
    UILabel *m = [[UILabel alloc] initWithFrame:CGRectMake(x, CGRectGetMaxY(t.frame) + 4, tw, 16)];
    m.backgroundColor = [UIColor clearColor];
    m.textColor = M3USubtleColor();
    m.font = [UIFont systemFontOfSize:13.0f];
    m.text = [meta componentsJoinedByString:@"  ·  "];
    [h addSubview:m];
    CGFloat bottom = CGRectGetMaxY(m.frame);
    NSString *desc = [d objectForKey:@"description"];
    if ([desc isKindOfClass:[NSString class]] && [desc length]) {
        UILabel *dl = [[UILabel alloc] initWithFrame:CGRectZero];
        dl.backgroundColor = [UIColor clearColor];
        dl.textColor = M3UTextColor();
        dl.font = [UIFont systemFontOfSize:13.0f];
        dl.numberOfLines = 0;
        dl.text = desc;
        CGSize ds = [desc sizeWithFont:dl.font constrainedToSize:CGSizeMake(tw, 1200) lineBreakMode:NSLineBreakByWordWrapping];
        dl.frame = CGRectMake(x, bottom + 8, tw, ds.height);
        [h addSubview:dl];
        bottom = CGRectGetMaxY(dl.frame);
    }
    CGFloat height = bottom + 14;
    if (hasPoster && height < 12 + ph + 14) height = 12 + ph + 14;
    h.frame = CGRectMake(0, 0, w, height);
    self.header = h;
    self.table.tableHeaderView = h;
}

#pragma mark - Pobieranie listy

- (BOOL)anyPosters
{
    for (NSDictionary *it in self.items)
        if ([[it objectForKey:@"img"] length] || [[it objectForKey:@"imglr"] length]) return YES;
    return NO;
}

- (void)applyMode
{
    self.gridMode = !self.detail && [self anyPosters];
    self.table.hidden = self.gridMode;
    self.grid.hidden = !self.gridMode;
    [self.table reloadData];
    [self.grid reloadData];
}

- (void)loadMore
{
    if (self.loading || self.exhausted || !self.portal) return;
    self.loading = YES;
    if (![self.items count]) [self.spinner startAnimating];
    NSMutableDictionary *p = [NSMutableDictionary dictionaryWithDictionary:self.baseReq];
    if (self.nextReq) [p addEntriesFromDictionary:self.nextReq];
    if ([[p objectForKey:@"cmd"] isEqual:@"flicks"] && [[p objectForKey:@"limit"] intValue] == 0) [p setObject:[NSNumber numberWithInt:40] forKey:@"limit"];
    [self.portal request:p done:^(NSDictionary *json, NSString *err) {
        self.loading = NO;
        [self.spinner stopAnimating];
        if (!json) {
            self.exhausted = YES;
            if (![self.items count]) [self showMessage:err]; else [self alert:err];
            return;
        }
        NSDictionary *ctl = [[json objectForKey:@"controls"] objectForKey:@"search"];
        if ([ctl isKindOfClass:[NSDictionary class]] && [[ctl objectForKey:@"request"] isKindOfClass:[NSDictionary class]])
            self.searchTemplate = [ctl objectForKey:@"request"];
        self.nextReq = nil;
        NSArray *arr = [json objectForKey:@"items"];
        if ([arr isKindOfClass:[NSArray class]]) {
            for (NSDictionary *it in arr) {
                if (![it isKindOfClass:[NSDictionary class]]) continue;
                if ([[it objectForKey:@"type"] isEqual:@"next"]) self.nextReq = [it objectForKey:@"request"];
                else [self.items addObject:it];
            }
        }
        if (!self.nextReq) self.exhausted = YES;
        self.loadedOnce = YES;
        [self showMessage:[self.items count] ? nil : L(@"Brak wyników.")];
        [self applyMode];
    }];
}

- (void)scrollViewDidScroll:(UIScrollView *)sv
{
    if (self.detail || !self.loadedOnce || self.loading || self.exhausted) return;
    if (sv.contentOffset.y + sv.bounds.size.height > sv.contentSize.height - 400.0f) [self loadMore];
}

#pragma mark - Szukanie

- (void)searchBarSearchButtonClicked:(UISearchBar *)bar
{
    [bar resignFirstResponder];
    NSString *q = [bar.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (![q length]) return;
    if (!self.searchTemplate) { [self alert:L(@"Ta mediateka nie ma szukania.")]; return; }
    NSMutableDictionary *req = [NSMutableDictionary dictionary];
    for (NSString *k in self.searchTemplate) {
        id v = [self.searchTemplate objectForKey:k];
        if ([v isKindOfClass:[NSString class]]) v = [(NSString *)v stringByReplacingOccurrencesOfString:@"{USERINPUT}" withString:q];
        [req setObject:v forKey:k];
    }
    M3UMediaController *c = [[M3UMediaController alloc] initWithPortal:self.portal request:req title:q search:self.searchTemplate detail:nil];
    [self.navigationController pushViewController:c animated:YES];
}

#pragma mark - Otwieranie pozycji i odtwarzanie

- (void)setBusy:(BOOL)busy
{
    _busy = busy;
    if (busy) [self.spinner startAnimating]; else [self.spinner stopAnimating];
}

- (void)openItem:(NSDictionary *)it
{
    if (self.busy) return;
    NSString *type = [it objectForKey:@"type"];
    NSDictionary *req = [it objectForKey:@"request"];
    NSString *direct = [it objectForKey:@"url"];
    if ([direct isKindOfClass:[NSString class]] && [direct length]) { [self playURL:direct]; return; }
    if (![req isKindOfClass:[NSDictionary class]]) return;
    NSString *title = [it objectForKey:@"title"] ?: @"";
    if ([type isEqual:@"category"]) {
        M3UMediaController *c = [[M3UMediaController alloc] initWithPortal:self.portal request:req title:title search:self.searchTemplate detail:nil];
        [self.navigationController pushViewController:c animated:YES];
        return;
    }
    self.busy = YES;
    [self.portal request:req done:^(NSDictionary *json, NSString *err) {
        self.busy = NO;
        if (!json) { [self alert:err]; return; }
        NSString *u = [json objectForKey:@"url"];
        NSArray *its = [json objectForKey:@"items"];
        if ([u isKindOfClass:[NSString class]] && [u length]) { [self playURL:u]; return; }
        if (![its isKindOfClass:[NSArray class]] || ![its count]) { [self alert:L(@"Brak odtwarzalnych pozycji.")]; return; }
        NSDictionary *first = [its objectAtIndex:0];
        if ([its count] == 1 && [[first objectForKey:@"url"] length]) { [self playURL:[first objectForKey:@"url"]]; return; }
        NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary:json];
        if (![d objectForKey:@"title"]) [d setObject:title forKey:@"title"];
        M3UMediaController *c = [[M3UMediaController alloc] initWithPortal:self.portal request:nil title:title search:self.searchTemplate detail:d];
        [self.navigationController pushViewController:c animated:YES];
    }];
}

- (void)playURL:(NSString *)s
{
    NSURL *u = [NSURL URLWithString:s];
    NSString *scheme = [[u scheme] lowercaseString];
    if (!u || !([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"])) {
        [self alert:L(@"Nie można odtworzyć tej pozycji.")];
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
        [self alert:L(@"Nie udało się odtworzyć filmu. Sprawdź, czy subskrypcja jest opłacona, a połączenie wystarczająco szybkie.")];
    }
}

#pragma mark - Tabela (kategorie, odcinki)

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return (NSInteger)[self.items count]; }

- (UIView *)tableView:(UITableView *)tv viewForHeaderInSection:(NSInteger)s { return self.detail ? M3UHeaderView(L(@"ODCINKI")) : nil; }
- (CGFloat)tableView:(UITableView *)tv heightForHeaderInSection:(NSInteger)s { return self.detail ? 22.0f : 0.0f; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip
{
    static NSString *ident = @"r";
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:ident];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:ident];
    M3UStyleCell(cell);
    NSDictionary *it = [self.items objectAtIndex:(NSUInteger)ip.row];
    cell.textLabel.text = [it objectForKey:@"title"];
    cell.detailTextLabel.text = nil;
    BOOL cat = [[it objectForKey:@"type"] isEqual:@"category"];
    if (cat) {
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.accessoryView = nil;
        NSString *y = [[it objectForKey:@"year"] intValue] > 0 ? [NSString stringWithFormat:@"%d", [[it objectForKey:@"year"] intValue]] : nil;
        cell.detailTextLabel.text = y;
    }
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip
{
    [tv deselectRowAtIndexPath:ip animated:YES];
    [self openItem:[self.items objectAtIndex:(NSUInteger)ip.row]];
}

#pragma mark - Siatka plakatów

- (NSInteger)collectionView:(UICollectionView *)cv numberOfItemsInSection:(NSInteger)s { return (NSInteger)[self.items count]; }

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)ip
{
    M3UPosterCell *cell = [cv dequeueReusableCellWithReuseIdentifier:@"poster" forIndexPath:ip];
    NSUInteger idx = (NSUInteger)ip.item;
    NSDictionary *it = [self.items objectAtIndex:idx];
    NSString *url = [it objectForKey:@"imglr"];
    if (![url length]) url = [it objectForKey:@"img"];
    UIImage *img = [self.portal cachedImage:url];
    int y = [[it objectForKey:@"year"] intValue];
    [cell setTitle:[it objectForKey:@"title"] year:(y > 0 ? [NSString stringWithFormat:@"%d", y] : nil) poster:img];
    if (!img && [url length]) {
        [self.portal loadImage:url done:^(UIImage *i) {
            if (!i || idx >= [self.items count] || [self.items objectAtIndex:idx] != it) return;
            M3UPosterCell *c = (M3UPosterCell *)[self.grid cellForItemAtIndexPath:[NSIndexPath indexPathForItem:(NSInteger)idx inSection:0]];
            if (c) [c setPoster:i];
        }];
    }
    return cell;
}

- (void)collectionView:(UICollectionView *)cv didSelectItemAtIndexPath:(NSIndexPath *)ip
{
    [self openItem:[self.items objectAtIndex:(NSUInteger)ip.item]];
}

@end
