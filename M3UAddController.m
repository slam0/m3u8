#import "M3UAddController.h"
#import "M3UTheme.h"

@interface M3UAddController () <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *nameField;
@property (nonatomic, strong) UITextField *urlField;
@end

@implementation M3UAddController

M3U_ROTATE_ANY

- (id)init
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) self.title = @"Nowa playlista";
    return self;
}

- (UITextField *)makeField:(NSString *)placeholder
{
    UITextField *f = [[UITextField alloc] initWithFrame:CGRectMake(110, 12, 190, 24)];
    f.placeholder = placeholder;
    f.delegate = self;
    f.autocorrectionType = UITextAutocorrectionTypeNo;
    f.autocapitalizationType = UITextAutocapitalizationTypeNone;
    f.clearButtonMode = UITextFieldViewModeWhileEditing;
    f.font = [UIFont systemFontOfSize:15];
    f.keyboardAppearance = UIKeyboardAppearanceAlert;
    f.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    return f;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    M3UStyleTable(self.tableView);
    self.nameField = [self makeField:@"np. Telewizja"];
    self.nameField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
    self.nameField.returnKeyType = UIReturnKeyNext;
    self.urlField = [self makeField:@"http://…/lista.m3u8"];
    self.urlField.keyboardType = UIKeyboardTypeURL;
    self.urlField.returnKeyType = UIReturnKeyDone;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                          target:self action:@selector(cancel)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Zapisz" style:UIBarButtonItemStyleDone
                                                                             target:self action:@selector(save)];
}

- (void)cancel { [self.delegate addControllerDidCancel:self]; }

- (void)alert:(NSString *)msg
{
    [[[UIAlertView alloc] initWithTitle:nil message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
}

- (void)save
{
    [self.view endEditing:YES];
    NSString *url = [self.urlField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *name = [self.nameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *lower = [url lowercaseString];
    NSURL *u = [NSURL URLWithString:url];
    if (!u || !([lower hasPrefix:@"http://"] || [lower hasPrefix:@"https://"]) || ![[u host] length]) {
        [self alert:@"Adres musi zaczynać się od http:// lub https://"];
        return;
    }
    if (![name length]) name = [u host];
    [self.delegate addController:self didAddName:name url:url];
}

- (BOOL)textFieldShouldReturn:(UITextField *)f
{
    if (f == self.nameField) [self.urlField becomeFirstResponder];
    else [self save];
    return NO;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 2; }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return s == 0 ? 2 : 1; }

- (UIView *)tableView:(UITableView *)tv viewForFooterInSection:(NSInteger)s
{
    return s == 0 ? M3UFooterView(@"Adres playlisty skopiujesz np. z panelu swojego dostawcy IPTV.", tv.bounds.size.width) : nil;
}

- (CGFloat)tableView:(UITableView *)tv heightForFooterInSection:(NSInteger)s
{
    return s == 0 ? M3UFooterHeight(@"Adres playlisty skopiujesz np. z panelu swojego dostawcy IPTV.", tv.bounds.size.width) : 0.0f;
}

- (UIView *)tableView:(UITableView *)tv viewForHeaderInSection:(NSInteger)s
{
    return s == 0 ? M3UHeaderView(@"Dane playlisty") : nil;
}

- (CGFloat)tableView:(UITableView *)tv heightForHeaderInSection:(NSInteger)s
{
    return s == 0 ? 22.0f : 14.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    M3UStyleCell(cell);
    if (ip.section == 1) {
        cell.textLabel.text = @"Wklej adres ze schowka";
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.textLabel.textColor = M3UAccentColor();
        return cell;
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    UITextField *f = ip.row == 0 ? self.nameField : self.urlField;
    cell.textLabel.text = ip.row == 0 ? @"Nazwa" : @"Adres";
    cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
    f.textColor = M3UTextColor();
    CGRect fr = f.frame;
    fr.size.width = tv.bounds.size.width - 110 - 40;
    f.frame = fr;
    [cell.contentView addSubview:f];
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip
{
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section != 1) return;
    NSString *s = [UIPasteboard generalPasteboard].string;
    if (![s length]) { [self alert:@"Schowek jest pusty."]; return; }
    self.urlField.text = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@end
