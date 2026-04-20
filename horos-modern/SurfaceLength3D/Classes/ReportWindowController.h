// ReportWindowController.h — radial distance visualization window

#import <AppKit/AppKit.h>

@class ViewerController, SurfaceLength3DFilter, ReportView;

NS_ASSUME_NONNULL_BEGIN

@interface ReportWindowController : NSWindowController

- (instancetype)initWithWindow:(nullable NSWindow *)window NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (instancetype)initWithViewer:(ViewerController *)viewer
                  pluginFilter:(SurfaceLength3DFilter *)filter NS_DESIGNATED_INITIALIZER;

- (void)updateSegmentedControl;

@property (nonatomic, readonly) NSInteger mainCentrePointIndex;
@property (nonatomic, readonly) double    maxDistance;

- (nullable NSString *)nameOfSelectedCentrePoint;
- (NSString *)displayNameForROIIndex:(NSInteger)roiIndex;
- (NSInteger)calculatedPairCount;
- (double)meanDistanceRatio;
- (double)maxSurfaceDistance;
- (ViewerController *)viewerController;
- (SurfaceLength3DFilter *)filter;

@end

NS_ASSUME_NONNULL_END
