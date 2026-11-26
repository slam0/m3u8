#import "M3UPlayerController.h"
#import "M3UTheme.h"
#import "M3ULogos.h"
#import "M3UEpg.h"
#import "M3ULocalization.h"
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>

static const CGFloat kEdge = 44.0f;       /* szerokość pasków przy krawędziach, od których zaczyna się przesunięcie */
static const CGFloat kRow = 62.0f;

@interface M3UPlayerController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) NSArray *entries;
@property (nonatomic, strong) M3UEntry *current;
@property (nonatomic, strong) MPMoviePlayerController *mp;
@property (nonatomic, strong) UIView *edgeL, *edgeR, *catcher, *listPanel, *epgPanel, *topBar, *infoBar;
@property (nonatomic, strong) UITableView *listTable, *epgTable;
@property (nonatomic, strong) UILabel *infoTitle, *infoNow, *epgHeader, *toast;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) NSArray *epgRows;
@property (nonatomic) BOOL listOpen, epgOpen, overlayVisible;
@property (nonatomic, strong) NSTimer *hideTimer;
@end

@implementation M3UPlayerController

M3U_ROTATE_ANY

- (id)initWithEntries:(NSArray *)entries current:(M3UEntry *)current
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.entries = entries;
        self.current = current;
        self.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    return self;
}

- (void)dealloc
{
    [self.hideTimer invalidate];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Widok

- (UIView *)darkPanel
{
    UIView *p = [[UIView alloc] initWithFrame:CGRectZero];
    p.backgroundColor = [UIColor colorWithRed:0.016f green:0.055f blue:0.17f alpha:0.90f];
    p.hidden = YES;
    p.layer.borderColor = [UIColor colorWithRed:0.59f green:0.75f blue:1.0f alpha:0.55f].CGColor;
    p.layer.borderWidth = 1.0f;
    return p;
}

- (UILabel *)headerIn:(UIView *)panel text:(NSString *)t
{
    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 54)];
    bar.backgroundColor = [UIColor colorWithRed:0.04f green:0.12f blue:0.31f alpha:1.0f];
    bar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [panel addSubview:bar];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, 280, 54)];
    l.backgroundColor = [UIColor clearColor];
    l.textColor = M3UTextColor();
    l.font = [UIFont boldSystemFontOfSize:20.0f];
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
    t.separatorColor = [UIColor colorWithWhite:1.0f alpha:0.12f];
    t.dataSource = self;
    t.delegate = self;
    t.rowHeight = kRow;
    t.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
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

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(videoTapped)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];

    /* paski przy krawędziach: od nich zaczyna się przesunięcie (w poziomie) */
    self.edgeR = [[UIView alloc] initWithFrame:CGRectZero];
    self.edgeR.backgroundColor = [UIColor clearColor];
    [self swipe:UISwipeGestureRecognizerDirectionLeft on:self.edgeR action:@selector(openList)];
    [self.view addSubview:self.edgeR];
    self.edgeL = [[UIView alloc] initWithFrame:CGRectZero];
    self.edgeL.backgroundColor = [UIColor clearColor];
    [self swipe:UISwipeGestureRecognizerDirectionRight on:self.edgeL action:@selector(openEpg)];
    [self.view addSubview:self.edgeL];

    /* przezroczysta warstwa: dotknięcie poza panelem go zamyka */
    self.catcher = [[UIView alloc] initWithFrame:CGRectZero];
    self.catcher.backgroundColor = [UIColor colorWithWhite:0 alpha:0.25f];
    self.catcher.hidden = YES;
    [self.catcher addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closePanels)]];
    [self.view addSubview:self.catcher];

    self.listPanel = [self darkPanel];
    [self headerIn:self.listPanel text:L(@"Kanały")];
    self.listTable = [self tableIn:self.listPanel];
    [self swipe:UISwipeGestureRecognizerDirectionRight on:self.listPanel action:@selector(closePanels)];
    [self.view addSubview:self.listPanel];

    self.epgPanel = [self darkPanel];
    self.epgHeader = [self headerIn:self.epgPanel text:L(@"Program")];
    self.epgTable = [self tableIn:self.epgPanel];
    [self swipe:UISwipeGestureRecognizerDirectionLeft on:self.epgPanel action:@selector(closePanels)];
    [self.view addSubview:self.epgPanel];

    /* górny pasek (zamknij) i dolna belka (nazwa kanału, co leci) - chowane po kilku sekundach */
    self.topBar = [[UIView alloc] initWithFrame:CGRectMake(16, 16, 96, 40)];
    self.topBar.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55f];
    self.topBar.layer.cornerRadius = 10.0f;
    self.closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.closeButton.frame = self.topBar.bounds;
    [self.closeButton setTitle:L(@"Zamknij") forState:UIControlStateNormal];
    self.closeButton.titleLabel.font = [UIFont boldSystemFontOfSize:17.0f];
    [self.closeButton setTitleColor:M3UTextColor() forState:UIControlStateNormal];
    [self.closeButton addTarget:self action:@selector(closePlayer) forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.closeButton];
    [self.view addSubview:self.topBar];

    self.infoBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 420, 58)];
    self.infoBar.backgroundColor = [UIColor colorWithWhite:0 alpha:0.62f];
    self.infoBar.layer.cornerRadius = 12.0f;
    self.infoTitle = [[UILabel alloc] initWithFrame:CGRectMake(16, 7, 388, 24)];
    self.infoTitle.backgroundColor = [UIColor clearColor];
    self.infoTitle.textColor = M3UTextColor();
    self.infoTitle.font = [UIFont boldSystemFontOfSize:19.0f];
    self.infoTitle.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.infoBar addSubview:self.infoTitle];
    self.infoNow = [[UILabel alloc] initWithFrame:CGRectMake(16, 33, 388, 18)];
    self.infoNow.backgroundColor = [UIColor clearColor];
    self.infoNow.textColor = M3USubtleColor();
    self.infoNow.font = [UIFont systemFontOfSize:14.0f];
    self.infoNow.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.infoBar addSubview:self.infoNow];
    [self.view addSubview:self.infoBar];

    self.toast = [[UILabel alloc] initWithFrame:CGRectZero];
    self.toast.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7f];
    self.toast.textColor = M3UTextColor();
    self.toast.font = [UIFont systemFontOfSize:16.0f];
    self.toast.textAlignment = NSTextAlignmentCenter;
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

    self.overlayVisible = YES;
    [self startCurrent];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.hideTimer invalidate];
    self.hideTimer = nil;
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationNone];
}

- (BOOL)isLandscape { return self.view.bounds.size.width > self.view.bounds.size.height; }

- (CGFloat)panelWidth { return MIN(340.0f, (CGFloat)(int)(self.view.bounds.size.width * 0.42f)); }

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
        self.catcher.hidden = !(self.listOpen || self.epgOpen);
    };
    self.catcher.hidden = !(self.listOpen || self.epgOpen);
    if (animated) {
        [UIView animateWithDuration:0.25 animations:apply completion:done];
    } else {
        apply();
        done(YES);
    }
    CGSize s = CGSizeMake(pw, b.size.height);
    self.listTable.frame = CGRectMake(0, 54, s.width, s.height - 54);
    self.epgTable.frame = CGRectMake(0, 54, s.width, s.height - 54);
    self.topBar.frame = CGRectMake(16, 16, 96, 40);
    CGFloat iw = MIN(420.0f, b.size.width - 80.0f);
    self.infoBar.frame = CGRectMake((CGFloat)(int)((b.size.width - iw) / 2.0f), b.size.height - 58.0f - 24.0f, iw, 58);
    self.infoTitle.frame = CGRectMake(16, 7, iw - 32, 24);
    self.infoNow.frame = CGRectMake(16, 33, iw - 32, 18);
    self.spinner.center = CGPointMake(b.size.width / 2.0f, b.size.height / 2.0f);
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self layoutPanelsAnimated:NO];
}

#pragma mark - Odtwarzanie

- (void)startCurrent
{
    NSURL *u = [NSURL URLWithString:self.current.url];
    NSString *scheme = [[u scheme] lowercaseString];
    [self refreshInfo];
    [self reloadEpgPanel];
    [self.listTable reloadData];
    [self scrollListToCurrent];
    if (!u || !([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"])) {
        [self showToast:[NSString stringWithFormat:L(@"iOS 6 odtworzy tylko strumienie HLS przez http lub https. Ten kanał używa „%@”."), scheme ?: @"?"]];
        return;
    }
    [self.mp stop];
    self.mp.contentURL = u;
    [self.spinner startAnimating];
    [self.mp prepareToPlay];
    [self.mp play];
    [self showOverlay];
}

- (void)loadStateChanged:(NSNotification *)n
{
    if (self.mp.loadState & (MPMovieLoadStatePlayable | MPMovieLoadStatePlaythroughOK)) [self.spinner stopAnimating];
}

- (void)playbackFinished:(NSNotification *)n
{
    NSNumber *reason = [[n userInfo] objectForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey];
    if ([reason intValue] == MPMovieFinishReasonPlaybackError) {
        [self.spinner stopAnimating];
        [self showToast:L(@"Nie udało się odtworzyć kanału. Wybierz inny z listy (przesuń palcem od prawej krawędzi).")];
    }
}

- (void)closePlayer
{
    [self.mp stop];
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Nakładka (zamknij, nazwa kanału)

- (void)refreshInfo
{
    self.infoTitle.text = self.current.name;
    NSDictionary *ep = M3UEpgEnabled() ? M3UEpgFor(self.current.name) : nil;
    NSString *now = [ep objectForKey:@"now"];
    if (now) self.infoNow.text = [NSString stringWithFormat:@"%@  %@–%@", now, M3UEpgClock([[ep objectForKey:@"start"] doubleValue]), M3UEpgClock([[ep objectForKey:@"end"] doubleValue])];
    else self.infoNow.text = nil;
}

- (void)setOverlayAlpha:(CGFloat)a
{
    self.topBar.alpha = a;
    self.infoBar.alpha = a;
    self.topBar.userInteractionEnabled = (a > 0.5f);
}

- (void)showOverlay
{
    [self.hideTimer invalidate];
    self.overlayVisible = YES;
    [UIView animateWithDuration:0.2 animations:^{ [self setOverlayAlpha:1.0f]; }];
    self.hideTimer = [NSTimer scheduledTimerWithTimeInterval:4.0 target:self selector:@selector(hideOverlay) userInfo:nil repeats:NO];
}

- (void)hideOverlay
{
    self.overlayVisible = NO;
    [UIView animateWithDuration:0.3 animations:^{ [self setOverlayAlpha:0.0f]; }];
}

- (void)videoTapped
{
    if (self.listOpen || self.epgOpen) return;
    if (self.overlayVisible) { [self.hideTimer invalidate]; [self hideOverlay]; } else [self showOverlay];
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

- (void)openList
{
    if (![self isLandscape]) return;
    self.epgOpen = NO;
    self.listOpen = YES;
    [self.hideTimer invalidate];
    [self hideOverlay];
    [self.listTable reloadData];
    [self scrollListToCurrent];
    [self layoutPanelsAnimated:YES];
}

- (void)openEpg
{
    if (![self isLandscape]) return;
    [self reloadEpgPanel];
    if (![self.epgRows count]) {
        [self showToast:M3UEpgEnabled() ? L(@"Brak programu dla tego kanału.") : L(@"Program TV jest wyłączony w Ustawieniach.")];
        return;
    }
    self.listOpen = NO;
    self.epgOpen = YES;
    [self.hideTimer invalidate];
    [self hideOverlay];
    [self layoutPanelsAnimated:YES];
    [self scrollEpgToCurrent];
}

- (void)closePanels
{
    self.listOpen = NO;
    self.epgOpen = NO;
    [self layoutPanelsAnimated:YES];
}

- (void)scrollListToCurrent
{
    NSUInteger i = [self.entries indexOfObjectIdenticalTo:self.current];
    if (i == NSNotFound) i = [self.entries indexOfObjectPassingTest:^BOOL(M3UEntry *e, NSUInteger k, BOOL *stop) { return [e.url isEqualToString:self.current.url]; }];
    if (i != NSNotFound && i < [self.entries count]) [self.listTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:(NSInteger)i inSection:0] atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
}

- (void)scrollEpgToCurrent
{
    if ([self.epgRows count]) [self.epgTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
}

- (void)reloadEpgPanel
{
    self.epgRows = M3UEpgEnabled() ? M3UEpgList(self.current.name) : [NSArray array];
    self.epgHeader.text = [NSString stringWithFormat:@"%@: %@", L(@"Program"), self.current.name];
    [self.epgTable reloadData];
}

- (void)epgUpdated
{
    [self refreshInfo];
    [self reloadEpgPanel];
    if (self.listOpen) [self.listTable reloadData];
}

- (void)logoLoaded
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reloadListRows) object:nil];
    [self performSelector:@selector(reloadListRows) withObject:nil afterDelay:0.15];
}

- (void)reloadListRows { if (self.listOpen) [self.listTable reloadData]; }

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
        cell.textLabel.textColor = M3UTextColor();
        cell.detailTextLabel.textColor = M3USubtleColor();
        cell.textLabel.font = [UIFont boldSystemFontOfSize:17.0f];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:13.0f];
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
        UIView *track = [[UIView alloc] initWithFrame:CGRectZero];
        track.tag = 77;
        track.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.22f];
        UIView *fill = [[UIView alloc] initWithFrame:CGRectZero];
        fill.tag = 78;
        fill.backgroundColor = M3UAccentColor();
        [track addSubview:fill];
        [cell.contentView addSubview:track];
    }
    UIView *track = [cell.contentView viewWithTag:77];
    track.hidden = YES;
    BOOL on = NO;
    if (channels) {
        M3UEntry *e = [self.entries objectAtIndex:(NSUInteger)ip.row];
        on = [e.url isEqualToString:self.current.url];
        cell.imageView.image = [self tileFor:e];
        cell.textLabel.text = e.name;
        NSDictionary *ep = M3UEpgEnabled() ? M3UEpgFor(e.name) : nil;
        cell.detailTextLabel.text = [ep objectForKey:@"now"] ? [NSString stringWithFormat:L(@"Teraz: %@"), [ep objectForKey:@"now"]] : nil;
    } else {
        NSArray *r = [self.epgRows objectAtIndex:(NSUInteger)ip.row];
        double s = [[r objectAtIndex:0] doubleValue], t = [[r objectAtIndex:1] doubleValue], now = [[NSDate date] timeIntervalSince1970];
        on = (s <= now && now < t);
        cell.imageView.image = nil;
        cell.textLabel.text = [NSString stringWithFormat:@"%@   %@", M3UEpgClock(s), [r objectAtIndex:2]];
        cell.detailTextLabel.text = on ? nil : @" ";
        if (on) {
            track.hidden = NO;
            track.frame = CGRectMake(16, kRow - 18, tv.bounds.size.width - 32, 3);
            UIView *fill = [track viewWithTag:78];
            float pr = t > s ? (float)((now - s) / (t - s)) : 0.0f;
            fill.frame = CGRectMake(0, 0, (CGFloat)(int)(track.bounds.size.width * MIN(1.0f, MAX(0.0f, pr))), 3);
        }
    }
    cell.backgroundColor = on ? [UIColor colorWithRed:0.20f green:0.47f blue:0.94f alpha:0.78f] : [UIColor clearColor];
    cell.contentView.backgroundColor = [UIColor clearColor];
    return cell;
}

- (void)tableView:(UITableView *)tv willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)ip
{
    /* kolor tła ustawiony w cellForRow bywa zerowany przy ponownym użyciu komórki - ustawiamy jeszcze raz */
    BOOL on;
    if (tv == self.listTable) on = [((M3UEntry *)[self.entries objectAtIndex:(NSUInteger)ip.row]).url isEqualToString:self.current.url];
    else {
        NSArray *r = [self.epgRows objectAtIndex:(NSUInteger)ip.row];
        double now = [[NSDate date] timeIntervalSince1970];
        on = [[r objectAtIndex:0] doubleValue] <= now && now < [[r objectAtIndex:1] doubleValue];
    }
    cell.backgroundColor = on ? [UIColor colorWithRed:0.20f green:0.47f blue:0.94f alpha:0.78f] : [UIColor clearColor];
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip
{
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (tv != self.listTable) return;
    M3UEntry *e = [self.entries objectAtIndex:(NSUInteger)ip.row];
    self.current = e;
    [self closePanels];
    [self startCurrent];
}

@end
