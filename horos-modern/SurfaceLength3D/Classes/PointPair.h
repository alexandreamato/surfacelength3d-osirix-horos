// PointPair.h — data model for a pair of anatomical points and their computed distances

#import <AppKit/AppKit.h>

typedef NS_ENUM(NSInteger, PointPairState) {
    PointPairStateNone = 0,
    PointPairStateCalculating,
    PointPairStateCalculated
};

NS_ASSUME_NONNULL_BEGIN

@interface PointPair : NSObject

@property (nonatomic, copy)   NSString             *p1Name;
@property (nonatomic, copy)   NSString             *p2Name;
@property (nonatomic, strong) NSArray<NSValue *>   *pathPoints;   // NSValue encoding SL3DPoint
@property (nonatomic, strong) NSColor              *pathColor;

@property (nonatomic, assign) PointPairState state;
@property (nonatomic, assign) BOOL           displayPath;
@property (nonatomic, assign) double         distanceDirect;   // Euclidean (mm)
@property (nonatomic, assign) double         distanceSurface;  // Geodesic (mm)
@property (nonatomic, assign) BOOL           clockwise;
@property (nonatomic, assign) NSInteger      p1ROIIndex;
@property (nonatomic, assign) NSInteger      p2ROIIndex;

@end

NS_ASSUME_NONNULL_END
