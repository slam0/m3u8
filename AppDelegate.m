#import "AppDelegate.h"
#import "M3UPlaylistsController.h"
#import "M3UChannelsController.h"
#import "M3USetupController.h"
#import "M3UStore.h"
#import "M3UDiag.h"
#import "M3UTheme.h"

@interface AppDelegate () <M3USetupDelegate>
@property (nonatomic, strong) UINavigationController *nav;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    M3UDiagInstall();
    NSString *crash = M3UDiagCrashReportIfAny();
    M3UBreadcrumb(@"start aplikacji 1.5.1");
    M3UDiagMarkRunning(YES);
    M3UThemeApply();
    [application setStatusBarStyle:UIStatusBarStyleBlackOpaque];
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.nav = [[UINavigationController alloc] initWithRootViewController:[[M3UPlaylistsController alloc] init]];
    self.window.rootViewController = self.nav;
    [self.window makeKeyAndVisible];
    if ([M3USetupController needsSetup]) {
        /* ekran konfiguracji tylko przy pierwszym uruchomieniu (bez zapisanych playlist) */
        dispatch_async(dispatch_get_main_queue(), ^{
            M3USetupController *setup = [[M3USetupController alloc] init];
            setup.delegate = self;
            setup.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
            [self.nav presentViewController:setup animated:NO completion:nil];
        });
    }
    if (crash) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *msg = [@"Poprzednio aplikacja zamknęła się niespodziewanie (mogło też być zwykłe wyłączenie). Ostatnie kroki:\n\n" stringByAppendingString:crash];
            [[[UIAlertView alloc] initWithTitle:@"Raport" message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        });
    }
    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application { M3UDiagMarkRunning(NO); }
- (void)applicationWillTerminate:(UIApplication *)application { M3UDiagMarkRunning(NO); }
- (void)applicationDidBecomeActive:(UIApplication *)application { M3UDiagMarkRunning(YES); }

- (void)setupFinished:(M3USetupController *)c playlist:(NSDictionary *)playlist
{
    if (playlist) {
        NSMutableArray *list = [M3UPlaylists() mutableCopy];
        [list addObject:playlist];
        M3USavePlaylists(list);
        [[NSNotificationCenter defaultCenter] postNotificationName:@"M3UPlaylistsChanged" object:nil];
        /* od razu pokazujemy kanały nowej playlisty (pod spodem, zanim zniknie ekran konfiguracji) */
        [self.nav pushViewController:[[M3UChannelsController alloc] initWithPlaylist:playlist] animated:NO];
    }
    [self.nav dismissViewControllerAnimated:YES completion:nil];
}

/* „Otwórz w…” z Safari lub Poczty: kopiujemy plik do Documents i pokazujemy na liście. */
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)source annotation:(id)annotation
{
    if (![url isFileURL]) return NO;
    NSString *name = [url lastPathComponent];
    NSString *dest = [M3UDocumentsPath() stringByAppendingPathComponent:name];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (int i = 2; [fm fileExistsAtPath:dest] && i < 100; i++) {
        dest = [M3UDocumentsPath() stringByAppendingPathComponent:
                [NSString stringWithFormat:@"%@ %d.%@", [name stringByDeletingPathExtension], i, [name pathExtension]]];
    }
    BOOL ok = [fm copyItemAtPath:[url path] toPath:dest error:NULL];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"M3UPlaylistsChanged" object:nil];
    return ok;
}

@end
