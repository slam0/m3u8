#import <UIKit/UIKit.h>

/* Ciemnogranatowy wygląd w stylu iOS 6: ciemny len, błyszczące granatowe paski i guziki. */

void M3UThemeApply(void);                          /* pasek i guziki (UIAppearance) - wołać przed tworzeniem okien */
UIColor *M3UTextColor(void);                       /* główny tekst (jasny) */
UIColor *M3USubtleColor(void);                     /* tekst pomocniczy */
UIColor *M3UAccentColor(void);                     /* niebieski akcent */
UIImage *M3UBackgroundPattern(void);               /* tło: ciemny len */
void M3UStyleTable(UITableView *tv);               /* lniane tło, bez domyślnych linii */
void M3UStyleCell(UITableViewCell *cell);          /* ciemne tło wiersza, wytłoczony tekst, niebieskie zaznaczenie */
void M3UStyleSearchBar(UISearchBar *bar);          /* granatowy pasek wyszukiwarki */
UIView *M3UHeaderView(NSString *title);            /* granatowy nagłówek sekcji (wysokość 22) */
UIView *M3UFooterView(NSString *text, CGFloat w);  /* tekst pod listą, na lnie */
CGFloat M3UFooterHeight(NSString *text, CGFloat w);
UIImage *M3UGlyphTile(int kind, CGFloat side);     /* płytka z symbolem: 0 gwiazdka, 1 lista, 2 plik */
UIImage *M3UBarIcon(NSString *name);               /* ikona na przycisk paska: @"ico_list" / @"ico_grid" */
