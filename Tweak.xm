#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "Bagel/Bagel.h"

// MARK: - Safari Internal Interfaces

@interface LoadingController : NSObject
- (NSURL*)URL;
@end

@interface TabDocument : NSObject
@end

@interface TabController : NSObject
-(void)updateSafariBlockerPrefsForActionType:(int)action blockedData:(NSString*)content;
-(void)showToastWithMessage:(NSString*)arg1;
@end

@interface SFBarRegistration : NSObject
- (BOOL)containsBarItem:(NSInteger)barItem;
@end

@interface _SFToolbar : NSObject
@property (nonatomic,weak) SFBarRegistration* barRegistration;
@end

@interface BrowserToolbar : _SFToolbar
@end

@interface NavigationBar : NSObject
- (id)_toolbarForBarItem:(NSInteger)barItem;
@end

@interface BrowserRootViewController : UIViewController
@property (readonly, nonatomic) BrowserToolbar* bottomToolbar;
@property (readonly, nonatomic) NavigationBar* navigationBar;
@end

// MARK: - Helper Functions

// Helper to find the active toolbar (Critical for preventing iPad crashes)
static _SFToolbar* activeToolbarOrToolbarForBarItemForBrowserRootViewController(BrowserRootViewController* rootVC, NSInteger barItem) {
    if(!rootVC) return nil;

    if([rootVC.bottomToolbar.barRegistration containsBarItem:barItem]) {
        return rootVC.bottomToolbar;
    } else {
        if([rootVC.navigationBar respondsToSelector:@selector(_toolbarForBarItem:)]) {
            return [rootVC.navigationBar _toolbarForBarItem:barItem];
        } else {
            // Fallback for older/different layouts
            _SFToolbar* leadingToolbar = [rootVC.navigationBar valueForKey:@"_leadingToolbar"];
            _SFToolbar* trailingToolbar = [rootVC.navigationBar valueForKey:@"_trailingToolbar"];

            if([leadingToolbar.barRegistration containsBarItem:barItem]) return (BrowserToolbar*)leadingToolbar;
            if([trailingToolbar.barRegistration containsBarItem:barItem]) return (BrowserToolbar*)trailingToolbar;

            return nil;
        }
    }
}

// Clean URL parsing using NSURL (More robust than string replacement)
static NSString* removeJunk(NSString* urlString) {
    if (!urlString) return @"";
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return [urlString lowercaseString];
    
    NSString *host = [url host];
    if ([host hasPrefix:@"www."]) host = [host substringFromIndex:4];
    return host ? host : urlString;
}

static NSString* removeJunkFromSpecifier(NSString* urlString) {
     if (!urlString) return @"";
     return [[urlString stringByReplacingOccurrencesOfString:@"www." withString:@""] lowercaseString];
}

// Preference Path (Sandboxed for iOS 15+)
#define prefFilePath [NSString stringWithFormat:@"%@/Library/Preferences/com.p2kdev.safariblocker.plist", NSHomeDirectory()]

static BOOL skipNextTabOpen = NO;
static NSMutableArray * blockedURLs;
static NSMutableArray * blockedDomains;
static NSMutableArray * allowedDomains;
static bool showBagelMenu = YES;

// MARK: - Hooks

%hook TabController

// Hook used in the fork (stable for iOS 15 without libundirect)
- (void)insertTab:(id)tabDocument afterTab:(id)afterTab inBackground:(BOOL)inBackground animated:(BOOL)animated {
    
    if(skipNextTabOpen) {
        %orig;
        skipNextTabOpen = NO;
        return;
    }

    TabDocument *originalTab = nil;
    @try {
        originalTab = MSHookIvar<TabDocument*>(tabDocument,"_parentTabDocumentForBackClosesSpawnedTab");
    }
    @catch(NSException* ex) {
        NSLog(@"[SafariBlocker] Error fetching parentTab: %@", ex.reason);
    }

    LoadingController* loadingController = [originalTab valueForKey:@"_loadingController"];
    NSURL *originalURL = [loadingController URL];

    if (originalTab && originalURL) {
        NSString *domainForURL = removeJunk([originalURL absoluteString]);
        NSString *resourceSpecifier = [originalURL resourceSpecifier];
        NSString *URLWithoutJunk = removeJunkFromSpecifier(resourceSpecifier);

        // 1. Check Whitelist
        if ([allowedDomains containsObject:domainForURL]) {
            %orig;
            return;
        }

        // Helper block to show toast
        void (^showToast)(NSString*) = ^(NSString *msg) {
            UIViewController* rootVC = [[self valueForKey:@"_browserController"] valueForKey:@"_rootViewController"];
            [[Bagel shared] pop:rootVC.view withMessage:msg];
        };

        // 2. Check Blocked Domains
        if ([blockedDomains containsObject:domainForURL]) {
            if (showBagelMenu) showToast([NSString stringWithFormat:@"Blocked pop-up from Domain - \n %@", domainForURL]);
            return;
        }

        // 3. Check Blocked URLs
        for (NSString *tempURL in blockedURLs) {
            if ([tempURL isEqualToString:URLWithoutJunk]) {
                if (showBagelMenu) showToast([NSString stringWithFormat:@"Blocked pop-up from URL - \n %@", URLWithoutJunk]);
                return;
            }
        }

        // 4. Ask User
        NSString *msg = [NSString stringWithFormat:@"Action required:\nDomain: %@\nURL: %@", domainForURL, URLWithoutJunk];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"SafariBlocker"
                                                                       message:msg
                                                                preferredStyle:UIAlertControllerStyleActionSheet];

        UIAlertAction* allowOnce = [UIAlertAction actionWithTitle:@"Allow Once" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            %orig;
        }];

        UIAlertAction* whitelistDomain = [UIAlertAction actionWithTitle:@"Whitelist Domain" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            [self updateSafariBlockerPrefsForActionType:1 blockedData:domainForURL];
            %orig;
        }];

        UIAlertAction* blockDomain = [UIAlertAction actionWithTitle:@"Block Domain" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
            [self updateSafariBlockerPrefsForActionType:2 blockedData:domainForURL];
        }];

        UIAlertAction* blockURL = [UIAlertAction actionWithTitle:@"Block URL" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
            [self updateSafariBlockerPrefsForActionType:3 blockedData:URLWithoutJunk];
        }];

        UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];

        [alert addAction:allowOnce];
        [alert addAction:whitelistDomain];
        [alert addAction:blockDomain];
        [alert addAction:blockURL];
        [alert addAction:cancelAction];

        // Present logic (iPad Popover Fix)
        BrowserRootViewController* rootVC = [[self valueForKey:@"_browserController"] valueForKey:@"_rootViewController"];
        _SFToolbar* activeToolbar = activeToolbarOrToolbarForBarItemForBrowserRootViewController(rootVC, 5); // 5 = TabExposeItem
        
        if(activeToolbar) {
            UIView* sourceView = [[activeToolbar.barRegistration valueForKey:@"_tabExposeItem"] valueForKey:@"_view"];
            if(sourceView) {
                alert.popoverPresentationController.sourceView = sourceView;
                alert.popoverPresentationController.sourceRect = sourceView.bounds;
            }
        }

        [rootVC presentViewController:alert animated:YES completion:nil];

    } else {
        %orig;
    }
}

%new
-(void)showToastWithMessage:(NSString*)message {
    UIViewController* rootVC = [[self valueForKey:@"_browserController"] valueForKey:@"_rootViewController"];
    [[Bagel shared] pop:rootVC.view withMessage:message];
}

%new
-(void)updateSafariBlockerPrefsForActionType:(int)action blockedData:(NSString*)content {
    if (!content) return;
    
    NSMutableDictionary *defaults = [NSMutableDictionary dictionary];
    [defaults addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:prefFilePath]];

    switch(action) {
        case 1: // Whitelist
            [allowedDomains addObject:content];
            [defaults setObject:[allowedDomains componentsJoinedByString:@";"] forKey:@"allowedDomains"];
            break;
        case 2: // Block Domain
            [blockedDomains addObject:content];
            [defaults setObject:[blockedDomains componentsJoinedByString:@";"] forKey:@"blockedDomains"];
            break;
        case 3: // Block URL
            [blockedURLs addObject:content];
            [defaults setObject:[blockedURLs componentsJoinedByString:@";"] forKey:@"blockedURLs"];
            break;
    }
    [defaults writeToFile:prefFilePath atomically:YES];
}
%end

// Hook to handle "Open in New Tab" from context menus gracefully
typedef void (^UIActionHandler)(__kindof UIAction *action);
@interface UIAction (Private)
@property (nonatomic, copy) UIActionHandler handler;
@end

%hook _SFLinkPreviewHelper
- (UIAction*)openInNewTabActionForURL:(NSURL*)arg1 preActionHandler:(id)arg2 {
    UIAction* action = %orig;
    UIActionHandler prevHandler = action.handler;
    action.handler = ^(__kindof UIAction* action) {
        skipNextTabOpen = YES;
        prevHandler(action);
        skipNextTabOpen = NO; 
    };
    return action;
}
%end

// MARK: - Preferences Loader

static void updatePrefs() {
    NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:prefFilePath];
    
    NSString *whitelistStr = [prefs objectForKey:@"allowedDomains"] ? [[prefs objectForKey:@"allowedDomains"] stringValue] : @"";
    NSString *blacklistDomStr = [prefs objectForKey:@"blockedDomains"] ? [[prefs objectForKey:@"blockedDomains"] stringValue] : @"";
    NSString *blacklistUrlStr = [prefs objectForKey:@"blockedURLs"] ? [[prefs objectForKey:@"blockedURLs"] stringValue] : @"";
    
    showBagelMenu = [prefs objectForKey:@"showBagelMenu"] ? [[prefs objectForKey:@"showBagelMenu"] boolValue] : YES;

    blockedURLs = [[blacklistUrlStr componentsSeparatedByString:@";"] mutableCopy];
    blockedDomains = [[blacklistDomStr componentsSeparatedByString:@";"] mutableCopy];
    allowedDomains = [[whitelistStr componentsSeparatedByString:@";"] mutableCopy];
    
    [blockedURLs removeObject:@""];
    [blockedDomains removeObject:@""];
    [allowedDomains removeObject:@""];
}

%ctor {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)updatePrefs, CFSTR("com.p2kdev.safariblocker.settingschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
    updatePrefs();
}
