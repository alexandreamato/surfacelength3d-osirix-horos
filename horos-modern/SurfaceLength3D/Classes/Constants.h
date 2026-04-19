// Constants.h — shared types and notification names for SurfaceLength3D

#import <Foundation/Foundation.h>

typedef struct {
    double x, y, z;
} SL3DPoint;

FOUNDATION_EXPORT NSNotificationName const SL3DSurfaceRenderedNotification;
FOUNDATION_EXPORT NSNotificationName const SL3DFinishedProcessingNotification;
