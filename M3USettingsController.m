#import "M3USettingsController.h"
#import "M3ULocalization.h"
#import "M3ULogos.h"
#import "M3UTheme.h"
#import "AppDelegate.h"

static NSString *const kLayoutKey = @"layout_grid";

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
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 4; }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s
{
    static const int rows[4] = { 3, 1, 2, 1 };
    return rows[s];
}

- (UIView *)tableView:(UITableView *)tv viewForHeaderInSection:(NSInteger)s
{
    NSArray *h = [NSArray arrayWithObjects:@"JĘZYK", @"WYGLĄD", @"DANE", @"O APLIKACJI", nil];
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
        c.textLabel.text = L(@"Kafelki zamiast listy");
        UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectZero];
        sw.on = [[NSUserDefaults standardUserDefaults] boolForKey:kLayoutKey];
        [sw addTarget:self action:@selector(layoutSwitched:) forControlEvents:UIControlEventValueChanged];
        c.accessoryView = sw;
        c.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (ip.section == 2) {
        if (ip.row == 0) {
            c.textLabel.text = L(@"Wyczyść pamięć logo");
            c.detailTextLabel.text = [NSString stringWithFormat:@"%.1f MB", (double)M3ULogoCacheBytes() / 1048576.0];
        } else {
            c.textLabel.text = L(@"Pokaż ekran startowy");
            c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    } else {
        c.textLabel.text = @"iSat";
        NSString *v = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"] ?: @"";
        c.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", L(@"Wersja"), v];
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
    } else if (ip.section == 2 && ip.row == 0) {
        M3UClearLogoCache();
        [tv reloadRowsAtIndexPaths:[NSArray arrayWithObject:ip] withRowAnimation:UITableViewRowAnimationNone];
        [[[UIAlertView alloc] initWithTitle:nil message:L(@"Pamięć logo wyczyszczona. Logo pobiorą się ponownie.") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    } else if (ip.section == 2 && ip.row == 1) {
        [(AppDelegate *)[UIApplication sharedApplication].delegate showSetup];
    }
}

- (void)layoutSwitched:(UISwitch *)sw
{
    [[NSUserDefaults standardUserDefaults] setBool:sw.on forKey:kLayoutKey];
}

@end
