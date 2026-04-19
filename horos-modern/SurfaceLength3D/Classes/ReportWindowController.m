// ReportWindowController.m
//
// XIB: Report.xib
//   Window with:
//   - ReportView (reportView) filling most of the window
//   - NSSegmentedControl (centrePointControl) for choosing the centre point
//   - NSButton "Close"

#import "ReportWindowController.h"
#import "ReportView.h"
#import "SurfaceLength3DFilter.h"
#import "ViewerController.h"
#import "ROI.h"
#import "PointPair.h"

@interface ReportWindowController ()

@property (nonatomic, weak)   ViewerController      *_viewerController;
@property (nonatomic, weak)   SurfaceLength3DFilter *_filter;
@property (nonatomic, assign) NSInteger              _mainCentrePointIndex;
@property (nonatomic, assign) double                 _maxDistance;

@property (nonatomic, weak) IBOutlet ReportView           *reportView;
@property (nonatomic, weak) IBOutlet NSSegmentedControl   *centrePointControl;

@end

@implementation ReportWindowController

@dynamic viewerController, filter, mainCentrePointIndex, maxDistance;

- (instancetype)initWithViewer:(ViewerController *)viewer
                  pluginFilter:(SurfaceLength3DFilter *)filter {
    self = [super initWithWindowNibName:@"Report" owner:self];
    if (self) {
        __viewerController       = viewer;
        __filter                 = filter;
        __mainCentrePointIndex   = [self calcMainCentrePoint];
        __maxDistance            = [self calcMaxDistance];
    }
    return self;
}

- (ViewerController *)viewerController      { return __viewerController; }
- (SurfaceLength3DFilter *)filter           { return __filter; }
- (NSInteger)mainCentrePointIndex           { return __mainCentrePointIndex; }
- (double)maxDistance                       { return __maxDistance; }

// ---------------------------------------------------------------------------
#pragma mark - Segmented control
// ---------------------------------------------------------------------------

- (void)updateSegmentedControl {
    NSArray *pts    = [__viewerController point2DList];
    NSInteger count = (NSInteger)pts.count;

    [self.centrePointControl setSegmentCount:count + 1];
    [self.centrePointControl setLabel:NSLocalizedString(@"All", nil) forSegment:0];

    for (NSInteger i = 0; i < count; i++) {
        ROI *roi = pts[(NSUInteger)i];
        [self.centrePointControl setLabel:roi.name forSegment:i + 1];
    }

    [self.reportView setNeedsDisplay:YES];
}

- (nullable NSString *)nameOfSelectedCentrePoint {
    return [self.centrePointControl labelForSegment:self.centrePointControl.selectedSegment];
}

// ---------------------------------------------------------------------------
#pragma mark - Actions
// ---------------------------------------------------------------------------

- (IBAction)closeReport:(id)sender {
    [self.window performClose:nil];
}

- (IBAction)changeCentrePoint:(id)sender {
    [self.reportView setNeedsDisplay:YES];
}

// ---------------------------------------------------------------------------
#pragma mark - Calculations
// ---------------------------------------------------------------------------

- (NSInteger)calcMainCentrePoint {
    NSArray<PointPair *> *results = __filter.pairsResultsArray;
    NSInteger totalPts = (NSInteger)[[__viewerController point2DList] count];
    NSInteger minIdx   = 0;
    double    minTotal = DBL_MAX;

    for (NSInteger pt = 0; pt < totalPts; pt++) {
        double total = 0;
        for (PointPair *pp in results) {
            if (pp.p1ROIIndex == pt || pp.p2ROIIndex == pt) total += pp.distanceSurface;
        }
        if (total < minTotal) { minTotal = total; minIdx = pt; }
    }
    return minIdx;
}

- (double)calcMaxDistance {
    double max = 0;
    for (PointPair *pp in __filter.pairsResultsArray) {
        if (pp.distanceSurface > max) max = pp.distanceSurface;
    }
    return max;
}

@end
