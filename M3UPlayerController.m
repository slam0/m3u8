#import "M3UPlayerController.h"
#import "M3UTheme.h"
#import "M3ULogos.h"
#import "M3UEpg.h"
#import "M3ULocalization.h"
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>

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
    CGContextSetRGBFillColor(c, 1, 1, 1, 1);
    if (pause) {
        CGContextFillRect(c, CGRectMake(6, 4, 6, 20));
        CGContextFillRect(c, CGRectMake(16, 4, 6, 20));
    } else {
        CGContextMoveToPoint(c, 7, 3);
        CGContextAddLineToPoint(c, 24, 14);
        CGContextAddLineToPoint(c, 7, 25);
        CGContextClosePath(c);
        CGContextFillPath(c);
    }
    UIImage *i = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return i;
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

@interface M3UPlayerController () <UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, strong) NSArray *entries;
@property (nonatomic, strong) M3UEntry *current;
@property (nonatomic, strong) MPMoviePlayerController *mp;
@property (nonatomic, strong) UIView *edgeL, *edgeR, *catcher, *listPanel, *epgPanel, *topBar, *bar;
@property (nonatomic, strong) UITableView *listTable, *epgTable;
@property (nonatomic, strong) UILabel *epgHeader, *epgEmpty, *toast;
@property (nonatomic, strong) UILabel *barTitle, *barBadge, *barProg, *loLabel, *hiLabel, *knobLabel;
@property (nonatomic, strong) UISlider *slider;
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
    p.backgroundColor = [UIColor colorWithRed:0.016f green:0.055f blue:0.17f alpha:0.92f];
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

- (UIButton *)barButton:(NSString *)title action:(SEL)a hi:(BOOL)hi
{
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.backgroundColor = hi ? [UIColor colorWithRed:0.20f green:0.47f blue:0.94f alpha:1.0f] : [UIColor colorWithRed:0.16f green:0.27f blue:0.55f alpha:1.0f];
    b.layer.cornerRadius = 9.0f;
    b.layer.borderWidth = 2.0f;
    b.layer.borderColor = [UIColor colorWithRed:0.59f green:0.75f blue:1.0f alpha:0.8f].CGColor;
    b.titleLabel.font = [UIFont boldSystemFontOfSize:16.0f];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:M3UTextColor() forState:UIControlStateNormal];
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
    tap.delegate = self;
    [self.view addGestureRecognizer:tap];
    [self swipe:UISwipeGestureRecognizerDirectionUp on:self.view action:@selector(nextChannel)].delegate = self;
    [self swipe:UISwipeGestureRecognizerDirectionDown on:self.view action:@selector(prevChannel)].delegate = self;

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.spinner.hidesWhenStopped = YES;
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
    self.catcher.backgroundColor = [UIColor colorWithWhite:0 alpha:0.25f];
    self.catcher.hidden = YES;
    [self.catcher addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closePanels)]];
    [self.view addSubview:self.catcher];

    /* lista kanałów (z prawej) */
    self.listPanel = [self darkPanel];
    [self headerIn:self.listPanel text:L(@"Kanały")];
    self.listTable = [self tableIn:self.listPanel];
    [self swipe:UISwipeGestureRecognizerDirectionRight on:self.listPanel action:@selector(closePanels)];
    [self.view addSubview:self.listPanel];

    /* program i archiwum (z lewej) */
    self.epgPanel = [self darkPanel];
    self.epgHeader = [self headerIn:self.epgPanel text:L(@"Program")];
    self.epgTable = [self tableIn:self.epgPanel];
    NSMutableArray *tabs = [NSMutableArray array];
    NSArray *tn = [NSArray arrayWithObjects:L(@"Wczoraj"), L(@"Dziś"), L(@"Jutro"), nil];
    for (NSInteger i = 0; i < 3; i++) {
        UIButton *b = [self barButton:[tn objectAtIndex:(NSUInteger)i] action:@selector(dayTapped:) hi:NO];
        b.tag = i;
        b.layer.cornerRadius = 8.0f;
        b.layer.borderWidth = 1.0f;
        b.titleLabel.font = [UIFont boldSystemFontOfSize:15.0f];
        [self.epgPanel addSubview:b];
        [tabs addObject:b];
    }
    self.dayTabs = tabs;
    self.epgEmpty = [self smallLabel:16.0f color:M3USubtleColor() align:NSTextAlignmentCenter];
    self.epgEmpty.numberOfLines = 0;
    self.epgEmpty.text = L(@"Brak programu dla tego kanału.");
    [self.epgPanel addSubview:self.epgEmpty];
    self.pickBtn = [self barButton:L(@"Wybierz dzień i godzinę") action:@selector(showPicker) hi:NO];
    [self.epgPanel addSubview:self.pickBtn];
    [self swipe:UISwipeGestureRecognizerDirectionLeft on:self.epgPanel action:@selector(closePanels)];
    [self.view addSubview:self.epgPanel];

    /* przycisk zamknięcia */
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

    /* dolny pasek: kanał, etykieta (na żywo / archiwum), audycja, oś czasu, przyciski */
    self.bar = [[UIView alloc] initWithFrame:CGRectZero];
    self.bar.backgroundColor = [UIColor colorWithWhite:0 alpha:0.70f];
    self.bar.layer.cornerRadius = 14.0f;
    self.barTitle = [self smallLabel:19.0f color:M3UTextColor() align:NSTextAlignmentLeft];
    self.barTitle.font = [UIFont boldSystemFontOfSize:19.0f];
    self.barBadge = [self smallLabel:14.0f color:[UIColor whiteColor] align:NSTextAlignmentCenter];
    self.barBadge.font = [UIFont boldSystemFontOfSize:14.0f];
    self.barBadge.layer.cornerRadius = 7.0f;
    self.barBadge.clipsToBounds = YES;
    self.barProg = [self smallLabel:14.0f color:M3USubtleColor() align:NSTextAlignmentLeft];
    self.loLabel = [self smallLabel:14.0f color:M3USubtleColor() align:NSTextAlignmentLeft];
    self.hiLabel = [self smallLabel:14.0f color:M3USubtleColor() align:NSTextAlignmentRight];
    self.knobLabel = [self smallLabel:12.0f color:M3UTextColor() align:NSTextAlignmentCenter];
    self.knobLabel.font = [UIFont boldSystemFontOfSize:12.0f];
    self.slider = [[UISlider alloc] initWithFrame:CGRectZero];
    self.slider.minimumValue = 0.0f;
    self.slider.maximumValue = 1.0f;
    [self.slider addTarget:self action:@selector(sliderDown) forControlEvents:UIControlEventTouchDown];
    [self.slider addTarget:self action:@selector(sliderMoved) forControlEvents:UIControlEventValueChanged];
    [self.slider addTarget:self action:@selector(sliderUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    self.backBtn = [self barButton:L(@"-10 min") action:@selector(skipBack) hi:NO];
    self.fwdBtn = [self barButton:L(@"+10 min") action:@selector(skipForward) hi:NO];
    self.liveBtn = [self barButton:L(@"Na żywo") action:@selector(goLive) hi:YES];
    self.playBtn = [self barButton:nil action:@selector(togglePause) hi:NO];
    [self.playBtn setImage:playIcon(YES) forState:UIControlStateNormal];
    for (UIView *v in [NSArray arrayWithObjects:self.barTitle, self.barBadge, self.barProg, self.loLabel, self.hiLabel, self.slider, self.knobLabel, self.backBtn, self.playBtn, self.fwdBtn, self.liveBtn, nil])
        [self.bar addSubview:v];
    [self.view addSubview:self.bar];

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

- (BOOL)isLandscape { return self.view.bounds.size.width > self.view.bounds.size.height; }

- (CGFloat)panelWidth { return MIN(340.0f, (CGFloat)(int)(self.view.bounds.size.width * 0.42f)); }

- (void)layoutBar
{
    CGRect b = self.view.bounds;
    CGFloat cw = MIN(648.0f, b.size.width - 40.0f), ch = 156.0f;
    self.bar.frame = CGRectMake((CGFloat)(int)((b.size.width - cw) / 2.0f), b.size.height - ch - 24.0f, cw, ch);
    CGSize ts = [self.barTitle.text ?: @"" sizeWithFont:self.barTitle.font];
    CGFloat tw = MIN(ts.width, cw * 0.5f);
    self.barTitle.frame = CGRectMake(18, 8, tw, 24);
    self.barBadge.frame = CGRectMake(18 + tw + 10, 11, 96, 18);
    self.barProg.frame = CGRectMake(18, 34, cw - 36, 18);
    self.loLabel.frame = CGRectMake(14, 76, 58, 20);
    self.hiLabel.frame = CGRectMake(cw - 72, 76, 58, 20);
    self.slider.frame = CGRectMake(74, 70, cw - 148, 30);
    CGFloat bw[4] = { 74, 80, 74, 108 }, gap = 10, total = 74 + 80 + 74 + 108 + gap * 3, x = (CGFloat)(int)((cw - total) / 2.0f);
    NSArray *btns = [NSArray arrayWithObjects:self.backBtn, self.playBtn, self.fwdBtn, self.liveBtn, nil];
    for (NSUInteger i = 0; i < 4; i++) {
        UIButton *bt = [btns objectAtIndex:i];
        bt.frame = CGRectMake(x, 110, bw[i], 40);
        x += bw[i] + gap;
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

    self.listTable.frame = CGRectMake(0, 54, pw, b.size.height - 54);
    CGFloat tabW = (CGFloat)(int)((pw - 24.0f - 12.0f) / 3.0f);
    for (UIButton *t in self.dayTabs) t.frame = CGRectMake(12 + t.tag * (tabW + 6), 62, tabW, 30);
    self.epgTable.frame = CGRectMake(0, 102, pw, b.size.height - 102 - 72);
    self.epgEmpty.frame = CGRectMake(20, 140, pw - 40, 60);
    self.pickBtn.frame = CGRectMake(12, b.size.height - 62, pw - 24, 46);
    self.topBar.frame = CGRectMake(16, 16, 96, 40);
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
        [self showToast:L(@"Nie udało się odtworzyć kanału. Wybierz inny z listy (przesuń palcem od prawej krawędzi).")];
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

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g shouldReceiveTouch:(UITouch *)t
{
    for (UIView *v in [NSArray arrayWithObjects:self.listPanel, self.epgPanel, self.bar, self.topBar, self.pickerView, nil])
        if (v && [t.view isDescendantOfView:v]) return NO;
    return YES;
}

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
    BOOL live = !self.archiveMode;
    self.barBadge.text = live ? L(@"NA ŻYWO") : L(@"ARCHIWUM");
    self.barBadge.backgroundColor = live ? [UIColor colorWithRed:0.20f green:0.47f blue:0.94f alpha:1.0f] : [UIColor colorWithRed:0.78f green:0.31f blue:0.16f alpha:1.0f];
    [self.playBtn setImage:playIcon(!self.paused) forState:UIControlStateNormal];
    self.fwdBtn.alpha = self.archiveMode ? 1.0f : 0.4f;
    self.liveBtn.alpha = (self.archiveMode || self.paused) ? 1.0f : 0.4f;
    [self layoutBar];
    [self reloadEpgPanel];
    [self updateTimeline];
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
    self.knobLabel.text = M3UEpgClock(pos);
    CGRect tr = [self.slider trackRectForBounds:self.slider.bounds];
    CGRect th = [self.slider thumbRectForBounds:self.slider.bounds trackRect:tr value:self.slider.value];
    self.knobLabel.frame = CGRectMake(self.slider.frame.origin.x + CGRectGetMidX(th) - 28.0f, 56.0f, 56, 14);
}

- (void)sliderDown { self.dragging = YES; self.sDown = self.slider.value; [self.hideTimer invalidate]; }

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
    if (fabsf(self.slider.value - self.sDown) < 0.004f) { [self showOverlay]; return; }      /* samo dotknięcie nic nie zmienia */
    [self playArchiveFrom:t];                      /* blisko „teraz” przechodzi na żywo */
}

- (void)tickFired
{
    [self updateTimeline];
    if (!self.archiveMode || self.paused) return;
    /* archiwum dogoniło „teraz” - to już transmisja na żywo */
    if ([self position] > [self nowEpoch] - 5.0) [self playLive];
}

#pragma mark - Nakładka (zamknij, pasek)

- (void)setOverlayAlpha:(CGFloat)a
{
    self.topBar.alpha = a;
    self.bar.alpha = a;
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
    for (UIButton *b in self.dayTabs)
        b.backgroundColor = (b.tag == self.dayIndex) ? [UIColor colorWithRed:0.20f green:0.47f blue:0.94f alpha:1.0f] : [UIColor colorWithRed:0.12f green:0.20f blue:0.42f alpha:1.0f];
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
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 340, 332)];
    v.backgroundColor = [UIColor colorWithRed:0.03f green:0.09f blue:0.24f alpha:0.98f];
    v.layer.cornerRadius = 14.0f;
    v.layer.borderWidth = 2.0f;
    v.layer.borderColor = [UIColor colorWithRed:0.59f green:0.75f blue:1.0f alpha:0.8f].CGColor;
    UILabel *t = [self smallLabel:18.0f color:M3UTextColor() align:NSTextAlignmentCenter];
    t.font = [UIFont boldSystemFontOfSize:18.0f];
    t.frame = CGRectMake(10, 10, 320, 28);
    t.text = L(@"Archiwum: wybierz moment");
    [v addSubview:t];
    UIDatePicker *p = [[UIDatePicker alloc] initWithFrame:CGRectMake(10, 46, 320, 216)];
    p.datePickerMode = UIDatePickerModeDateAndTime;
    double now = [self nowEpoch];
    p.minimumDate = [NSDate dateWithTimeIntervalSince1970:now - kArchiveDepth];
    p.maximumDate = [NSDate dateWithTimeIntervalSince1970:now - 60.0];
    p.date = [NSDate dateWithTimeIntervalSince1970:MAX(now - kArchiveDepth, MIN(now - 3600.0, [self position]))];
    [v addSubview:p];
    self.picker = p;
    UIButton *no = [self barButton:L(@"Anuluj") action:@selector(hidePicker) hi:NO];
    no.frame = CGRectMake(14, 274, 148, 44);
    [v addSubview:no];
    UIButton *go = [self barButton:L(@"Odtwórz") action:@selector(pickerGo) hi:YES];
    go.frame = CGRectMake(178, 274, 148, 44);
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
            track.frame = CGRectMake(16, kRow - 18, tv.bounds.size.width - 32, 3);
            UIView *fill = [track viewWithTag:78];
            float pr = t > s ? (float)((now - s) / (t - s)) : 0.0f;
            fill.frame = CGRectMake(0, 0, (CGFloat)(int)(track.bounds.size.width * MIN(1.0f, MAX(0.0f, pr))), 3);
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
    cell.backgroundColor = [self rowIsOn:tv at:ip] ? [UIColor colorWithRed:0.20f green:0.47f blue:0.94f alpha:0.78f] : [UIColor clearColor];
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
