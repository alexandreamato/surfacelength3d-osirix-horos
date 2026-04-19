#import "PointPair.h"

@implementation PointPair

- (instancetype)init {
    self = [super init];
    if (self) {
        _state       = PointPairStateNone;
        _displayPath = YES;
    }
    return self;
}

- (double)distanceRatio {
    if (self.distanceDirect < 1e-9) return 1.0;
    return self.distanceSurface / self.distanceDirect;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ → %@: %.1f mm (surface), %@",
            self.p1Name, self.p2Name, self.distanceSurface,
            self.clockwise ? @"CW" : @"CCW"];
}

@end
