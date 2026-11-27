#import "M3USetupController.h"
#import <QuartzCore/QuartzCore.h>
#import "M3UTheme.h"
#import "M3UStore.h"
#import "M3ULocalization.h"

static NSString *const kSetupDone = @"setup_done";
static NSString *const kLayoutKey = @"layout_grid";
static const NSInteger kPages = 4;

@interface M3USetupController () <UIScrollViewDelegate, UITextFieldDelegate>
@property (nonatomic, strong) UIScrollView *pager;
@property (nonatomic, strong) UIPageControl *dots;
@property (nonatomic, strong) UIButton *mainButton;
@property (nonatomic, strong) UIButton *skipButton;
@property (nonatomic, strong) UITextField *nameField;
@property (nonatomic, strong) UITextField *urlField;
@property (nonatomic, strong) UIButton *listChoice;
@property (nonatomic, strong) UIButton *gridChoice;
@property (nonatomic, assign) NSInteger page;
@property (nonatomic, assign) BOOL gridSelected;
@property (nonatomic, assign) CGFloat urlFieldBottom;
@end

@implementation M3USetupController

M3U_ROTATE_PORTRAIT

+ (BOOL)needsSetup
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if ([d boolForKey:kSetupDone]) return NO;
    if ([M3UPlaylists() count] > 0) {      /* ktoś, kto aktualizuje aplikację i ma już playlisty */
        [d setBool:YES forKey:kSetupDone];
        return NO;
    }
    return YES;
}

#pragma mark - Pomocnicze

static UILabel *makeLabel(NSString *text, CGRect frame, CGFloat size, BOOL bold, UIColor *color, NSTextAlignment align)
{
    UILabel *l = [[UILabel alloc] initWithFrame:frame];
    l.backgroundColor = [UIColor clearColor];
    l.text = text;
    l.textColor = color;
    l.textAlignment = align;
    l.font = bold ? [UIFont boldSystemFontOfSize:size] : [UIFont systemFontOfSize:size];
    l.shadowColor = [UIColor colorWithRed:0 green:0.08f blue:0.27f alpha:0.8f];
    l.shadowOffset = CGSizeMake(0, 1);
    l.numberOfLines = 0;
    return l;
}

static UIColor *softWhite(void) { return [UIColor whiteColor]; }
static UIColor *softBlue(void) { return [UIColor colorWithRed:0.78f green:0.89f blue:1.0f alpha:1.0f]; }

static UIImage *stretch(NSString *name, CGFloat cap)
{
    return [[UIImage imageNamed:name] resizableImageWithCapInsets:UIEdgeInsetsMake(cap, cap, cap, cap)];
}

static UIButton *barButton(NSString *title, CGRect frame, id target, SEL action)
{
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.frame = frame;
    [b setBackgroundImage:stretch(@"btn_bar", 10) forState:UIControlStateNormal];
    [b setBackgroundImage:stretch(@"btn_bar_pressed", 10) forState:UIControlStateHighlighted];
    [b setTitle:title forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    b.titleLabel.shadowOffset = CGSizeMake(0, -1);
    [b setTitleShadowColor:[UIColor colorWithWhite:0 alpha:0.6f] forState:UIControlStateNormal];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [b addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}

static UIImageView *glassPanel(CGRect frame)
{
    UIImageView *v = [[UIImageView alloc] initWithImage:stretch(@"glass_panel", 14)];
    v.frame = frame;
    return v;
}

- (UITextField *)makeField:(NSString *)placeholder frame:(CGRect)f
{
    UITextField *t = [[UITextField alloc] initWithFrame:f];
    t.borderStyle = UITextBorderStyleRoundedRect;
    t.placeholder = placeholder;
    t.font = [UIFont systemFontOfSize:16];
    t.autocorrectionType = UITextAutocorrectionTypeNo;
    t.autocapitalizationType = UITextAutocapitalizationTypeNone;
    t.clearButtonMode = UITextFieldViewModeWhileEditing;
    t.keyboardAppearance = UIKeyboardAppearanceAlert;
    t.delegate = self;
    return t;
}

#pragma mark - Widok

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.gridSelected = YES;                                   /* kafelki wybrane na start, jak na makiecie */
    CGRect b = self.view.bounds;
    CGFloat W = b.size.width, H = b.size.height;
    [self.view addSubview:M3UBackdropViewBlue(b)];

    self.pager = [[UIScrollView alloc] initWithFrame:b];
    self.pager.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.pager.pagingEnabled = YES;
    self.pager.showsHorizontalScrollIndicator = NO;
    self.pager.alwaysBounceHorizontal = NO;
    self.pager.bounces = NO;
    self.pager.delegate = self;
    self.pager.contentSize = CGSizeMake(W * kPages, H);
    [self.view addSubview:self.pager];

    CGFloat extra = (H > 470.0f) ? (H - 460.0f) * 0.35f : 0.0f;       /* na wyższym ekranie (iPhone 5) trochę luzu */
    if (extra > 130.0f) extra = 130.0f;
    /* na iPadzie treść stoi w wąskiej kolumnie pośrodku, jak na telefonie */
    CGFloat cw = W > 480.0f ? 420.0f : W, cx = (W - cw) / 2.0f;
    [self buildWelcome:CGRectMake(cx, 0, cw, H) extra:extra];
    [self buildWays:CGRectMake(W + cx, 0, cw, H) extra:extra];
    [self buildForm:CGRectMake(W * 2 + cx, 0, cw, H) extra:extra];
    [self buildLayout:CGRectMake(W * 3 + cx, 0, cw, H) extra:extra];

    self.dots = [[UIPageControl alloc] initWithFrame:CGRectMake(0, H - 86, W, 20)];
    self.dots.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.dots.numberOfPages = kPages;
    if ([self.dots respondsToSelector:@selector(setPageIndicatorTintColor:)]) {
        self.dots.pageIndicatorTintColor = [UIColor colorWithWhite:1.0f alpha:0.4f];
        self.dots.currentPageIndicatorTintColor = [UIColor whiteColor];
    }
    self.dots.userInteractionEnabled = NO;
    [self.view addSubview:self.dots];

    self.mainButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.mainButton.frame = CGRectMake((W - 200) / 2.0f, H - 58, 200, 44);
    self.mainButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
    [self.mainButton setBackgroundImage:stretch(@"btn_main", 18) forState:UIControlStateNormal];
    [self.mainButton setBackgroundImage:stretch(@"btn_main_pressed", 18) forState:UIControlStateHighlighted];
    self.mainButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [self.mainButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.mainButton setTitleShadowColor:[UIColor colorWithRed:0 green:0.08f blue:0.3f alpha:0.8f] forState:UIControlStateNormal];
    self.mainButton.titleLabel.shadowOffset = CGSizeMake(0, -1);
    [self.mainButton addTarget:self action:@selector(nextTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.mainButton];

    self.skipButton = barButton(L(@"Pomiń"), CGRectMake(W - 86, 10, 76, 32), self, @selector(skipTapped));
    self.skipButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.view addSubview:self.skipButton];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [nc addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [self updateControls];
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)buildWelcome:(CGRect)f extra:(CGFloat)e
{
    UIView *p = [[UIView alloc] initWithFrame:f];
    CGFloat W = f.size.width;
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"setup_icon"]];
    icon.frame = CGRectMake((W - 110) / 2.0f, 40 + e * 0.6f, 110, 110);
    [p addSubview:icon];
    CGFloat y = 168 + e;
    [p addSubview:makeLabel(L(@"Witaj w iSat"), CGRectMake(0, y, W, 36), 28, YES, softWhite(), NSTextAlignmentCenter)];
    [p addSubview:makeLabel(L(@"Czytnik playlist M3U i M3U8"), CGRectMake(0, y + 40, W, 22), 16, NO, softBlue(), NSTextAlignmentCenter)];
    [p addSubview:makeLabel(L(@"kanały z ikonami, ulubione, odtwarzanie"), CGRectMake(0, y + 64, W, 20), 13, NO, softBlue(), NSTextAlignmentCenter)];
    UIImageView *panel = glassPanel(CGRectMake(24, y + 100, W - 48, 62));
    [p addSubview:panel];
    [p addSubview:makeLabel(L(@"Do startu potrzebujesz tylko\nadresu swojej playlisty"), CGRectMake(24, y + 108, W - 48, 46), 15, YES, softWhite(), NSTextAlignmentCenter)];
    [self.pager addSubview:p];
}

- (void)buildWays:(CGRect)f extra:(CGFloat)e
{
    UIView *p = [[UIView alloc] initWithFrame:f];
    CGFloat W = f.size.width;
    [p addSubview:makeLabel(L(@"Dodaj playlistę"), CGRectMake(0, 44, W, 34), 26, YES, softWhite(), NSTextAlignmentCenter)];
    [p addSubview:makeLabel(L(@"Trzy sposoby, wybierz jeden"), CGRectMake(0, 80, W, 20), 14, NO, softBlue(), NSTextAlignmentCenter)];
    NSArray *items = [NSArray arrayWithObjects:
        [NSArray arrayWithObjects:L(@"Adres z internetu"), L(@"wklej link do pliku .m3u lub .m3u8"), nil],
        [NSArray arrayWithObjects:L(@"Schowek"), L(@"jedno dotknięcie, jeśli już skopiowałeś link"), nil],
        [NSArray arrayWithObjects:L(@"Plik w aplikacji"), L(@"wyślij plik przez „Otwórz w…” albo iTunes"), nil], nil];
    CGFloat cardH = 72.0f, gap = 8.0f + e * 0.3f, y = 112 + e * 0.3f;
    for (NSUInteger i = 0; i < 3; i++) {
        [p addSubview:glassPanel(CGRectMake(16, y, W - 32, cardH))];
        UILabel *num = makeLabel([NSString stringWithFormat:@"%d", (int)i + 1], CGRectMake(30, y + 16, 40, 40), 24, YES, softWhite(), NSTextAlignmentCenter);
        num.backgroundColor = [UIColor colorWithRed:0.27f green:0.52f blue:0.92f alpha:1.0f];
        num.layer.cornerRadius = 10.0f;
        num.layer.borderWidth = 1.0f;
        num.layer.borderColor = [UIColor colorWithRed:0.02f green:0.08f blue:0.27f alpha:1.0f].CGColor;
        [p addSubview:num];
        NSArray *it = [items objectAtIndex:i];
        [p addSubview:makeLabel([it objectAtIndex:0], CGRectMake(82, y + 12, W - 104, 22), 17, YES, softWhite(), NSTextAlignmentLeft)];
        UILabel *sub = makeLabel([it objectAtIndex:1], CGRectMake(82, y + 36, W - 104, 30), 12, NO, softBlue(), NSTextAlignmentLeft);
        [p addSubview:sub];
        y += cardH + gap;
    }
    [self.pager addSubview:p];
}

- (void)buildForm:(CGRect)f extra:(CGFloat)e
{
    UIView *p = [[UIView alloc] initWithFrame:f];
    CGFloat W = f.size.width;
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"setup_icon"]];
    icon.frame = CGRectMake((W - 60) / 2.0f, 36 + e * 0.2f, 60, 60);
    [p addSubview:icon];
    CGFloat y0 = 104 + e * 0.2f;
    [p addSubview:makeLabel(L(@"Konfiguracja iSat"), CGRectMake(0, y0, W, 30), 22, YES, softWhite(), NSTextAlignmentCenter)];
    [p addSubview:makeLabel(L(@"Dodaj swoją pierwszą playlistę"), CGRectMake(0, y0 + 32, W, 18), 13, NO, softBlue(), NSTextAlignmentCenter)];
    CGFloat py = y0 + 60;
    [p addSubview:glassPanel(CGRectMake(14, py, W - 28, 186))];
    [p addSubview:makeLabel(L(@"NAZWA"), CGRectMake(28, py + 8, W - 56, 16), 11, YES, softBlue(), NSTextAlignmentLeft)];
    self.nameField = [self makeField:L(@"np. Moja telewizja") frame:CGRectMake(26, py + 26, W - 52, 32)];
    self.nameField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
    self.nameField.returnKeyType = UIReturnKeyNext;
    [p addSubview:self.nameField];
    [p addSubview:makeLabel(L(@"ADRES PLAYLISTY (M3U / M3U8)"), CGRectMake(28, py + 66, W - 56, 16), 11, YES, softBlue(), NSTextAlignmentLeft)];
    self.urlField = [self makeField:@"http://…" frame:CGRectMake(26, py + 84, W - 52, 32)];
    self.urlField.keyboardType = UIKeyboardTypeURL;
    self.urlField.returnKeyType = UIReturnKeyDone;
    [p addSubview:self.urlField];
    self.urlFieldBottom = py + 84 + 32;
    [p addSubview:barButton(L(@"Wklej adres ze schowka"), CGRectMake(26, py + 132, W - 52, 40), self, @selector(pasteTapped))];
    [self.pager addSubview:p];
}

- (void)buildLayout:(CGRect)f extra:(CGFloat)e
{
    UIView *p = [[UIView alloc] initWithFrame:f];
    CGFloat W = f.size.width;
    [p addSubview:makeLabel(L(@"Wybierz wygląd"), CGRectMake(0, 44, W, 34), 26, YES, softWhite(), NSTextAlignmentCenter)];
    [p addSubview:makeLabel(L(@"Zmienisz go później jednym przyciskiem"), CGRectMake(0, 80, W, 20), 13, NO, softBlue(), NSTextAlignmentCenter)];
    CGFloat cw = (W - 44) / 2.0f, y = 116 + e * 0.3f, ch = 220;
    for (int i = 0; i < 2; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.frame = CGRectMake(16 + i * (cw + 12), y, cw, ch);
        b.tag = i;
        [b setBackgroundImage:stretch(@"glass_panel", 14) forState:UIControlStateNormal];
        [b setBackgroundImage:stretch(@"glass_panel_sel", 14) forState:UIControlStateSelected];
        [b setBackgroundImage:stretch(@"glass_panel_sel", 14) forState:UIControlStateSelected | UIControlStateHighlighted];
        [b addTarget:self action:@selector(layoutChosen:) forControlEvents:UIControlEventTouchUpInside];
        UIImageView *mini = [[UIImageView alloc] initWithImage:[UIImage imageNamed:i == 0 ? @"setup_list" : @"setup_grid"]];
        mini.frame = CGRectMake((cw - 110) / 2.0f, 14, 110, 150);
        mini.userInteractionEnabled = NO;
        [b addSubview:mini];
        UILabel *l = makeLabel(i == 0 ? L(@"Lista") : L(@"Kafelki"), CGRectMake(0, 176, cw, 30), 17, YES, softWhite(), NSTextAlignmentCenter);
        l.userInteractionEnabled = NO;
        [b addSubview:l];
        [p addSubview:b];
        if (i == 0) self.listChoice = b; else self.gridChoice = b;
    }
    [self.pager addSubview:p];
    [self updateLayoutChoice];
}

- (void)updateLayoutChoice
{
    self.listChoice.selected = !self.gridSelected;
    self.gridChoice.selected = self.gridSelected;
}

- (void)layoutChosen:(UIButton *)b
{
    self.gridSelected = (b.tag == 1);
    [self updateLayoutChoice];
}

#pragma mark - Strony

- (void)updateControls
{
    self.dots.currentPage = self.page;
    [self.mainButton setTitle:(self.page == kPages - 1 ? L(@"Zaczynamy!") : L(@"Dalej")) forState:UIControlStateNormal];
}

- (void)scrollViewDidScroll:(UIScrollView *)sv
{
    CGFloat W = sv.bounds.size.width;
    NSInteger p = (NSInteger)((sv.contentOffset.x + W / 2.0f) / W);
    if (p < 0) p = 0;
    if (p >= kPages) p = kPages - 1;
    if (p != self.page) {
        self.page = p;
        [self.view endEditing:YES];
        [self updateControls];
    }
}

- (void)goToPage:(NSInteger)p
{
    [self.view endEditing:YES];
    [self.pager setContentOffset:CGPointMake(self.pager.bounds.size.width * p, 0) animated:YES];
}

- (void)alert:(NSString *)msg
{
    [[[UIAlertView alloc] initWithTitle:nil message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
}

/* Adres z formularza: nil i brak komunikatu, gdy pole puste; nil z komunikatem, gdy adres jest zły. */
- (NSDictionary *)playlistFromForm:(BOOL *)invalid
{
    *invalid = NO;
    NSCharacterSet *ws = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSString *url = [self.urlField.text stringByTrimmingCharactersInSet:ws];
    NSString *name = [self.nameField.text stringByTrimmingCharactersInSet:ws];
    if (![url length]) return nil;
    NSString *lower = [url lowercaseString];
    NSURL *u = [NSURL URLWithString:url];
    if (!u || !([lower hasPrefix:@"http://"] || [lower hasPrefix:@"https://"]) || ![[u host] length]) {
        *invalid = YES;
        return nil;
    }
    if (![name length]) name = [u host];
    return [NSDictionary dictionaryWithObjectsAndKeys:name, @"name", url, @"url", nil];
}

- (void)nextTapped
{
    if (self.page == 2) {                                         /* formularz: sprawdzamy adres przed pójściem dalej */
        BOOL invalid = NO;
        [self playlistFromForm:&invalid];
        if (invalid) { [self alert:L(@"Adres musi zaczynać się od http:// lub https://")]; return; }
    }
    if (self.page < kPages - 1) { [self goToPage:self.page + 1]; return; }
    BOOL invalid = NO;
    NSDictionary *pl = [self playlistFromForm:&invalid];
    if (invalid) { [self alert:L(@"Adres playlisty musi zaczynać się od http:// lub https://")]; [self goToPage:2]; return; }
    [[NSUserDefaults standardUserDefaults] setBool:self.gridSelected forKey:kLayoutKey];
    [self finishWithPlaylist:pl];
}

- (void)skipTapped
{
    [self finishWithPlaylist:nil];
}

- (void)finishWithPlaylist:(NSDictionary *)pl
{
    [self.view endEditing:YES];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kSetupDone];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self.delegate setupFinished:self playlist:pl];
}

- (void)pasteTapped
{
    NSString *s = [[UIPasteboard generalPasteboard].string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *lower = [s lowercaseString];
    if (![s length] || !([lower hasPrefix:@"http://"] || [lower hasPrefix:@"https://"])) {
        [self alert:L(@"W schowku nie ma adresu http:// ani https://. Skopiuj link do playlisty i spróbuj jeszcze raz.")];
        return;
    }
    self.urlField.text = s;
    if (![[self.nameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length]) {
        NSString *host = [[NSURL URLWithString:s] host];
        if ([host length]) self.nameField.text = host;
    }
}

#pragma mark - Pola tekstowe i klawiatura

- (BOOL)textFieldShouldReturn:(UITextField *)f
{
    if (f == self.nameField) [self.urlField becomeFirstResponder];
    else [f resignFirstResponder];
    return NO;
}

- (void)keyboardWillShow:(NSNotification *)n
{
    if (self.page != 2) return;
    CGRect kb = [[[n userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat H = self.view.bounds.size.height;
    CGFloat shift = (self.urlFieldBottom + 12.0f) - (H - kb.size.height);
    if (shift < 0) shift = 0;
    NSTimeInterval dur = [[[n userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    [UIView animateWithDuration:dur animations:^{
        CGRect fr = self.pager.frame; fr.origin.y = -shift; self.pager.frame = fr;
    }];
}

- (void)keyboardWillHide:(NSNotification *)n
{
    NSTimeInterval dur = [[[n userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    [UIView animateWithDuration:dur animations:^{
        CGRect fr = self.pager.frame; fr.origin.y = 0; self.pager.frame = fr;
    }];
}

- (UIStatusBarStyle)preferredStatusBarStyle { return UIStatusBarStyleLightContent; }

@end
