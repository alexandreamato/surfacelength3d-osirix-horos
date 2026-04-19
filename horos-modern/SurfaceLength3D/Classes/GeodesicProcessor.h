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

- (instancetype)initWithViewerController:(ViewerController *)vc
                        windowController:(ProcessWindowController *)wc
                            pluginFilter:(SurfaceLength3DFilter *)filter NS_DESIGNATED_INITIALIZER;

// Runs Dijkstra on a background thread; calls completion on the main thread when done.
- (void)processAllPathsWithCompletion:(nullable void (^)(void))completion;

- (void)removeAllPaths;
- (void)removePathAtIndex:(NSInteger)index;
- (void)displayPathAtIndex:(NSInteger)index;

@end

NS_ASSUME_NONNULL_END
