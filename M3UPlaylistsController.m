#import "M3UPlaylistsController.h"
#import "M3UChannelsController.h"
#import "M3UAddController.h"
#import "M3UStore.h"
#import "M3UTheme.h"
#import "M3UDiag.h"
#import "M3ULocalization.h"

@interface M3UPlaylistsController () <M3UAddDelegate>
@property (nonatomic, strong) NSArray *playlists;
@property (nonatomic, strong) NSArray *files;
@end

@implementation M3UPlaylistsController

M3U_ROTATE_ANY

- (id)init
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) self.title = @"iSat";
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    M3UStyleTable(self.tableView);
    self.tableView.rowHeight = 56.0f;
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:L(@"Wstecz") style:UIBarButtonItemStyleBordered target:nil action:nil];
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                           target:self action:@selector(addTapped)];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reload) name:@"M3UPlaylistsChanged" object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self reload];
}

- (void)reload
{
    self.playlists = M3UPlaylists();
    self.files = M3ULocalFiles();
    [self.tableView reloadData];
}

- (void)addTapped
{
    M3UAddController *add = [[M3UAddController alloc] init];
    add.delegate = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:add];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)addController:(M3UAddController *)c didAddName:(NSString *)name url:(NSString *)url
{
    NSMutableArray *list = [self.playlists mutableCopy];
    [list addObject:[NSDictionary dictionaryWithObjectsAndKeys:name, @"name", url, @"url", nil]];
    M3USavePlaylists(list);
    [self dismissViewControllerAnimated:YES completion:nil];
    [self reload];
}

- (void)addControllerDidCancel:(M3UAddController *)c
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Tabela (sekcje: 0 ulubione, 1 playlisty, 2 pliki)

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv
{
    return [self.files count] ? 3 : 2;
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s
{
    if (s == 0) return 1;
    if (s == 1) return (NSInteger)[self.playlists count];
    return (NSInteger)[self.files count];
}

- (NSString *)headerText:(NSInteger)s
{
    if (s == 1) return L(@"Playlisty");
    if (s == 2) return L(@"Pliki w aplikacji");
    return nil;
}

- (NSString *)footerText:(NSInteger)s
{
    if (s == 1 && ![self.playlists count])
        return L(@"Dotknij +, żeby dodać adres playlisty (.m3u lub .m3u8).");
    if (s == (NSInteger)([self.files count] ? 2 : 1))
        return L(@"Pliki .m3u wrzucisz przez iTunes (karta Aplikacje → Udostępnianie plików) albo „Otwórz w…” z Safari.");
    return nil;
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

- (UIView *)tableView:(UITableView *)tv viewForFooterInSection:(NSInteger)s
{
    NSString *t = [self footerText:s];
    return t ? M3UFooterView(t, tv.bounds.size.width) : nil;
}

- (CGFloat)tableView:(UITableView *)tv heightForFooterInSection:(NSInteger)s
{
    NSString *t = [self footerText:s];
    return t ? M3UFooterHeight(t, tv.bounds.size.width) : 0.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip
{
    static NSString *ident = @"c";
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:ident];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:ident];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    M3UStyleCell(cell);
    if (ip.section == 0) {
        cell.imageView.image = M3UGlyphTile(0, 40.0f);
        cell.textLabel.text = L(@"Ulubione");
        cell.detailTextLabel.text = [NSString stringWithFormat:L(@"Kanałów: %lu"), (unsigned long)[M3UFavorites() count]];
    } else if (ip.section == 1) {
        NSDictionary *d = [self.playlists objectAtIndex:(NSUInteger)ip.row];
        cell.imageView.image = M3UGlyphTile(1, 40.0f);
        cell.textLabel.text = [d objectForKey:@"name"];
        cell.detailTextLabel.text = [d objectForKey:@"url"];
    } else {
        NSString *f = [self.files objectAtIndex:(NSUInteger)ip.row];
        cell.imageView.image = M3UGlyphTile(2, 40.0f);
        cell.textLabel.text = f;
        cell.detailTextLabel.text = L(@"plik w aplikacji");
    }
    return cell;
}

- (BOOL)tableView:(UITableView *)tv canEditRowAtIndexPath:(NSIndexPath *)ip
{
    return ip.section == 1;
}

- (void)tableView:(UITableView *)tv commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)ip
{
    if (style != UITableViewCellEditingStyleDelete || ip.section != 1) return;
    NSMutableArray *list = [self.playlists mutableCopy];
    [list removeObjectAtIndex:(NSUInteger)ip.row];
    M3USavePlaylists(list);
    self.playlists = list;
    [tv reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationFade];
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip
{
    [tv deselectRowAtIndexPath:ip animated:YES];
    M3UBreadcrumb([NSString stringWithFormat:@"dotknięto wiersz: sekcja %d, pozycja %d", (int)ip.section, (int)ip.row]);
    M3UChannelsController *c;
    if (ip.section == 0) {
        c = [[M3UChannelsController alloc] initWithFavorites];
    } else if (ip.section == 1) {
        c = [[M3UChannelsController alloc] initWithPlaylist:[self.playlists objectAtIndex:(NSUInteger)ip.row]];
    } else {
        NSString *f = [self.files objectAtIndex:(NSUInteger)ip.row];
        c = [[M3UChannelsController alloc] initWithPlaylist:[NSDictionary dictionaryWithObjectsAndKeys:f, @"name", f, @"file", nil]];
    }
    M3UBreadcrumb(@"tworzę ekran kanałów (push)");
    [self.navigationController pushViewController:c animated:YES];
}

@end
