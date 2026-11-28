#import "M3USettingsController.h"
#import "M3ULocalization.h"
#import "M3ULogos.h"
#import "M3UEpg.h"
#import "M3UTheme.h"
#import "AppDelegate.h"

static NSString *const kLayoutKey = @"layout_grid";

@interface M3USettingsController () <UIAlertViewDelegate>
@end

/* Kolejność motywów na liście: nSat (5) pierwszy, potem pozostałe. */
static NSInteger themeAtRow(NSInteger row) { static const NSInteger o[6] = { 5, 0, 1, 2, 3, 4 }; return (row >= 0 && row < 6) ? o[row] : 5; }

@implementation M3USettingsController

M3U_ROTATE_ANY

- (id)init
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) self.title = L(@"Ustawienia");
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    M3UStyleTable(self.tableView);
    self.tableView.rowHeight = 50.0f;
    [[NSNotificationCenter defaultCenter] addObserver:self.tableView selector:@selector(reloadData) name:M3UEpgDidUpdate object:nil];
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self.tableView]; }

/* sekcje: 0 język, 1 program TV, 2 wygląd, 3 motyw, 4 dane, 5 o aplikacji */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 6; }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s
{
    static const int rows[6] = { 3, 4, 2, 6, 2, 2 };
    return rows[s];
}

- (UIView *)tableView:(UITableView *)tv viewForHeaderInSection:(NSInteger)s
{
    NSArray *h = [NSArray arrayWithObjects:@"JĘZYK", @"PROGRAM TV (EPG)", @"WYGLĄD", @"MOTYW", @"DANE", @"O APLIKACJI", nil];
    return M3UHeaderView(L([h objectAtIndex:(NSUInteger)s]));
}

- (CGFloat)tableView:(UITableView *)tv heightForHeaderInSection:(NSInteger)s { return 22.0f; }
- (CGFloat)tableView:(UITableView *)tv heightForFooterInSection:(NSInteger)s { return 0.0f; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip
{
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    M3UStyleCell(c);
    c.selectionStyle = UITableViewCellSelectionStyleBlue;
    if (ip.section == 0) {
        NSArray *codes = [NSArray arrayWithObjects:@"pl", @"en", @"ru", nil];
        NSArray *names = [NSArray arrayWithObjects:@"Polski", @"English", @"Русский", nil];
        c.textLabel.text = [names objectAtIndex:(NSUInteger)ip.row];
        BOOL on = [[codes objectAtIndex:(NSUInteger)ip.row] isEqualToString:M3UCurrentLanguage()];
        c.accessoryType = on ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    } else if (ip.section == 1) {
        if (ip.row == 0) {
            c.textLabel.text = L(@"Pokazuj program");
            UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectZero];
            sw.on = M3UEpgEnabled();
            [sw addTarget:self action:@selector(epgSwitched:) forControlEvents:UIControlEventValueChanged];
            c.accessoryView = sw;
            c.selectionStyle = UITableViewCellSelectionStyleNone;
        } else if (ip.row == 1) {
            c.textLabel.text = L(@"Adres programu (EPG)");
            c.detailTextLabel.text = [M3UEpgURL() isEqualToString:M3UEpgDefaultURL] ? L(@"domyślny") : L(@"własny");
            c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else if (ip.row == 2) {
            c.textLabel.text = L(@"Odśwież program teraz");
            c.detailTextLabel.text = M3UEpgStatus() ?: @"";
        } else {
            c.textLabel.text = L(@"Kanałów w programie");
            c.detailTextLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)M3UEpgChannelCount()];
            c.selectionStyle = UITableViewCellSelectionStyleNone;
        }
    } else if (ip.section == 2 && ip.row == 1) {
        c.textLabel.text = L(@"Wznów ostatni kanał po uruchomieniu");
        c.textLabel.numberOfLines = 2;
        UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectZero];
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        sw.on = [ud objectForKey:@"resume_last"] ? [ud boolForKey:@"resume_last"] : YES;
        [sw addTarget:self action:@selector(resumeSwitched:) forControlEvents:UIControlEventValueChanged];
        c.accessoryView = sw;
        c.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (ip.section == 2) {
        c.textLabel.text = L(@"Kafelki zamiast listy");
        UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectZero];
        sw.on = [[NSUserDefaults standardUserDefaults] boolForKey:kLayoutKey];
        [sw addTarget:self action:@selector(layoutSwitched:) forControlEvents:UIControlEventValueChanged];
        c.accessoryView = sw;
        c.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (ip.section == 3) {
        c.textLabel.text = L(M3UThemeName(themeAtRow(ip.row)));
        c.accessoryType = (themeAtRow(ip.row) == M3UThemeIndex()) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    } else if (ip.section == 4) {
        if (ip.row == 0) {
            c.textLabel.text = L(@"Wyczyść pamięć logo");
            c.detailTextLabel.text = [NSString stringWithFormat:@"%.1f MB", (double)M3ULogoCacheBytes() / 1048576.0];
        } else {
            c.textLabel.text = L(@"Pokaż ekran startowy");
            c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    } else if (ip.row == 0) {
        c.textLabel.text = @"nSat";
        NSString *v = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"] ?: @"";
        c.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", L(@"Wersja"), v];
        c.selectionStyle = UITableViewCellSelectionStyleNone;
    } else {
        c.textLabel.text = L(@"Autor");
        c.detailTextLabel.text = @"nazar0vsky (slam0)";
        c.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return c;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip
{
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section == 0) {
        NSString *code = [[NSArray arrayWithObjects:@"pl", @"en", @"ru", nil] objectAtIndex:(NSUInteger)ip.row];
        if ([code isEqualToString:M3UCurrentLanguage()]) return;
        M3USetLanguage(code);              /* AppDelegate odbuduje ekrany w nowym języku */
    } else if (ip.section == 1 && ip.row == 1) {
        UIAlertView *a = [[UIAlertView alloc] initWithTitle:L(@"Adres programu (EPG)")
                                                    message:L(@"Wpisz adres pliku programu (JSON). Puste pole przywraca adres domyślny.")
                                                   delegate:self cancelButtonTitle:L(@"Anuluj") otherButtonTitles:L(@"Zapisz"), nil];
        a.alertViewStyle = UIAlertViewStylePlainTextInput;
        UITextField *f = [a textFieldAtIndex:0];
        f.text = M3UEpgURL();
        f.keyboardType = UIKeyboardTypeURL;
        f.autocorrectionType = UITextAutocorrectionTypeNo;
        f.autocapitalizationType = UITextAutocapitalizationTypeNone;
        [a show];
    } else if (ip.section == 1 && ip.row == 2) {
        M3UEpgRefresh(YES);
    } else if (ip.section == 3) {
        M3USetTheme(themeAtRow(ip.row));               /* AppDelegate odbuduje ekrany w nowym motywie */
    } else if (ip.section == 4 && ip.row == 0) {
        M3UClearLogoCache();
        [tv reloadRowsAtIndexPaths:[NSArray arrayWithObject:ip] withRowAnimation:UITableViewRowAnimationNone];
        [[[UIAlertView alloc] initWithTitle:nil message:L(@"Pamięć logo wyczyszczona. Logo pobiorą się ponownie.") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    } else if (ip.section == 4 && ip.row == 1) {
        [(AppDelegate *)[UIApplication sharedApplication].delegate showSetup];
    }
}

- (void)epgSwitched:(UISwitch *)sw { M3UEpgSetEnabled(sw.on); }

- (void)alertView:(UIAlertView *)a clickedButtonAtIndex:(NSInteger)i
{
    if (i == a.cancelButtonIndex) return;
    M3UEpgSetURL([[a textFieldAtIndex:0] text]);
    M3UEpgRefresh(YES);
    [self.tableView reloadData];
}

- (void)resumeSwitched:(UISwitch *)sw
{
    [[NSUserDefaults standardUserDefaults] setBool:sw.on forKey:@"resume_last"];
}

- (void)layoutSwitched:(UISwitch *)sw
{
    [[NSUserDefaults standardUserDefaults] setBool:sw.on forKey:kLayoutKey];
}

@end
