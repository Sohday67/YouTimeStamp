#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <UIKit/UIKit.h>

#import "../YTVideoOverlay/Header.h"
#import "../YTVideoOverlay/Init.x"
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
#define OrderSettingTitle @"ORDER"

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

// For settings reordering
@interface YTIIcon : NSObject
@property (nonatomic, assign) NSInteger iconType;
@end

@interface YTSettingsViewController (YouTimeStamp)
- (void)setSectionItems:(NSArray *)items forCategory:(NSUInteger)category title:(NSString *)title titleDescription:(NSString *)desc headerHidden:(BOOL)hidden;
- (void)setSectionItems:(NSArray *)items forCategory:(NSUInteger)category title:(NSString *)title icon:(YTIIcon *)icon titleDescription:(NSString *)desc headerHidden:(BOOL)hidden;
@end

@interface YTSettingsSectionItem (YouTimeStamp)
- (NSString *)title;
- (BOOL)isEnabled;
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

static NSArray *reorderYouTimeStampSettings(NSArray *items) {
    if (!items || items.count == 0) return items;
    
    NSMutableArray *mutableItems = [items mutableCopy];
    
    // Load the YTVideoOverlay bundle to get the localized "ORDER" title
    NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"YTVideoOverlay" ofType:@"bundle"];
    NSBundle *tweakBundle = bundlePath 
        ? [NSBundle bundleWithPath:bundlePath]
        : [NSBundle bundleWithPath:[NSString stringWithFormat:ROOT_PATH_NS(@"/Library/Application Support/YTVideoOverlay.bundle")]];
    
    // If bundle not found, return items unchanged
    if (!tweakBundle) return items;
    
    NSString *orderTitle = [tweakBundle localizedStringForKey:OrderSettingTitle value:nil table:nil];
    
    // Find the YouTimeStamp section and reorder its items
    // Structure: Header, Enabled, Position, Order, ExtraBooleanKeys...
    // We want: Header, Enabled, Position, ExtraBooleanKeys..., Order
    NSInteger youTimeStampHeaderIndex = -1;
    NSInteger nextSectionIndex = mutableItems.count; // Default to end if no next section
    
    // Find YouTimeStamp header and the next section header
    // Section headers in YTVideoOverlay are identified by having isEnabled=NO
    for (NSInteger i = 0; i < mutableItems.count; i++) {
        id item = mutableItems[i];
        if ([item respondsToSelector:@selector(title)]) {
            NSString *title = [item title];
            if ([title isEqualToString:TweakKey]) {
                youTimeStampHeaderIndex = i;
            } else if (youTimeStampHeaderIndex >= 0 && [item respondsToSelector:@selector(isEnabled)] && ![item isEnabled]) {
                // Found the next section header (disabled items are headers in YTVideoOverlay)
                nextSectionIndex = i;
                break;
            }
        }
    }
    
    if (youTimeStampHeaderIndex < 0) return items;
    
    // Find the Order item within YouTimeStamp section
    NSInteger orderItemIndex = -1;
    for (NSInteger i = youTimeStampHeaderIndex + 1; i < nextSectionIndex; i++) {
        id item = mutableItems[i];
        if ([item respondsToSelector:@selector(title)]) {
            NSString *title = [item title];
            if ([title isEqualToString:orderTitle]) {
                orderItemIndex = i;
                break;
            }
        }
    }
    
    if (orderItemIndex < 0 || orderItemIndex >= nextSectionIndex - 1) return items;
    
    // Move Order item to the end of YouTimeStamp section (before next section)
    id orderItem = mutableItems[orderItemIndex];
    [mutableItems removeObjectAtIndex:orderItemIndex];
    [mutableItems insertObject:orderItem atIndex:nextSectionIndex - 1];
    
    return [mutableItems copy];
}

/**
  * Reorders settings so that the Order option appears after ExtraBooleanKeys
  */
%group Settings
%hook YTSettingsViewController

- (void)setSectionItems:(NSArray *)items forCategory:(NSUInteger)category title:(NSString *)title titleDescription:(NSString *)desc headerHidden:(BOOL)hidden {
    if (category == 1222) { // YTVideoOverlay section
        items = reorderYouTimeStampSettings(items);
    }
    %orig(items, category, title, desc, hidden);
}

- (void)setSectionItems:(NSArray *)items forCategory:(NSUInteger)category title:(NSString *)title icon:(YTIIcon *)icon titleDescription:(NSString *)desc headerHidden:(BOOL)hidden {
    if (category == 1222) { // YTVideoOverlay section
        items = reorderYouTimeStampSettings(items);
    }
    %orig(items, category, title, icon, desc, hidden);
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
