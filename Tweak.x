#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <UIKit/UIKit.h>

#import "YTVideoOverlay/Header.h"
#import "YTVideoOverlay/Init.x"
#import <YouTubeHeader/YTColor.h>
#import <YouTubeHeader/QTMIcon.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayView.h>
#import <YouTubeHeader/YTMainAppControlsOverlayView.h>
#import <YouTubeHeader/YTPlayerViewController.h>
#import <YouTubeHeader/YTSettingsSectionItem.h>
#import <YouTubeHeader/YTSettingsViewController.h>

#define TweakKey @"YouTimeStamp"
#define HoldToCopyWithoutTimestampKey @"YouTimeStamp-HoldToCopyWithoutTimestamp"
static const NSInteger YTVideoOverlaySection = 1222;

@interface YTMainAppVideoPlayerOverlayViewController (YouTimeStamp)
@property (nonatomic, assign) YTPlayerViewController *parentViewController;
@end

@interface YTMainAppVideoPlayerOverlayView (YouTimeStamp)
@property (nonatomic, weak, readwrite) YTMainAppVideoPlayerOverlayViewController *delegate;
@end

@interface YTPlayerViewController (YouTimeStamp)
@property (nonatomic, assign) CGFloat currentVideoMediaTime;
@property (nonatomic, assign) NSString *currentVideoID;
- (void)didPressYouTimeStamp;
- (void)didLongPressYouTimeStamp;
@end

@interface YTMainAppControlsOverlayView (YouTimeStamp)
@property (nonatomic, assign) YTPlayerViewController *playerViewController;
- (void)didPressYouTimeStamp:(id)arg;
- (void)didLongPressYouTimeStamp:(UILongPressGestureRecognizer *)gesture;
@end

@interface YTInlinePlayerBarController : NSObject
@end

@interface YTInlinePlayerBarContainerView (YouTimeStamp)
@property (nonatomic, strong) YTInlinePlayerBarController *delegate;
- (void)didPressYouTimeStamp:(id)arg;
- (void)didLongPressYouTimeStamp:(UILongPressGestureRecognizer *)gesture;
@end

// YTSettingsSectionItem interface for accessing title
@interface YTSettingsSectionItem (YouTimeStamp)
@property (nonatomic, strong, readonly) NSString *title;
@end


// For displaying snackbars - @theRealfoxster
@interface YTHUDMessage : NSObject
+ (id)messageWithText:(id)text;
- (void)setAction:(id)action;
@end

@interface GOOHUDMessageAction : NSObject
- (void)setTitle:(NSString *)title;
- (void)setHandler:(void (^)(id))handler;
@end

@interface GOOHUDManagerInternal : NSObject
- (void)showMessageMainThread:(id)message;
+ (id)sharedInstance;
@end

NSBundle *YouTimeStampBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:TweakKey ofType:@"bundle"];
        if (tweakBundlePath)
            bundle = [NSBundle bundleWithPath:tweakBundlePath];
        else
            bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:ROOT_PATH_NS(@"/Library/Application Support/%@.bundle"), TweakKey]];
    });
    return bundle;
}

static UIImage *timestampImage(NSString *qualityLabel) {
    return [%c(QTMIcon) tintImage:[UIImage imageNamed:[NSString stringWithFormat:@"Timestamp@%@", qualityLabel] inBundle: YouTimeStampBundle() compatibleWithTraitCollection:nil] color:[%c(YTColor) white1]];
}

static void addLongPressGestureToButton(YTQTMButton *button, id target, SEL selector) {
    if (button && [[NSUserDefaults standardUserDefaults] boolForKey:HoldToCopyWithoutTimestampKey]) {
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:target action:selector];
        longPress.minimumPressDuration = 0.5;
        [button addGestureRecognizer:longPress];
    }
}

%group Main
%hook YTPlayerViewController
// New method to copy the URL with the timestamp to the clipboard - @arichornlover
%new
- (void)didPressYouTimeStamp {
    // Get the current time of the video
    CGFloat currentTime = self.currentVideoMediaTime;
    NSInteger timeInterval = (NSInteger)currentTime;

    // Create a link using the video ID and the timestamp
    if (self.currentVideoID) {
        NSString *videoId = [NSString stringWithFormat:@"https://youtu.be/%@", self.currentVideoID];
        NSString *timestampString = [NSString stringWithFormat:@"?t=%.0ld", (long)timeInterval];

        // Create link
        NSString *modifiedURL = [videoId stringByAppendingString:timestampString];
        // Copy the link to clipboard
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        [pasteboard setString:modifiedURL];
        // Load localized string
        NSBundle *bundle = YouTimeStampBundle();
        NSString *msg = NSLocalizedStringFromTableInBundle(
            @"URL_COPIED",
            nil,
            bundle ?: [NSBundle mainBundle],
            @"Message when URL is copied"
        );

        // Show snackbar
        [[%c(GOOHUDManagerInternal) sharedInstance]
            showMessageMainThread:[%c(YTHUDMessage) messageWithText:msg]];

    } else {
        NSLog(@"[YouTimeStamp] No video ID available");
    }
}

// New method to copy the URL without the timestamp to the clipboard
%new
- (void)didLongPressYouTimeStamp {
    // Create a link using only the video ID (no timestamp)
    if (self.currentVideoID) {
        NSString *videoURL = [NSString stringWithFormat:@"https://youtu.be/%@", self.currentVideoID];
        
        // Copy the link to clipboard
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        [pasteboard setString:videoURL];
        // Load localized string
        NSBundle *bundle = YouTimeStampBundle();
        NSString *msg = NSLocalizedStringFromTableInBundle(
            @"URL_COPIED_NO_TIMESTAMP",
            nil,
            bundle ?: [NSBundle mainBundle],
            @"Message when URL is copied without timestamp"
        );

        // Show snackbar
        [[%c(GOOHUDManagerInternal) sharedInstance]
            showMessageMainThread:[%c(YTHUDMessage) messageWithText:msg]];

    } else {
        NSLog(@"[YouTimeStamp] No video ID available");
    }
}
%end
%end

/**
  * Adds a timestamp copy button to the top area in the video player overlay
  */
%group Top
%hook YTMainAppControlsOverlayView

- (id)initWithDelegate:(id)delegate {
    self = %orig;
    if (self) {
        addLongPressGestureToButton(self.overlayButtons[TweakKey], self, @selector(didLongPressYouTimeStamp:));
    }
    return self;
}

- (id)initWithDelegate:(id)delegate autoplaySwitchEnabled:(BOOL)autoplaySwitchEnabled {
    self = %orig;
    if (self) {
        addLongPressGestureToButton(self.overlayButtons[TweakKey], self, @selector(didLongPressYouTimeStamp:));
    }
    return self;
}

- (UIImage *)buttonImage:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey] ? timestampImage(@"3") : %orig;
}

// Custom method to handle the timestamp button press
%new(v@:@)
- (void)didPressYouTimeStamp:(id)arg {
    // Call our custom method in the YTPlayerViewController class - this is 
    // directly accessible in the self.playerViewController property
    YTMainAppVideoPlayerOverlayView *mainOverlayView = (YTMainAppVideoPlayerOverlayView *)self.superview;
    YTMainAppVideoPlayerOverlayViewController *mainOverlayController = (YTMainAppVideoPlayerOverlayViewController *)mainOverlayView.delegate;
    YTPlayerViewController *playerViewController = mainOverlayController.parentViewController;
    if (playerViewController) {
        [playerViewController didPressYouTimeStamp];
    }
}

// Custom method to handle long press on the timestamp button
%new(v@:@)
- (void)didLongPressYouTimeStamp:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        YTMainAppVideoPlayerOverlayView *mainOverlayView = (YTMainAppVideoPlayerOverlayView *)self.superview;
        YTMainAppVideoPlayerOverlayViewController *mainOverlayController = (YTMainAppVideoPlayerOverlayViewController *)mainOverlayView.delegate;
        YTPlayerViewController *playerViewController = mainOverlayController.parentViewController;
        if (playerViewController) {
            [playerViewController didLongPressYouTimeStamp];
        }
    }
}

%end
%end

/**
  * Adds a timestamp copy button to the bottom area next to the fullscreen button
  */
%group Bottom
%hook YTInlinePlayerBarContainerView

- (id)init {
    self = %orig;
    if (self) {
        addLongPressGestureToButton(self.overlayButtons[TweakKey], self, @selector(didLongPressYouTimeStamp:));
    }
    return self;
}

- (UIImage *)buttonImage:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey] ? timestampImage(@"3") : %orig;
}

// Custom method to handle the timestamp button press
%new(v@:@)
- (void)didPressYouTimeStamp:(id)arg {
    // Navigate to the YTPlayerViewController class from here
    YTInlinePlayerBarController *delegate = self.delegate; // for @property
    YTMainAppVideoPlayerOverlayViewController *_delegate = [delegate valueForKey:@"_delegate"]; // for ivars
    YTPlayerViewController *parentViewController = _delegate.parentViewController;
    // Call our custom method in the YTPlayerViewController class
    if (parentViewController) {
        [parentViewController didPressYouTimeStamp];
    }
}

// Custom method to handle long press on the timestamp button
%new(v@:@)
- (void)didLongPressYouTimeStamp:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        YTInlinePlayerBarController *delegate = self.delegate;
        YTMainAppVideoPlayerOverlayViewController *_delegate = [delegate valueForKey:@"_delegate"];
        YTPlayerViewController *parentViewController = _delegate.parentViewController;
        if (parentViewController) {
            [parentViewController didLongPressYouTimeStamp];
        }
    }
}

%end
%end

/**
  * Hooks YTSettingsViewController to reorder settings items for YouTimeStamp
  * This moves the "Hold to copy without timestamp" setting above the "Order" setting
  */
// Helper function to get localized string for YouTimeStamp bundle
static NSString *getYouTimeStampLocalizedString(NSString *key) {
    NSBundle *bundle = YouTimeStampBundle();
    return [bundle localizedStringForKey:key value:nil table:nil];
}

// Helper function to get item title from YTSettingsSectionItem
// Tries _title first, then title property, with error handling
static NSString *getItemTitle(id item) {
    @try {
        // First try the private _title property
        NSString *title = [item valueForKey:@"_title"];
        if (title) return title;
    } @catch (NSException *exception) {
        // If _title doesn't exist, try the public title property
    }
    @try {
        NSString *title = [item valueForKey:@"title"];
        if (title) return title;
    } @catch (NSException *exception) {
        // Property doesn't exist
    }
    return nil;
}

// Helper function to reorder settings items for YouTimeStamp section
// Swaps the Order and Hold to copy settings so Hold to copy appears first
static NSArray *reorderYouTimeStampSettings(NSArray *items) {
    if (items.count == 0) return items;
    
    NSMutableArray *mutableItems = [items mutableCopy];
    
    // Find YouTimeStamp header, Order item, and Hold to copy item indices
    NSInteger youTimeStampHeaderIndex = -1;
    NSInteger orderItemIndex = -1;
    NSInteger holdToCopyIndex = -1;
    
    // Get localized strings for Hold to copy setting
    NSString *holdToCopyTitle = getYouTimeStampLocalizedString(@"YouTimeStamp-HoldToCopyWithoutTimestamp_KEY");
    
    for (NSUInteger i = 0; i < mutableItems.count; i++) {
        id item = mutableItems[i];
        NSString *itemTitle = getItemTitle(item);
        if (!itemTitle) continue;
        
        // Find YouTimeStamp header
        if ([itemTitle isEqualToString:TweakKey]) {
            youTimeStampHeaderIndex = i;
        }
        // Find Order item (only within YouTimeStamp section)
        else if (youTimeStampHeaderIndex >= 0 && orderItemIndex < 0 && [itemTitle isEqualToString:@"Order"]) {
            orderItemIndex = i;
        }
        // Find Hold to copy item (by checking if title matches)
        else if (youTimeStampHeaderIndex >= 0 && holdToCopyIndex < 0 && holdToCopyTitle && [itemTitle isEqualToString:holdToCopyTitle]) {
            holdToCopyIndex = i;
        }
    }
    
    // If we found both Order and Hold to copy items within YouTimeStamp section,
    // and Hold to copy is after Order, swap them
    if (orderItemIndex >= 0 && holdToCopyIndex >= 0 && holdToCopyIndex > orderItemIndex) {
        id orderItem = mutableItems[orderItemIndex];
        id holdToCopyItem = mutableItems[holdToCopyIndex];
        mutableItems[orderItemIndex] = holdToCopyItem;
        mutableItems[holdToCopyIndex] = orderItem;
        return [mutableItems copy];
    }
    
    return items;
}

%group Settings
%hook YTSettingsViewController

// Hook for newer YouTube versions with icon parameter
- (void)setSectionItems:(NSArray *)items forCategory:(NSUInteger)category title:(NSString *)title icon:(id)icon titleDescription:(NSString *)titleDescription headerHidden:(BOOL)headerHidden {
    if (category == YTVideoOverlaySection) {
        items = reorderYouTimeStampSettings(items);
    }
    %orig(items, category, title, icon, titleDescription, headerHidden);
}

// Hook for older YouTube versions without icon parameter
- (void)setSectionItems:(NSArray *)items forCategory:(NSUInteger)category title:(NSString *)title titleDescription:(NSString *)titleDescription headerHidden:(BOOL)headerHidden {
    if (category == YTVideoOverlaySection) {
        items = reorderYouTimeStampSettings(items);
    }
    %orig(items, category, title, titleDescription, headerHidden);
}

%end
%end

%ctor {
    // Set default value for HoldToCopyWithoutTimestamp if not already set
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:HoldToCopyWithoutTimestampKey] == nil) {
        [defaults setBool:YES forKey:HoldToCopyWithoutTimestampKey];
    }
    
    initYTVideoOverlay(TweakKey, @{
        AccessibilityLabelKey: @"Copy Timestamp",
        SelectorKey: @"didPressYouTimeStamp:",
        ExtraBooleanKeys: @[HoldToCopyWithoutTimestampKey],
    });
    %init(Main);
    %init(Top);
    %init(Bottom);
    %init(Settings);
}
