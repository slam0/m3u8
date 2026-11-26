#import "M3UStore.h"

static NSString *const kPlaylists = @"playlists";
static NSString *const kFavorites = @"favorites";

NSArray *M3UPlaylists(void)
{
    NSArray *a = [[NSUserDefaults standardUserDefaults] arrayForKey:kPlaylists];
    return a ? a : [NSArray array];
}

void M3USavePlaylists(NSArray *list)
{
    [[NSUserDefaults standardUserDefaults] setObject:list forKey:kPlaylists];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

NSArray *M3UFavorites(void)
{
    NSArray *a = [[NSUserDefaults standardUserDefaults] arrayForKey:kFavorites];
    return a ? a : [NSArray array];
}

BOOL M3UIsFavorite(NSString *url)
{
    for (NSDictionary *d in M3UFavorites())
        if ([[d objectForKey:@"url"] isEqualToString:url]) return YES;
    return NO;
}

void M3UToggleFavorite(NSString *name, NSString *url, NSString *group, NSString *logo)
{
    NSMutableArray *list = [M3UFavorites() mutableCopy];
    for (NSUInteger i = 0; i < [list count]; i++) {
        if ([[[list objectAtIndex:i] objectForKey:@"url"] isEqualToString:url]) {
            [list removeObjectAtIndex:i];
            goto save;
        }
    }
    [list addObject:[NSDictionary dictionaryWithObjectsAndKeys:name ?: @"", @"name", url, @"url", group ?: @"", @"group", logo ?: @"", @"logo", nil]];
save:
    [[NSUserDefaults standardUserDefaults] setObject:list forKey:kFavorites];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

static NSString *cachePath(NSString *key)
{
    unsigned long h = 5381;
    const char *c = [key UTF8String];
    while (c && *c) h = h * 33 + (unsigned char)*c++;
    NSString *dir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    return [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"lista-%lx.m3u", h]];
}

NSString *M3UCachedText(NSString *key)
{
    return [NSString stringWithContentsOfFile:cachePath(key) encoding:NSUTF8StringEncoding error:NULL];
}

void M3USaveCachedText(NSString *key, NSString *text)
{
    [text writeToFile:cachePath(key) atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

NSString *M3UDocumentsPath(void)
{
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
}

NSArray *M3ULocalFiles(void)
{
    NSMutableArray *out = [NSMutableArray array];
    NSArray *all = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:M3UDocumentsPath() error:NULL];
    for (NSString *f in all) {
        NSString *ext = [[f pathExtension] lowercaseString];
        if ([ext isEqualToString:@"m3u"] || [ext isEqualToString:@"m3u8"]) [out addObject:f];
    }
    return [out sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}
