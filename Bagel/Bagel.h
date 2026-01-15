//
//  Bagel.h
//  Bagel
//
//  Created by Chris Barker on 25/07/2020.
//  Updated for Modern iOS
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface Bagel : NSObject

+ (Bagel *)shared;

@property (nonatomic, assign) CGFloat speed;
@property (nonatomic, assign) CGFloat wait;
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic, strong) UIColor *backgroundColor;
@property (nonatomic, assign) NSInteger lineCount;
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, assign) NSTextAlignment textAlignment;
@property (nonatomic, assign) CGFloat bottomConstraint;

-(void)pop:(UIView * _Nullable)view withMessage:(NSString * _Nonnull)message;

@end

NS_ASSUME_NONNULL_END
