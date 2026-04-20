// ProcessWindowController.h — table view of point pairs with direct/surface distances

#import <AppKit/AppKit.h>

@class ViewerController, SurfaceLength3DFilter;

NS_ASSUME_NONNULL_BEGIN

@interface ProcessWindowController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>

- (instancetype)initWithWindow:(nullable NSWindow *)window NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (instancetype)initWithViewer:(ViewerController *)viewer
                  pluginFilter:(SurfaceLength3DFilter *)filter NS_DESIGNATED_INITIALIZER;

- (void)renewProcessingTable;
- (void)updateResultsColumn;

@end

NS_ASSUME_NONNULL_END
