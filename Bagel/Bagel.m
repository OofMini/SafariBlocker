//
//  Bagel.m
//  Bagel
//
//  Updated for iOS 15/16 + Code Cleanup
//

#import "Bagel.h"
#import "UIView+AddConstraints.h"

@interface Message: NSObject
@property NSString *message;
@property UIView *toView;
@end

@implementation Message
-(id)initWithMessage:(NSString *)message forView:(UIView *)view {
    self = [super init];
    if (self) {
        _message = message;
        _toView = view;
    }
    return self;
}
@end

@implementation Bagel

NSMutableArray *messages;
bool baking;

+ (Bagel *)shared {
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
        messages = [[NSMutableArray alloc] init];
    }
    return self;
}

-(void)pop:(UIView * _Nullable)view withMessage:(NSString * _Nonnull)message {
    Message *nextMessage = [[Message alloc] initWithMessage:message forView:view];
    [messages addObject:nextMessage];
    [self sendMessage];
}

-(void)sendMessage {
    Message *nextMessage = messages.firstObject;
    if (!nextMessage || [nextMessage.message isEqualToString:@""] || baking || messages.count == 0) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    [self makeBagel:nextMessage.toView withMessage:nextMessage.message withCompletion:^(bool finished) {
        if (messages.count > 0) {
            [messages removeObjectAtIndex:0];
        }
        [weakSelf sendMessage];
    }];
}

-(void)makeBagel:(UIView * _Nullable)view withMessage:(NSString * _Nonnull)message withCompletion:(void(^)(bool finished))completion {
    baking = true;
    
    UIView *viewToAdd = view ?: [self getKeyView];
    
    // UI Setup
    UIView *bagelView = [[UIView alloc] init];
    [bagelView setBackgroundColor:[_backgroundColor colorWithAlphaComponent:0.98]];
    [bagelView setAlpha:0.0];
    [bagelView.layer setCornerRadius:15];
    [bagelView setClipsToBounds:YES];

    UILabel *textLabel = [[UILabel alloc] init];
    [textLabel setTextColor:_textColor];
    [textLabel setTextAlignment:_textAlignment];
    [textLabel setText:message];
    [textLabel setNumberOfLines:_lineCount];
    [textLabel setFont:_font];
    [textLabel setClipsToBounds:YES];

    [bagelView addSubview:textLabel];
    [viewToAdd addSubview:bagelView];

    // Auto Layout
    [bagelView addConstraintsTo:textLabel withLeading:16 withTrailing:-16 withTop:16 withBottom:-16];
    [viewToAdd addConstraintsTo:bagelView withLeading:20 withTrailing:-20 withTop:0.0 withBottom:_bottomConstraint];

    // Animations
    [UIView animateWithDuration:_speed delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        [bagelView setAlpha:1.0];
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:self.speed delay:self.wait options:UIViewAnimationOptionCurveEaseInOut animations:^{
            [bagelView setAlpha:0.0];
        } completion:^(BOOL finished) {
            [bagelView removeFromSuperview];
            baking = false;
            if (completion) completion(true);
        }];
    }];
}

-(UIView *)getKeyView {
    // Modern iOS Scene support
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow) return window;
            }
        }
    }
    return [[UIApplication sharedApplication].windows lastObject];
}

@end
