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

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ → %@: %.1f mm (surface), %@",
            self.p1Name, self.p2Name, self.distanceSurface,
            self.clockwise ? @"CW" : @"CCW"];
}

@end
