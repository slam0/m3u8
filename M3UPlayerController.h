#import <UIKit/UIKit.h>
#import "M3UList.h"

/* Własny odtwarzacz kanałów na iPadzie. W poziomie: przesunięcie palcem od prawej krawędzi wysuwa listę kanałów
 * (przełączanie bez wychodzenia z eteru), od lewej - program (EPG) bieżącego kanału, jeśli jest. */
@interface M3UPlayerController : UIViewController
- (id)initWithEntries:(NSArray *)entries current:(M3UEntry *)current;
@end
