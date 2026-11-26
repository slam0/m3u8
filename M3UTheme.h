#import <UIKit/UIKit.h>

/* Wygląd w stylu iOS 6: skórzany pasek, lniane tło, papierowe wiersze, błyszczące guziki. */

void M3UThemeApply(void);                          /* pasek i guziki (UIAppearance) - wołać przed tworzeniem okien */
UIColor *M3UBrown(void);                           /* kolor tekstu na papierze */
UIColor *M3USubtleBrown(void);                     /* kolor tekstu pomocniczego */
void M3UStyleTable(UITableView *tv);               /* lniane tło i linie między wierszami */
void M3UStyleCell(UITableViewCell *cell);          /* wytłoczony tekst, złote zaznaczenie */
void M3UPaperCell(UITableViewCell *cell);          /* papierowe tło - wołać w willDisplayCell */
void M3UStyleSearchBar(UISearchBar *bar);          /* skórzany pasek wyszukiwarki */
UIView *M3UHeaderView(NSString *title);            /* skórzany nagłówek sekcji (wysokość 22) */
UIView *M3UFooterView(NSString *text, CGFloat w);  /* tekst pod listą, na lnie */
CGFloat M3UFooterHeight(NSString *text, CGFloat w);
