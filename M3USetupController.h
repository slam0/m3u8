#import <UIKit/UIKit.h>

/* Ekran konfiguracji przy pierwszym uruchomieniu: powitanie, trzy sposoby dodania playlisty,
 * formularz (nazwa, adres, schowek) i wybór wyglądu. „Pomiń” jest na każdym ekranie. */

@class M3USetupController;

@protocol M3USetupDelegate <NSObject>
/* playlist: @{name, url} albo nil, gdy użytkownik pominął dodawanie playlisty */
- (void)setupFinished:(M3USetupController *)c playlist:(NSDictionary *)playlist;
@end

@interface M3USetupController : UIViewController
@property (nonatomic, weak) id<M3USetupDelegate> delegate;
+ (BOOL)needsSetup;     /* YES tylko przy pierwszym starcie i bez zapisanych playlist */
@end
