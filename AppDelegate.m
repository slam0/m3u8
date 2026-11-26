#import "AppDelegate.h"
#import "M3UPlaylistsController.h"
#import "M3UStore.h"
#import "M3UTheme.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    M3UThemeApply();
    [application setStatusBarStyle:UIStatusBarStyleBlackOpaque];
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:[[M3UPlaylistsController alloc] init]];
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    return YES;
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
