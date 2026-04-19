// ValidationPhantom.h — geometric validation of the Dijkstra geodesic algorithm
//
// Creates synthetic VTK surface geometry (sphere or cylinder) with analytically
// known geodesic distances, runs the same algorithm used clinically, and reports
// the % error vs the ground truth.
//
// Purpose: provides the phantom validation called for in:
// Amato ACM. J Vasc Bras. 2016;15(4):308-311. DOI: 10.1590/1677-5449.005316

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PhantomShape) {
    PhantomShapeSphere,    // Analytical: R * arccos(P1·P2 / R²)
    PhantomShapeCylinder,  // Analytical: sqrt(deltaZ² + (R*deltaTheta)²)
};

@interface PhantomTestCase : NSObject
@property (nonatomic, readonly, copy) NSString *label;
@property (nonatomic, readonly) double analyticalDistance;   // mm — ground truth
@property (nonatomic, readonly) double measuredDistance;     // mm — Dijkstra result
@property (nonatomic, readonly) double absoluteError;        // mm
@property (nonatomic, readonly) double percentError;         // %
@end

@interface ValidationPhantomResult : NSObject
@property (nonatomic, readonly) PhantomShape shape;
@property (nonatomic, readonly) double radius;               // mm
@property (nonatomic, readonly) NSInteger meshResolution;    // subdivisions
@property (nonatomic, readonly, copy) NSArray<PhantomTestCase *> *testCases;
@property (nonatomic, readonly) double meanPercentError;
@property (nonatomic, readonly) double maxPercentError;
@property (nonatomic, readonly, copy) NSString *summary;
@end

@interface ValidationPhantom : NSObject

/// Runs validation asynchronously on a background thread.
/// completion is called on the main thread.
+ (void)validateShape:(PhantomShape)shape
               radius:(double)radius            // mm
       meshResolution:(NSInteger)resolution     // 50–200; higher = more accurate, slower
           completion:(void (^)(ValidationPhantomResult *result))completion;

@end

NS_ASSUME_NONNULL_END
