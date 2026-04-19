// ReportView.m — radial plot: each point placed at a polar position derived from
// its Z-offset (vertical) and clockwise/CCW flag (horizontal) relative to the centre.

#import "ReportView.h"
#import "ReportWindowController.h"
#import "PointPair.h"
#import "SurfaceLength3DFilter.h"
#import "ROI.h"
#import "DCMPix.h"

static const CGFloat kMarkerDiameter = 10.0;
static const CGFloat kLineWidth      = 2.0;

@implementation ReportView

- (BOOL)isFlipped { return NO; }

- (void)drawRect:(NSRect)dirtyRect {
    ReportWindowController *wc = (ReportWindowController *)self.window.windowController;
    if (!wc) return;

    NSRect bounds = self.bounds;

    // Background
    [[NSColor colorWithWhite:0.92 alpha:1.0] setFill];
    NSRectFill(bounds);

    NSArray<PointPair *> *results = wc.filter.pairsResultsArray;
    if (!results.count) return;

    // Scale: fit largest distance inside half the view
    double minDim = MIN(NSWidth(bounds), NSHeight(bounds));
    double scale  = (wc.maxDistance > 0) ? minDim / (wc.maxDistance * 2.0) : 1.0;

    NSPoint centre = NSMakePoint(NSMidX(bounds), NSMidY(bounds));
    NSArray *roiList = [wc.viewerController point2DList];

    NSString *centreName = [wc nameOfSelectedCentrePoint] ?: @"";
    BOOL plotAll = [centreName isEqualToString:NSLocalizedString(@"All", nil)];

    NSInteger centrePtIndex = wc.mainCentrePointIndex;
    if (!plotAll) {
        for (PointPair *pp in results) {
            if ([pp.p1Name isEqualToString:centreName]) { centrePtIndex = pp.p1ROIIndex; break; }
            if ([pp.p2Name isEqualToString:centreName]) { centrePtIndex = pp.p2ROIIndex; break; }
        }
        centreName = ((ROI *)roiList[(NSUInteger)centrePtIndex]).name;
    } else {
        centreName = ((ROI *)roiList[(NSUInteger)centrePtIndex]).name;
    }

    // Get DICOM location for centre point
    ROI    *centreROI = roiList[(NSUInteger)centrePtIndex];
    DCMPix *centreDCM = centreROI.pix;
    float centreLocation[3];
    [centreDCM convertPixX:[centreROI.points[0] x]
                      pixY:[centreROI.points[0] y]
             toDICOMCoords:centreLocation];

    // Store computed view coordinates for the "All" path-drawing pass
    NSMutableArray<NSValue *> *viewCoords =
        [NSMutableArray arrayWithCapacity:roiList.count];
    for (NSUInteger i = 0; i < roiList.count; i++) {
        [viewCoords addObject:[NSValue valueWithPoint:NSZeroPoint]];
    }
    [viewCoords replaceObjectAtIndex:(NSUInteger)centrePtIndex
                          withObject:[NSValue valueWithPoint:centre]];

    // Typography
    NSDictionary *labelAttrs  = @{ NSFontAttributeName: [NSFont systemFontOfSize:13],
                                   NSForegroundColorAttributeName: [NSColor blackColor] };
    NSDictionary *distAttrs   = @{ NSFontAttributeName: [NSFont systemFontOfSize:10],
                                   NSForegroundColorAttributeName: [NSColor darkGrayColor] };

    // Draw lines and points from the centre to each connected point
    for (PointPair *pp in results) {
        BOOL cwFromCentre = pp.clockwise;
        NSInteger ptIndex = -1;

        if ([pp.p1Name isEqualToString:centreName]) {
            ptIndex = pp.p2ROIIndex;
        } else if ([pp.p2Name isEqualToString:centreName]) {
            ptIndex = pp.p1ROIIndex;
            cwFromCentre = !pp.clockwise;
        }

        if (ptIndex < 0) continue;

        ROI    *ptROI = roiList[(NSUInteger)ptIndex];
        DCMPix *ptDCM = ptROI.pix;
        float ptLocation[3];
        [ptDCM convertPixX:[ptROI.points[0] x]
                      pixY:[ptROI.points[0] y]
             toDICOMCoords:ptLocation];

        double deltaZ = ptLocation[2] - centreLocation[2];
        double lateral = (pp.distanceSurface > fabs(deltaZ))
                         ? sqrt(pp.distanceSurface * pp.distanceSurface - deltaZ * deltaZ)
                         : 0.0;

        CGFloat ptX = centre.x + (cwFromCentre ? -lateral : lateral) * scale;
        CGFloat ptY = centre.y + deltaZ * scale;
        NSPoint ptView = NSMakePoint(ptX, ptY);

        [viewCoords replaceObjectAtIndex:(NSUInteger)ptIndex
                              withObject:[NSValue valueWithPoint:ptView]];

        // Line from point to centre
        NSBezierPath *line = [NSBezierPath bezierPath];
        line.lineWidth = kLineWidth;
        [pp.pathColor setStroke];
        [line moveToPoint:ptView];
        [line lineToPoint:centre];
        [line stroke];

        // Point marker (blue circle)
        [[NSColor systemBlueColor] setFill];
        NSBezierPath *dot = [NSBezierPath bezierPathWithOvalInRect:
            NSMakeRect(ptX - kMarkerDiameter/2, ptY - kMarkerDiameter/2,
                       kMarkerDiameter, kMarkerDiameter)];
        [dot fill];

        // Point label
        CGFloat yOff = (ptY < centre.y) ? -22.0 : 8.0;
        [ptROI.name drawAtPoint:NSMakePoint(ptX - 10, ptY + yOff) withAttributes:labelAttrs];

        // Distance label at midpoint of line
        NSPoint mid = NSMakePoint((ptX + centre.x) / 2, (ptY + centre.y) / 2);
        CGFloat xOff = (fabs(ptX - centre.x) > fabs(ptY - centre.y)) ? 0 : 8;
        yOff         = (fabs(ptX - centre.x) > fabs(ptY - centre.y)) ? -14 : 0;
        NSMutableDictionary *da = [distAttrs mutableCopy];
        da[NSForegroundColorAttributeName] = pp.pathColor;
        [[NSString stringWithFormat:@"%.1f", pp.distanceSurface]
            drawAtPoint:NSMakePoint(mid.x + xOff, mid.y + yOff) withAttributes:da];
    }

    // Centre marker (red circle)
    [[NSColor systemRedColor] setFill];
    NSBezierPath *centreMarker = [NSBezierPath bezierPathWithOvalInRect:
        NSMakeRect(centre.x - kMarkerDiameter/2, centre.y - kMarkerDiameter/2,
                   kMarkerDiameter, kMarkerDiameter)];
    [centreMarker fill];

    NSMutableDictionary *redLabel = [labelAttrs mutableCopy];
    redLabel[NSForegroundColorAttributeName] = [NSColor systemRedColor];
    [centreName drawAtPoint:NSMakePoint(centre.x - 20, centre.y - 22) withAttributes:redLabel];

    // If "All" selected, draw inter-point paths (dashed if they wrap around the back)
    if (!plotAll) return;

    for (PointPair *pp in results) {
        if (pp.p1ROIIndex == centrePtIndex || pp.p2ROIIndex == centrePtIndex) continue;

        NSPoint pt1 = [viewCoords[(NSUInteger)pp.p1ROIIndex] pointValue];
        NSPoint pt2 = [viewCoords[(NSUInteger)pp.p2ROIIndex] pointValue];

        BOOL aroundBack = [self pathGoesAroundBack:pp centreIndex:centrePtIndex results:results];

        NSBezierPath *line = [NSBezierPath bezierPath];
        line.lineWidth = kLineWidth;
        [pp.pathColor setStroke];
        [line moveToPoint:pt1];
        [line lineToPoint:pt2];
        if (aroundBack) {
            CGFloat dash[2] = { 5.0, 3.0 };
            [line setLineDash:dash count:2 phase:0];
        }
        [line stroke];

        NSPoint mid = NSMakePoint((pt1.x + pt2.x) / 2, (pt1.y + pt2.y) / 2);
        CGFloat xOff = (fabs(pt1.x - pt2.x) > fabs(pt1.y - pt2.y)) ? 0 : 8;
        CGFloat yOff = (fabs(pt1.x - pt2.x) > fabs(pt1.y - pt2.y)) ? -14 : 0;
        NSMutableDictionary *da = [distAttrs mutableCopy];
        da[NSForegroundColorAttributeName] = pp.pathColor;
        [[NSString stringWithFormat:@"%.1f", pp.distanceSurface]
            drawAtPoint:NSMakePoint(mid.x + xOff, mid.y + yOff) withAttributes:da];
    }
}

// ---------------------------------------------------------------------------
// Determine whether the path between two non-centre points wraps around the back
// (uses the clockwise flags of adjacent paths through the centre).
// ---------------------------------------------------------------------------
- (BOOL)pathGoesAroundBack:(PointPair *)pp
               centreIndex:(NSInteger)cIdx
                   results:(NSArray<PointPair *> *)results {
    BOOL c_to_p1 = NO, p2_to_c = NO;

    for (PointPair *cp in results) {
        BOOL involvesCentre = (cp.p1ROIIndex == cIdx || cp.p2ROIIndex == cIdx);
        if (!involvesCentre) continue;

        if (cp.p1ROIIndex == pp.p1ROIIndex || cp.p2ROIIndex == pp.p1ROIIndex) {
            c_to_p1 = (cp.p2ROIIndex == pp.p1ROIIndex) ? cp.clockwise : !cp.clockwise;
        }
        if (cp.p1ROIIndex == pp.p2ROIIndex || cp.p2ROIIndex == pp.p2ROIIndex) {
            p2_to_c = (cp.p1ROIIndex == pp.p2ROIIndex) ? cp.clockwise : !cp.clockwise;
        }
    }

    if (c_to_p1 == p2_to_c) {
        BOOL p1_to_p2 = pp.clockwise;
        if (p1_to_p2 == c_to_p1) return YES;
    }
    return NO;
}

@end
