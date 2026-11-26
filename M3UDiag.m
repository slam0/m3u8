#import "M3UDiag.h"

static NSString *const kRunning = @"diag_running";
static NSMutableArray *steps;

static NSString *diagPath(void)
{
    NSString *dir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
    return [dir stringByAppendingPathComponent:@"isat-ostatnie-kroki.txt"];
}

static void flush(void)
{
    [[steps componentsJoinedByString:@"\n"] writeToFile:diagPath() atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

void M3UBreadcrumb(NSString *step)
{
    if (!steps) steps = [[NSMutableArray alloc] init];
    [steps addObject:step ?: @"?"];
    while ([steps count] > 14) [steps removeObjectAtIndex:0];
    flush();
}

static void exceptionHandler(NSException *e)
{
    NSArray *st = [e callStackSymbols];
    NSUInteger n = [st count] < 8 ? [st count] : 8;
    NSString *trace = [[st subarrayWithRange:NSMakeRange(0, n)] componentsJoinedByString:@"\n"];
    M3UBreadcrumb([NSString stringWithFormat:@"WYJĄTEK %@: %@\n%@", [e name], [e reason], trace]);
    [[NSUserDefaults standardUserDefaults] synchronize];
}

void M3UDiagInstall(void)
{
    NSSetUncaughtExceptionHandler(&exceptionHandler);
}

NSString *M3UDiagCrashReportIfAny(void)
{
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kRunning]) return nil;
    NSString *s = [NSString stringWithContentsOfFile:diagPath() encoding:NSUTF8StringEncoding error:NULL];
    return [s length] ? s : @"(brak zapisanych kroków)";
}

void M3UDiagMarkRunning(BOOL running)
{
    [[NSUserDefaults standardUserDefaults] setBool:running forKey:kRunning];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
