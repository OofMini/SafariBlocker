//
//  Bagel.m
//  Bagel
//
//  Created by Chris Barker on 25/07/2020.
//  Updated for iOS 15/16
//

#import "Bagel.h"
#import "UIView+AddConstraints.h"

// MARK: Message Object

@interface Message: NSObject
@property NSString *message;
@property UIView *toView;
@end

@implementation Message
-(id)initWithMessage:(NSString *)message forView:(UIView *)view {

    self = [super init];
    if( !self ) return nil;

    _message = message;
    _toView = view;

    return self;

}
@end

// MARK: Bagel (tasty 🥯)

@implementation Bagel

NSMutableArray *messages;
bool baking;

+ (Bagel *) shared {
    static dispatch_once_t once;
    static Bagel *shared;
    dispatch_once(&once, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (instancetype)init {

    self = [super init];
    if (self) {
        _backgroundColor = [UIColor purpleColor];
        _textColor = [UIColor whiteColor];
        _lineCount = 0;
        _font = [UIFont systemFontOfSize:17.0];
        _textAlignment = NSTextAlignmentCenter;
        _bottomConstraint = -30.0;
        _speed = 0.4;
        _wait = 1.8;
        messages = [[NSMutableArray alloc]init];
    }
    return self;

}

-(void)pop:(UIView * _Nullable) view withMessage:(NSString * _Nonnull) message {
    Message *nextMessage = [[Message alloc]initWithMessage:message forView:view];
    [messages addObject:nextMessage];
    [self sendMessage];
}

-(void)sendMessage {

    Message *nextMessage = messages.firstObject;

    if (nextMessage == nil || [nextMessage.message isEqual: @""] || baking || messages.count == 0) {
        return;
    }

    [self makeBagel:nextMessage.toView withMessage:nextMessage.message withCompletion:^(bool complete) {
        [messages removeObjectAtIndex:0];
        [self sendMessage];
    }];

}

-(void)makeBagel:(UIView * _Nullable) view withMessage:(NSString * _Nonnull) message withCompletion:(void(^)(bool finished))completion {

    baking = true;

    UIView *viewToAdd = view;
    if (viewToAdd == nil) {
        viewToAdd = [self getKeyView];
    }

    // Setup UIView 🍞
    UIView *bagelView = [[UIView alloc]init];
    [bagelView setBackgroundColor:[_backgroundColor colorWithAlphaComponent:0.98]];
    [bagelView setAlpha:0.0];
    [bagelView.layer setCornerRadius:15];
    [bagelView setClipsToBounds:YES];

    // Setup UILabel 🏷
    UILabel *textLabel = [[UILabel alloc]init];
    [textLabel setTextColor:_textColor];
    [textLabel setTextAlignment:_textAlignment];
    [textLabel setText:message];
    [textLabel setNumberOfLines:_lineCount];
    [textLabel setFont:_font];
    [textLabel setClipsToBounds:YES];

    [bagelView addSubview:textLabel];
    [viewToAdd addSubview:bagelView];

    // Set Constaints 🏗
    [textLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
    [bagelView setTranslatesAutoresizingMaskIntoConstraints:NO];

    [bagelView addConstraintsTo:textLabel withLeading:16 withTrailing:-16 withTop:16 withBottom:-16];
    [viewToAdd addConstraintsTo:bagelView withLeading:20 withTrailing:-20 withTop:0.0 withBottom:_bottomConstraint];

    [UIView animateWithDuration:_speed delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        [bagelView setAlpha:1.0];
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:self.speed delay:self.wait options:UIViewAnimationOptionCurveEaseInOut animations:^{
            [bagelView setAlpha:0.0];
        } completion:^(BOOL finished) {
            [bagelView removeFromSuperview];
            baking = false;
            completion(true);
        }];
    }];

}

-(UIView *)getKeyView {
    // iOS 13+ / 15+ Scene Support
    // We iterate over connected scenes to find the active foreground scene
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            // Find the key window in this scene
            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow) {
                    return window;
                }
            }
        }
    }
    
    // Fallback for older iOS or if no scene matches
    UIWindow *topWindow = [[[UIApplication sharedApplication].windows sortedArrayUsingComparator:^NSComparisonResult(UIWindow *firstWindow, UIWindow *secondWindow) {
        return firstWindow.windowLevel - secondWindow.windowLevel;
    }] lastObject];
    
    // If we have subviews, return the last one (often the top view controller's view)
    if (topWindow.subviews.count > 0) {
        return [[topWindow subviews] lastObject];
    }
    
    return topWindow;
}

@end
