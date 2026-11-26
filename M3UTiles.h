#import <UIKit/UIKit.h>

/* Kafelek kanału w widoku siatki: karta, płytka z logo/inicjałami, nazwa i gwiazdka ulubionych. */
@interface M3UTileCell : UICollectionViewCell
- (void)setTitle:(NSString *)title plate:(UIImage *)plate favorite:(BOOL)favorite;
- (void)setPlate:(UIImage *)plate;
- (void)setProgram:(NSString *)text progress:(float)progress;   /* nil = bez programu */
@end

/* Nagłówek grupy w siatce. */
@interface M3UTileHeader : UICollectionReusableView
- (void)setTitle:(NSString *)title;
@end
