//
//  UIView+AddConstraints.m
//  Bagel
//
//  Created by Chris Barker on 25/07/2020.
//  Updated for Modern Auto Layout
//

#import "UIView+AddConstraints.h"

@implementation UIView (AddConstraints)

-(void)addConstraintsTo:(UIView *)view withLeading:(CGFloat)leading withTrailing:(CGFloat)trailing withTop:(CGFloat)top withBottom:(CGFloat)bottom {
    
    // Ensure the view is prepared for Auto Layout
    view.translatesAutoresizingMaskIntoConstraints = NO;
    
    NSMutableArray *constraints = [NSMutableArray array];
    
    if (leading != 0.0) {
        [constraints addObject:[view.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:leading]];
    }
    
    if (trailing != 0.0) {
        [constraints addObject:[view.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:trailing]];
    }
    
    if (top != 0.0) {
        [constraints addObject:[view.topAnchor constraintEqualToAnchor:self.topAnchor constant:top]];
    }
    
    if (bottom != 0.0) {
        [constraints addObject:[view.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:bottom]];
    }
    
    [NSLayoutConstraint activateConstraints:constraints];
}

@end