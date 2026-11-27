#import "M3USetupController.h"
#import <QuartzCore/QuartzCore.h>
#import "M3UTheme.h"
#import "M3UStore.h"
#import "M3ULocalization.h"

static NSString *const kSetupDone = @"setup_done";
static NSString *const kLayoutKey = @"layout_grid";
static const NSInteger kPages = 5;          /* 0 język, 1 powitanie, 2 sposoby, 3 formularz, 4 wygląd */
static const NSInteger kFormPage = 3;

@interface M3USetupController () <UIScrollViewDelegate, UITextFieldDelegate, UIPickerViewDataSource, UIPickerViewDelegate>
@property (nonatomic, strong) UIScrollView *pager;
@property (nonatomic, strong) UIView *progress;
@property (nonatomic, strong) NSMutableArray *segments;
@property (nonatomic, strong) UIButton *mainButton;
@property (nonatomic, strong) UIButton *skipButton;
@property (nonatomic, strong) UITextField *nameField;
@property (nonatomic, strong) UITextField *urlField;
@property (nonatomic, strong) UIButton *listChoice;
@property (nonatomic, strong) UIButton *gridChoice;
@property (nonatomic, strong) UIView *listRadio;
@property (nonatomic, strong) UIView *gridRadio;
@property (nonatomic, strong) UIPickerView *picker;
@property (nonatomic, strong) NSMutableArray *regs;        /* napisy do odświeżenia po zmianie języka: {widok, klucz, rodzaj} */
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

static UIColor *coral(void) { return [UIColor colorWithRed:1.0f green:100 / 255.0f blue:86 / 255.0f alpha:1.0f]; }
static UIColor *softBlue(void) { return [UIColor colorWithRed:170 / 255.0f green:205 / 255.0f blue:250 / 255.0f alpha:1.0f]; }

static UIImage *stretchH(NSString *name, CGFloat cap)          /* rozciągany tylko poziomo (przyciski) */
{
    return [[UIImage imageNamed:name] resizableImageWithCapInsets:UIEdgeInsetsMake(0, cap, 0, cap)];
}

static UIImage *stretchAll(NSString *name, CGFloat cap)
{
    return [[UIImage imageNamed:name] resizableImageWithCapInsets:UIEdgeInsetsMake(cap, cap, cap, cap)];
}

enum { kRegText = 0, kRegPlaceholder = 1, kRegTitle = 2 };

- (void)reg:(UIView *)v key:(NSString *)key kind:(int)kind
{
    [self.regs addObject:[NSArray arrayWithObjects:v, key, [NSNumber numberWithInt:kind], nil]];
}

/* Napis z kluczem tłumaczenia: odświeża się sam po zmianie języka na pierwszym ekranie. */
- (UILabel *)label:(NSString *)key frame:(CGRect)frame size:(CGFloat)size bold:(BOOL)bold color:(UIColor *)color align:(NSTextAlignment)align
{
    UILabel *l = [[UILabel alloc] initWithFrame:frame];
    l.backgroundColor = [UIColor clearColor];
    l.text = L(key);
    l.textColor = color;
    l.textAlignment = align;
    l.font = bold ? [UIFont boldSystemFontOfSize:size] : [UIFont systemFontOfSize:size];
    l.shadowColor = [UIColor colorWithRed:0 green:0.03f blue:0.16f alpha:0.75f];
    l.shadowOffset = CGSizeMake(0, 1);
    l.numberOfLines = 0;
    [self reg:l key:key kind:kRegText];
    return l;
}

- (UILabel *)plain:(NSString *)text frame:(CGRect)frame size:(CGFloat)size bold:(BOOL)bold color:(UIColor *)color align:(NSTextAlignment)align
{
    UILabel *l = [[UILabel alloc] initWithFrame:frame];
    l.backgroundColor = [UIColor clearColor];
    l.text = text;
    l.textColor = color;
    l.textAlignment = align;
    l.font = bold ? [UIFont boldSystemFontOfSize:size] : [UIFont systemFontOfSize:size];
    l.shadowColor = [UIColor colorWithRed:0 green:0.03f blue:0.16f alpha:0.75f];
    l.shadowOffset = CGSizeMake(0, 1);
    return l;
}

- (UIButton *)ghostButton:(NSString *)key frame:(CGRect)frame action:(SEL)action
{
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.frame = frame;
    [b setBackgroundImage:stretchH(@"setup_ghost", 18) forState:UIControlStateNormal];
    [b setBackgroundImage:stretchH(@"setup_ghost_pressed", 18) forState:UIControlStateHighlighted];
    [b setTitle:L(key) forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [b setTitleColor:[UIColor colorWithRed:0.88f green:0.93f blue:1.0f alpha:1.0f] forState:UIControlStateNormal];
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self reg:b key:key kind:kRegTitle];
    return b;
}

- (UITextField *)makeField:(NSString *)placeholderKey placeholder:(NSString *)raw frame:(CGRect)f
{
    UITextField *t = [[UITextField alloc] initWithFrame:f];
    t.borderStyle = UITextBorderStyleNone;
    t.background = stretchAll(@"setup_field", 14);
    t.textColor = [UIColor whiteColor];
    t.font = [UIFont systemFontOfSize:15];
    t.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 10)];
    t.leftViewMode = UITextFieldViewModeAlways;
    t.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    t.autocorrectionType = UITextAutocorrectionTypeNo;
    t.autocapitalizationType = UITextAutocapitalizationTypeNone;
    t.clearButtonMode = UITextFieldViewModeWhileEditing;
    t.keyboardAppearance = UIKeyboardAppearanceAlert;
    t.delegate = self;
    [self setPlaceholder:placeholderKey ? L(placeholderKey) : raw forField:t];
    if (placeholderKey) [self reg:t key:placeholderKey kind:kRegPlaceholder];
    return t;
}

- (void)setPlaceholder:(NSString *)text forField:(UITextField *)t
{
    UIColor *c = [UIColor colorWithRed:110 / 255.0f green:130 / 255.0f blue:175 / 255.0f alpha:1.0f];
    if ([t respondsToSelector:@selector(setAttributedPlaceholder:)]) {
        t.attributedPlaceholder = [[NSAttributedString alloc] initWithString:text attributes:[NSDictionary dictionaryWithObject:c forKey:NSForegroundColorAttributeName]];
    } else {
        t.placeholder = text;
    }
}

- (UIView *)radio:(CGPoint)center
{
    UIView *r = [[UIView alloc] initWithFrame:CGRectMake(center.x - 8, center.y - 8, 16, 16)];
    r.layer.cornerRadius = 8.0f;
    r.layer.borderWidth = 1.5f;
    r.userInteractionEnabled = NO;
    UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(4.5f, 4.5f, 7, 7)];
    dot.layer.cornerRadius = 3.5f;
    dot.backgroundColor = coral();
    dot.tag = 7;
    [r addSubview:dot];
    return r;
}

#pragma mark - Widok

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.regs = [NSMutableArray array];
    self.gridSelected = YES;                                   /* kafelki wybrane na start */
    CGRect b = self.view.bounds;
    CGFloat W = b.size.width, H = b.size.height;
    [self.view addSubview:M3UBackdropViewNSat(b)];

    self.pager = [[UIScrollView alloc] initWithFrame:b];
    self.pager.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.pager.pagingEnabled = YES;
    self.pager.showsHorizontalScrollIndicator = NO;
    self.pager.alwaysBounceHorizontal = NO;
    self.pager.bounces = NO;
    self.pager.delegate = self;
    self.pager.contentSize = CGSizeMake(W * kPages, H);
    [self.view addSubview:self.pager];

    /* na iPadzie treść stoi w wąskiej kolumnie pośrodku, jak na telefonie */
    CGFloat cw = W > 480.0f ? 420.0f : W, cx = (W - cw) / 2.0f;
    for (NSInteger i = 0; i < kPages; i++) {
        CGRect f = CGRectMake(W * i + cx, 0, cw, H);
        switch (i) {
            case 0: [self buildLanguage:f]; break;
            case 1: [self buildWelcome:f]; break;
            case 2: [self buildWays:f]; break;
            case 3: [self buildForm:f]; break;
            default: [self buildLayout:f]; break;
        }
    }

    /* pasek postępu: pięć segmentów u góry */
    self.progress = [[UIView alloc] initWithFrame:CGRectMake(cx + 18, 16, 5 * 39, 3)];
    self.segments = [NSMutableArray array];
    for (int i = 0; i < 5; i++) {
        CALayer *s = [CALayer layer];
        s.frame = CGRectMake(i * 39, 0, 35, 3);
        s.cornerRadius = 1.5f;
        [self.progress.layer addSublayer:s];
        [self.segments addObject:s];
    }
    [self.view addSubview:self.progress];

    self.mainButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.mainButton.frame = CGRectMake((W - 190) / 2.0f, H - 58, 190, 44);
    self.mainButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
    [self.mainButton setBackgroundImage:stretchH(@"setup_btn", 24) forState:UIControlStateNormal];
    [self.mainButton setBackgroundImage:stretchH(@"setup_btn_pressed", 24) forState:UIControlStateHighlighted];
    self.mainButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [self.mainButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.mainButton setTitleShadowColor:[UIColor colorWithRed:0.3f green:0.02f blue:0.04f alpha:0.8f] forState:UIControlStateNormal];
    self.mainButton.titleLabel.shadowOffset = CGSizeMake(0, -1);
    [self.mainButton addTarget:self action:@selector(nextTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.mainButton];

    self.skipButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.skipButton.frame = CGRectMake(W - cx - 96, 4, 84, 30);
    self.skipButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    self.skipButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    self.skipButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    [self.skipButton setTitle:L(@"Pomiń") forState:UIControlStateNormal];
    [self.skipButton setTitleColor:[UIColor colorWithRed:200 / 255.0f green:222 / 255.0f blue:1.0f alpha:1.0f] forState:UIControlStateNormal];
    [self.skipButton setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
    [self.skipButton addTarget:self action:@selector(skipTapped) forControlEvents:UIControlEventTouchUpInside];
    [self reg:self.skipButton key:@"Pomiń" kind:kRegTitle];
    [self.view addSubview:self.skipButton];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [nc addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [self updateControls];
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (BOOL)compact { return self.view.bounds.size.height < 500.0f; }

/* 0: wybór języka (kółko UIPickerView) */
- (void)buildLanguage:(CGRect)f
{
    UIView *p = [[UIView alloc] initWithFrame:f];
    CGFloat W = f.size.width; BOOL c = [self compact];
    UIImage *li = [UIImage imageNamed:@"setup_logo"];
    CGFloat lw = c ? 170 : 220, lh = lw * li.size.height / li.size.width;
    UIImageView *logo = [[UIImageView alloc] initWithImage:li];
    logo.frame = CGRectMake((W - lw) / 2.0f, c ? 24 : 36, lw, lh);
    [p addSubview:logo];
    CGFloat y = CGRectGetMaxY(logo.frame) + (c ? 6 : 8);
    [p addSubview:[self label:@"Wybierz język" frame:CGRectMake(0, y, W, 28) size:22 bold:YES color:[UIColor whiteColor] align:NSTextAlignmentCenter]];
    [p addSubview:[self plain:@"Choose language  ·  Выберите язык" frame:CGRectMake(0, y + 28, W, 18) size:13 bold:NO color:softBlue() align:NSTextAlignmentCenter]];
    self.picker = [[UIPickerView alloc] initWithFrame:CGRectMake((W - 260) / 2.0f, y + 56, 260, 162)];
    self.picker.dataSource = self;
    self.picker.delegate = self;
    self.picker.showsSelectionIndicator = YES;
    NSString *cur = M3UCurrentLanguage();
    [self.picker selectRow:([cur isEqualToString:@"en"] ? 1 : ([cur isEqualToString:@"ru"] ? 2 : 0)) inComponent:0 animated:NO];
    [p addSubview:self.picker];
    if (!c) [p addSubview:[self label:@"Język zmienisz później w Ustawieniach" frame:CGRectMake(16, y + 56 + 162 + 12, W - 32, 18) size:11 bold:NO color:[UIColor colorWithRed:200 / 255.0f green:222 / 255.0f blue:1.0f alpha:1.0f] align:NSTextAlignmentCenter]];
    [self.pager addSubview:p];
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pv { return 1; }
- (NSInteger)pickerView:(UIPickerView *)pv numberOfRowsInComponent:(NSInteger)c { return 3; }
- (NSString *)pickerView:(UIPickerView *)pv titleForRow:(NSInteger)row forComponent:(NSInteger)c
{
    return row == 0 ? @"Polski" : (row == 1 ? @"English" : @"Русский");
}
- (void)pickerView:(UIPickerView *)pv didSelectRow:(NSInteger)row inComponent:(NSInteger)c
{
    M3USetLanguageQuiet(row == 0 ? @"pl" : (row == 1 ? @"en" : @"ru"));
    [self refreshTexts];
}

/* Po wyborze języka odświeżamy wszystkie napisy na pozostałych ekranach. */
- (void)refreshTexts
{
    for (NSArray *r in self.regs) {
        UIView *v = [r objectAtIndex:0];
        NSString *key = [r objectAtIndex:1];
        int kind = [[r objectAtIndex:2] intValue];
        if (kind == kRegText) ((UILabel *)v).text = L(key);
        else if (kind == kRegTitle) [(UIButton *)v setTitle:L(key) forState:UIControlStateNormal];
        else [self setPlaceholder:L(key) forField:(UITextField *)v];
    }
    [self updateControls];
}

/* 1: powitanie */
- (void)buildWelcome:(CGRect)f
{
    UIView *p = [[UIView alloc] initWithFrame:f];
    CGFloat W = f.size.width; BOOL c = [self compact];
    UIImage *li = [UIImage imageNamed:@"setup_logo"];
    CGFloat lw = c ? 270 : 300, lh = lw * li.size.height / li.size.width;
    CGFloat extra = (self.view.bounds.size.height > 560.0f) ? MIN(80.0f, (self.view.bounds.size.height - 548.0f) * 0.3f) : 0;
    UIImageView *logo = [[UIImageView alloc] initWithImage:li];
    logo.frame = CGRectMake((W - lw) / 2.0f, (c ? 56 : 95) + extra, lw, lh);
    [p addSubview:logo];
    CGFloat y = CGRectGetMaxY(logo.frame) + (c ? 12 : 44);
    [p addSubview:[self label:@"Witaj!" frame:CGRectMake(0, y, W, 36) size:28 bold:YES color:[UIColor whiteColor] align:NSTextAlignmentCenter]];
    [p addSubview:[self label:@"Skonfigurujemy wszystko w kilka chwil" frame:CGRectMake(20, y + 40, W - 40, 40) size:14 bold:NO color:softBlue() align:NSTextAlignmentCenter]];
    [self.pager addSubview:p];
}

/* 2: trzy sposoby (kulki na orbicie) */
- (void)buildWays:(CGRect)f
{
    UIView *p = [[UIView alloc] initWithFrame:f];
    CGFloat W = f.size.width; BOOL c = [self compact];
    UIImage *ii = [UIImage imageNamed:@"setup_info"];
    UIImageView *info = [[UIImageView alloc] initWithImage:ii];
    info.frame = CGRectMake((W - ii.size.width) / 2.0f, c ? 14 : 38, ii.size.width, ii.size.height);
    [p addSubview:info];
    CGFloat ty = c ? 88 : 128;
    [p addSubview:[self label:@"Dodaj playlistę" frame:CGRectMake(0, ty, W, 28) size:22 bold:YES color:[UIColor whiteColor] align:NSTextAlignmentCenter]];
    [p addSubview:[self label:@"Trzy sposoby, wybierz jeden" frame:CGRectMake(0, ty + 28, W, 18) size:13 bold:NO color:softBlue() align:NSTextAlignmentCenter]];
    NSArray *items = [NSArray arrayWithObjects:
        [NSArray arrayWithObjects:@"Adres z internetu", @"wklej link do pliku .m3u lub .m3u8", nil],
        [NSArray arrayWithObjects:@"Schowek", @"jedno dotknięcie, jeśli już skopiowałeś link", nil],
        [NSArray arrayWithObjects:@"Plik w aplikacji", @"wyślij plik przez „Otwórz w…” albo iTunes", nil], nil];
    CGFloat X = 46, y0 = c ? 186 : 232, dy = c ? 72 : 85;
    CAShapeLayer *line = [CAShapeLayer layer];                   /* przerywana linia orbity między kulkami */
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(X, y0 + 21)];
    [path addLineToPoint:CGPointMake(X, y0 + 2 * dy - 21)];
    line.path = path.CGPath;
    line.strokeColor = [UIColor colorWithRed:150 / 255.0f green:200 / 255.0f blue:1.0f alpha:0.8f].CGColor;
    line.fillColor = nil;
    line.lineWidth = 1.5f;
    line.lineDashPattern = [NSArray arrayWithObjects:[NSNumber numberWithInt:5], [NSNumber numberWithInt:6], nil];
    [p.layer addSublayer:line];
    for (NSUInteger i = 0; i < 3; i++) {
        CGFloat y = y0 + i * dy;
        UIImageView *sp = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"setup_sphere"]];
        sp.frame = CGRectMake(X - 23, y - 23, 46, 46);
        [p addSubview:sp];
        UILabel *n = [self plain:[NSString stringWithFormat:@"%d", (int)i + 1] frame:CGRectMake(X - 23, y - 12, 46, 22) size:17 bold:YES color:[UIColor whiteColor] align:NSTextAlignmentCenter];
        [p addSubview:n];
        NSArray *it = [items objectAtIndex:i];
        [p addSubview:[self label:[it objectAtIndex:0] frame:CGRectMake(76, y - 19, W - 92, 22) size:16 bold:YES color:[UIColor whiteColor] align:NSTextAlignmentLeft]];
        [p addSubview:[self label:[it objectAtIndex:1] frame:CGRectMake(76, y + 4, W - 92, 32) size:12 bold:NO color:softBlue() align:NSTextAlignmentLeft]];
    }
    [self.pager addSubview:p];
}

/* 3: formularz */
- (void)buildForm:(CGRect)f
{
    UIView *p = [[UIView alloc] initWithFrame:f];
    CGFloat W = f.size.width; BOOL c = [self compact];
    UIImage *li = [UIImage imageNamed:@"setup_logo"];
    CGFloat lw = c ? 110 : 180, lh = lw * li.size.height / li.size.width;
    UIImageView *logo = [[UIImageView alloc] initWithImage:li];
    logo.frame = CGRectMake((W - lw) / 2.0f, c ? 26 : 36, lw, lh);
    [p addSubview:logo];
    CGFloat ty = CGRectGetMaxY(logo.frame) + (c ? 4 : 8);
    [p addSubview:[self label:@"Dodaj swoją pierwszą playlistę" frame:CGRectMake(10, ty, W - 20, 24) size:18 bold:YES color:[UIColor whiteColor] align:NSTextAlignmentCenter]];
    [p addSubview:[self label:@"Nazwę możesz zmienić później" frame:CGRectMake(0, ty + 26, W, 16) size:12 bold:NO color:softBlue() align:NSTextAlignmentCenter]];
    CGFloat cy = ty + (c ? 52 : 58), fh = c ? 38 : 43, step = c ? 62 : 80;
    CGFloat ch = (c ? 26 : 32) + fh * 2 + (step - fh) + (c ? 50 : 54);
    UIImageView *card = [[UIImageView alloc] initWithImage:stretchAll(@"setup_card", 16)];
    card.frame = CGRectMake(18, cy, W - 36, ch);
    [p addSubview:card];
    CGFloat fy = cy + (c ? 24 : 36);
    [p addSubview:[self label:@"NAZWA" frame:CGRectMake(32, fy - (c ? 20 : 22), W - 64, 16) size:10 bold:YES color:[UIColor colorWithRed:150 / 255.0f green:190 / 255.0f blue:1.0f alpha:1.0f] align:NSTextAlignmentLeft]];
    self.nameField = [self makeField:@"np. Moja telewizja" placeholder:nil frame:CGRectMake(32, fy, W - 64, fh)];
    self.nameField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
    self.nameField.returnKeyType = UIReturnKeyNext;
    [p addSubview:self.nameField];
    CGFloat fy2 = fy + step;
    [p addSubview:[self label:@"ADRES PLAYLISTY (M3U / M3U8)" frame:CGRectMake(32, fy2 - (c ? 20 : 22), W - 64, 16) size:10 bold:YES color:[UIColor colorWithRed:150 / 255.0f green:190 / 255.0f blue:1.0f alpha:1.0f] align:NSTextAlignmentLeft]];
    self.urlField = [self makeField:nil placeholder:@"http://…" frame:CGRectMake(32, fy2, W - 64, fh)];
    self.urlField.keyboardType = UIKeyboardTypeURL;
    self.urlField.returnKeyType = UIReturnKeyDone;
    [p addSubview:self.urlField];
    self.urlFieldBottom = fy2 + fh;
    [p addSubview:[self ghostButton:@"Wklej adres ze schowka" frame:CGRectMake(32, fy2 + fh + 10, W - 64, 34) action:@selector(pasteTapped)]];
    [self.pager addSubview:p];
}

/* 4: wybór wyglądu */
- (void)buildLayout:(CGRect)f
{
    UIView *p = [[UIView alloc] initWithFrame:f];
    CGFloat W = f.size.width; BOOL c = [self compact];
    CGFloat ty = c ? 40 : 56;
    [p addSubview:[self label:@"Wybierz wygląd" frame:CGRectMake(0, ty, W, 30) size:22 bold:YES color:[UIColor whiteColor] align:NSTextAlignmentCenter]];
    [p addSubview:[self label:@"Zmienisz go później jednym przyciskiem" frame:CGRectMake(0, ty + 30, W, 18) size:13 bold:NO color:softBlue() align:NSTextAlignmentCenter]];
    CGFloat cw = (W - 44) / 2.0f, y = c ? 108 : 115, ch = c ? 232 : 265;
    for (int i = 0; i < 2; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.frame = CGRectMake(18 + i * (cw + 8), y, cw, ch);
        b.tag = i;
        [b setBackgroundImage:stretchAll(@"setup_card", 16) forState:UIControlStateNormal];
        [b setBackgroundImage:stretchAll(@"setup_card_sel", 16) forState:UIControlStateSelected];
        [b setBackgroundImage:stretchAll(@"setup_card_sel", 16) forState:UIControlStateSelected | UIControlStateHighlighted];
        [b addTarget:self action:@selector(layoutChosen:) forControlEvents:UIControlEventTouchUpInside];
        UIImageView *mini = [[UIImageView alloc] initWithImage:[UIImage imageNamed:i == 0 ? @"setup_list" : @"setup_grid"]];
        mini.frame = CGRectMake((cw - 110) / 2.0f, 14, 110, 150);
        mini.userInteractionEnabled = NO;
        [b addSubview:mini];
        UILabel *l = [self label:(i == 0 ? @"Lista" : @"Kafelki") frame:CGRectMake(0, ch - 54, cw, 24) size:16 bold:YES color:[UIColor whiteColor] align:NSTextAlignmentCenter];
        l.userInteractionEnabled = NO;
        [b addSubview:l];
        UIView *r = [self radio:CGPointMake(cw / 2.0f, ch - 20)];
        [b addSubview:r];
        [p addSubview:b];
        if (i == 0) { self.listChoice = b; self.listRadio = r; } else { self.gridChoice = b; self.gridRadio = r; }
    }
    [self.pager addSubview:p];
    [self updateLayoutChoice];
}

- (void)styleRadio:(UIView *)r on:(BOOL)on
{
    r.layer.borderColor = (on ? coral() : [UIColor colorWithRed:170 / 255.0f green:200 / 255.0f blue:1.0f alpha:0.65f]).CGColor;
    [r viewWithTag:7].hidden = !on;
}

- (void)updateLayoutChoice
{
    self.listChoice.selected = !self.gridSelected;
    self.gridChoice.selected = self.gridSelected;
    [self styleRadio:self.listRadio on:!self.gridSelected];
    [self styleRadio:self.gridRadio on:self.gridSelected];
}

- (void)layoutChosen:(UIButton *)b
{
    self.gridSelected = (b.tag == 1);
    [self updateLayoutChoice];
}

#pragma mark - Strony

- (void)updateControls
{
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (NSInteger i = 0; i < (NSInteger)[self.segments count]; i++) {
        CALayer *s = [self.segments objectAtIndex:(NSUInteger)i];
        s.backgroundColor = (i <= self.page ? coral() : [UIColor colorWithWhite:1.0f alpha:0.2f]).CGColor;
    }
    [CATransaction commit];
    self.skipButton.hidden = (self.page == 0 || self.page == kPages - 1);          /* na wyborze języka i na końcu „Pomiń” nie ma */
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
    if (self.page == kFormPage) {                                 /* formularz: sprawdzamy adres przed pójściem dalej */
        BOOL invalid = NO;
        [self playlistFromForm:&invalid];
        if (invalid) { [self alert:L(@"Adres musi zaczynać się od http:// lub https://")]; return; }
    }
    if (self.page < kPages - 1) { [self goToPage:self.page + 1]; return; }
    BOOL invalid = NO;
    NSDictionary *pl = [self playlistFromForm:&invalid];
    if (invalid) { [self alert:L(@"Adres playlisty musi zaczynać się od http:// lub https://")]; [self goToPage:kFormPage]; return; }
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

- (void)textFieldDidBeginEditing:(UITextField *)f { f.background = stretchAll(@"setup_field_focus", 14); }
- (void)textFieldDidEndEditing:(UITextField *)f { f.background = stretchAll(@"setup_field", 14); }

- (BOOL)textFieldShouldReturn:(UITextField *)f
{
    if (f == self.nameField) [self.urlField becomeFirstResponder];
    else [f resignFirstResponder];
    return NO;
}

- (void)keyboardWillShow:(NSNotification *)n
{
    if (self.page != kFormPage) return;
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
