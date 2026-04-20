// GeodesicProcessor.h — computes geodesic paths on VTK surface meshes using Dijkstra's algorithm

#import <Foundation/Foundation.h>

// VTK opaque forward declaration — keeps id keyword safe in Objective-C headers
#ifdef __cplusplus
#  define id Id
#  include "vtkActor.h"
#  undef id
#else
typedef void vtkActor;
#endif

@class ViewerController, ProcessWindowController, SurfaceLength3DFilter;

NS_ASSUME_NONNULL_BEGIN

@interface GeodesicProcessor : NSObject

@property (nonatomic, assign) double pathLineWidth;

- (instancetype)initWithViewerController:(nullable ViewerController *)vc
                        windowController:(nullable ProcessWindowController *)wc
                            pluginFilter:(nullable SurfaceLength3DFilter *)filter NS_DESIGNATED_INITIALIZER;

/// Returns info dicts for all VTK actors with enough vertices to be surfaces.
/// Keys: @"index" (NSInteger), @"vertices" (NSInteger), @"label" (NSString).
- (NSArray<NSDictionary *> *)availableSurfaceDescriptions;

/// Select which surface actor to use for geodesic computation. Default = -1 (auto: largest).
- (void)setPreferredSurfaceIndex:(NSInteger)index;

/// Runs Dijkstra on a background thread; calls completion on the main thread when done.
- (void)processAllPathsWithCompletion:(nullable void (^)(void))completion;

- (void)removeAllPaths;
- (void)removePathAtIndex:(NSInteger)index;
- (void)displayPathAtIndex:(NSInteger)index;
- (void)applyCurrentLineWidthToVisiblePaths;

@end

NS_ASSUME_NONNULL_END
