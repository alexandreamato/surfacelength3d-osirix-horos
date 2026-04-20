// WizardWindowController.h — 3-step wizard (Place Points → Process → Report)
// Step 1 (VOI Cutter via AppleScript) removed; Horos's built-in ROI tools are sufficient.

#import <AppKit/AppKit.h>

@class ViewerController, SurfaceLength3DFilter;

NS_ASSUME_NONNULL_BEGIN

@interface WizardWindowController : NSWindowController

- (instancetype)initWithWindow:(nullable NSWindow *)window NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (instancetype)initWithViewer:(ViewerController *)viewer
                  pluginFilter:(SurfaceLength3DFilter *)filter NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
