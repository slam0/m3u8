#import "M3UTiles.h"
#import "M3UTheme.h"

@implementation M3UTileCell {
    UIImageView *_card;
    UIImageView *_plate;
    UILabel *_title;
    UILabel *_star;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.backgroundColor = [UIColor clearColor];
    _card = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"tile_card"] resizableImageWithCapInsets:UIEdgeInsetsMake(14, 14, 14, 14)]];
    _card.frame = self.contentView.bounds;
    _card.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.contentView addSubview:_card];

    /* górna część: logo w swoich proporcjach, wpasowane w ramkę */
    _plate = [[UIImageView alloc] initWithFrame:CGRectMake(12, 12, frame.size.width - 24, 82)];
    _plate.contentMode = UIViewContentModeScaleAspectFit;
    _plate.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.contentView addSubview:_plate];

    _title = [[UILabel alloc] initWithFrame:CGRectMake(8, 100, frame.size.width - 16, 40)];
    _title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _title.backgroundColor = [UIColor clearColor];
    _title.textColor = M3UTextColor();
    _title.shadowColor = [UIColor colorWithWhite:0 alpha:0.85f];
    _title.shadowOffset = CGSizeMake(0, -1);
    _title.font = [UIFont boldSystemFontOfSize:14.0f];
    _title.textAlignment = NSTextAlignmentCenter;
    _title.numberOfLines = 2;
    _title.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.contentView addSubview:_title];

    _star = [[UILabel alloc] initWithFrame:CGRectMake(frame.size.width - 30, 4, 26, 24)];
    _star.backgroundColor = [UIColor clearColor];
    _star.text = @"★";
    _star.textAlignment = NSTextAlignmentCenter;
    _star.font = [UIFont systemFontOfSize:20.0f];
    _star.textColor = [UIColor colorWithRed:1.0f green:0.82f blue:0.30f alpha:1.0f];
    _star.shadowColor = [UIColor colorWithWhite:0 alpha:0.9f];
    _star.shadowOffset = CGSizeMake(0, 1);
    _star.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    _star.hidden = YES;
    [self.contentView addSubview:_star];
    return self;
}

- (void)setTitle:(NSString *)title plate:(UIImage *)plate favorite:(BOOL)favorite
{
    _title.text = title;
    _plate.image = plate;
    _star.hidden = !favorite;
    self.contentView.alpha = 1.0f;
}

- (void)setPlate:(UIImage *)plate { _plate.image = plate; }

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    self.contentView.alpha = highlighted ? 0.65f : 1.0f;
}

@end

@implementation M3UTileHeader {
    UILabel *_label;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    UIImageView *bg = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"header_bar"] resizableImageWithCapInsets:UIEdgeInsetsMake(8, 4, 8, 4)]];
    bg.frame = self.bounds;
    bg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:bg];
    _label = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, frame.size.width - 24, 21)];
    _label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _label.backgroundColor = [UIColor clearColor];
    _label.textColor = M3UTextColor();
    _label.shadowColor = [UIColor colorWithWhite:0 alpha:0.85f];
    _label.shadowOffset = CGSizeMake(0, -1);
    _label.font = [UIFont boldSystemFontOfSize:13.0f];
    [self addSubview:_label];
    return self;
}

- (void)setTitle:(NSString *)title { _label.text = title; }

@end
