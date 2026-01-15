#import <Preferences/Preferences.h>
#import <Preferences/PSListController.h>
#include <objc/runtime.h>

// Define interface for PSTextFieldSpecifier to expose setPlaceholder
@interface PSTextFieldSpecifier : PSSpecifier
- (void)setPlaceholder:(NSString *)placeholder;
@end

@interface LSApplicationProxy : NSObject
+(id)applicationProxyForIdentifier:(NSString *)bundleId;
-(NSURL *)containerURL;
@end

@interface TBRootListController : PSListController
@end

@interface TBGeneralListController : PSListController
@property (nonatomic,retain) NSMutableArray *dataList;
@property (nonatomic,assign) NSString *dataListKey;
-(id)initForType:(int)type;
@end

NSString *prefFilePath;

@implementation TBRootListController

- (id)init {
    self = [super init];
    if (self) {
        NSURL *containerURL = [[objc_getClass("LSApplicationProxy") applicationProxyForIdentifier:@"com.apple.mobilesafari"] containerURL];
        prefFilePath = [[containerURL path] stringByAppendingPathComponent:@"Library/Preferences/com.p2kdev.safariblocker.plist"];
    }
    return self;
}

- (id)specifiers {
    if(_specifiers == nil) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)launchAllowedDomainOptions { [self pushController:[[TBGeneralListController alloc] initForType:1] animate:YES]; }
- (void)launchBlockedDomainOptions { [self pushController:[[TBGeneralListController alloc] initForType:2] animate:YES]; }
- (void)launchBlockedURLOptions { [self pushController:[[TBGeneralListController alloc] initForType:3] animate:YES]; }
- (void)visitTwitter { [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://twitter.com/p2kdev"] options:@{} completionHandler:nil]; }

@end

@implementation TBGeneralListController

- (id)initForType:(int)type {
    self = [super init];
    if (self) {
        self.dataList = [[NSMutableArray alloc] init];
        if (type == 1) self.dataListKey = @"allowedDomains";
        else if (type == 2) self.dataListKey = @"blockedDomains";
        else if (type == 3) self.dataListKey = @"blockedURLs";
    }
    return self;
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [[NSMutableArray alloc] init];
        NSMutableDictionary *tweakSettings = [[NSMutableDictionary alloc] initWithContentsOfFile:prefFilePath];
        id plistValue = [tweakSettings objectForKey:self.dataListKey];

        if (plistValue) {
            int index = 1;
            self.dataList = [[plistValue componentsSeparatedByString:@";"] mutableCopy];
            for (NSString *currData in self.dataList) {
                if ([currData length] == 0) continue;
                NSString *newDataLabel = [NSString stringWithFormat:@"#%d", index];
                
                // Use the defined interface to allow setPlaceholder
                PSTextFieldSpecifier *newData = (PSTextFieldSpecifier *)[PSSpecifier preferenceSpecifierNamed:newDataLabel target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSEditTextCell edit:nil];
                
                [newData setProperty:newDataLabel forKey:@"key"];
                [newData setProperty:@"com.p2kdev.safariblocker.settingschanged" forKey:@"PostNotification"];
                [newData setProperty:@YES forKey:@"enabled"];
                
                // Now works because we defined the method in the interface above
                [newData setPlaceholder:@"Enter url/domain"];
                
                [_specifiers addObject:newData];
                index++;
            }
        }
    }
    return _specifiers;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    
    // Safely check for PSEditableTableCell
    if ([cell isKindOfClass:objc_getClass("PSEditableTableCell")]) {
        // Cast to 'id' to dynamically access 'textField' without header dependency issues
        id editableCell = cell;
        
        if ([editableCell respondsToSelector:@selector(textField)]) {
            UITextField *textField = [editableCell textField];
            if (textField) {
                UIToolbar *keyboardDoneButtonView = [[UIToolbar alloc] init];
                [keyboardDoneButtonView sizeToFit];
                
                UIBarButtonItem *flexBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
                UIBarButtonItem *doneBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissKeyboard:)];
                
                keyboardDoneButtonView.items = @[flexBarButton, doneBarButton];
                textField.inputAccessoryView = keyboardDoneButtonView;
            }
        }
    }
    return cell;
}

- (void)dismissKeyboard:(id)sender {
    [self.view endEditing:YES];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier {
    NSMutableDictionary *defaults = [NSMutableDictionary dictionary];
    [defaults addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:prefFilePath]];
    NSString *key = [specifier propertyForKey:@"key"];
    if ([key hasPrefix:@"#"]) {
        NSInteger idx = [[key stringByReplacingOccurrencesOfString:@"#" withString:@""] integerValue] - 1;
        if (idx < self.dataList.count) {
            self.dataList[idx] = value;
            [defaults setObject:[self.dataList componentsJoinedByString:@";"] forKey:self.dataListKey];
        }
    }
    [defaults writeToFile:prefFilePath atomically:YES];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.p2kdev.safariblocker.settingschanged"), NULL, NULL, YES);
}

- (id)readPreferenceValue:(PSSpecifier*)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if ([key hasPrefix:@"#"]) {
        NSInteger idx = [[key stringByReplacingOccurrencesOfString:@"#" withString:@""] integerValue] - 1;
        if (idx < self.dataList.count) return self.dataList[idx];
    }
    return nil;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath { return YES; }

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self.dataList removeObjectAtIndex:indexPath.row];
        NSMutableDictionary *defaults = [NSMutableDictionary dictionary];
        [defaults addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:prefFilePath]];
        [defaults setObject:[self.dataList componentsJoinedByString:@";"] forKey:self.dataListKey];
        [defaults writeToFile:prefFilePath atomically:YES];
        [self reloadSpecifiers];
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.p2kdev.safariblocker.settingschanged"), NULL, NULL, YES);
    }
}
@end
