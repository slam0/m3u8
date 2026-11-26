#import <UIKit/UIKit.h>

/* Granatowo-niebieski wygląd w stylu iOS 6: gładkie niebieskie tło z błyskiem, błyszczące paski i guziki. */

void M3UThemeApply(void);                          /* pasek i guziki (UIAppearance) - wołać przed tworzeniem okien */
UIColor *M3UTextColor(void);                       /* główny tekst (jasny) */
UIColor *M3USubtleColor(void);                     /* tekst pomocniczy */
UIColor *M3UAccentColor(void);                     /* niebieski akcent */
UIView *M3UBackdropView(CGRect frame);             /* tło ekranu: gładki niebieski gradient z błyskiem */
void M3UStyleTable(UITableView *tv);               /* tło ekranu, bez domyślnych linii */
void M3UStyleCell(UITableViewCell *cell);          /* ciemne tło wiersza, wytłoczony tekst, niebieskie zaznaczenie */
void M3UStyleSearchBar(UISearchBar *bar);          /* granatowy pasek wyszukiwarki */
UIView *M3UHeaderView(NSString *title);            /* granatowy nagłówek sekcji (wysokość 22) */
UIView *M3UFooterView(NSString *text, CGFloat w);  /* tekst pod listą, na lnie */
CGFloat M3UFooterHeight(NSString *text, CGFloat w);
UIImage *M3UGlyphTile(int kind, CGFloat side);     /* płytka z symbolem: 0 gwiazdka, 1 lista, 2 plik */
UIImage *M3UBarIcon(NSString *name);
UIImage *M3UFavoriteMark(CGFloat side);            /* znacznik ulubionych: niebieska zakładka, rysowana kodem */               /* ikona na przycisk paska: @"ico_list" / @"ico_grid" */

/* Obracanie ekranu (iOS 5 i iOS 6+): wszystkie ekrany poza kreatorem startowym */
#define M3U_ROTATE_ANY \
    - (BOOL)shouldAutorotate { return YES; } \
    - (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskAllButUpsideDown; } \
    - (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad || o != UIInterfaceOrientationPortraitUpsideDown; }
#define M3U_ROTATE_PORTRAIT \
    - (BOOL)shouldAutorotate { return NO; } \
    - (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskPortrait; } \
    - (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o { return o == UIInterfaceOrientationPortrait; }
