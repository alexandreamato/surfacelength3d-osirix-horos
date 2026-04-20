// ReportWindowController.m — programmatic UI (no XIB)

#import "ReportWindowController.h"
#import "ReportView.h"
#import "SurfaceLength3DFilter.h"
#import <Horos/ViewerController.h>
#import <Horos/ROI.h>
#import <Horos/DCMPix.h>
#import "PointPair.h"
#import "MeasurementExporter.h"
#import "VascularPlanningReport.h"

@interface ReportWindowController ()

@property (nonatomic, weak)   ViewerController      *viewerController;
@property (nonatomic, weak)   SurfaceLength3DFilter *filter;
@property (nonatomic, assign) NSInteger              mainCentrePointIndex;
@property (nonatomic, assign) double                 maxDistance;

@property (nonatomic, strong) ReportView           *reportView;
@property (nonatomic, strong) NSSegmentedControl   *centrePointControl;
@property (nonatomic, strong) NSButton             *exportPDFButton;
@property (nonatomic, strong) NSButton             *vascularPlanButton;

@end

@implementation ReportWindowController

- (instancetype)initWithViewer:(ViewerController *)viewer
                  pluginFilter:(SurfaceLength3DFilter *)filter {
    NSWindow *win = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 600, 520)
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
                    backing:NSBackingStoreBuffered
                      defer:NO];
    win.title = @"Surface Length 3D — Report";
    win.releasedWhenClosed = NO;
    self = [super initWithWindow:win];
    if (self) {
        _viewerController      = viewer;
        _filter          = filter;
        _mainCentrePointIndex  = [self calcMainCentrePoint];
        _maxDistance           = [self calcMaxDistance];
        [self buildUI];
        [self updateSegmentedControl];
        [win center];
    }
    return self;
}

- (void)buildUI {
    NSView *content = self.window.contentView;

    // --- Report view ---
    _reportView = [[ReportView alloc] init];
    _reportView.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:_reportView];

    // --- Segmented control ---
    _centrePointControl = [[NSSegmentedControl alloc] init];
    _centrePointControl.translatesAutoresizingMaskIntoConstraints = NO;
    [_centrePointControl setTarget:self];
    [_centrePointControl setAction:@selector(changeCentrePoint:)];
    [content addSubview:_centrePointControl];

    // --- Buttons ---
    _exportPDFButton = [NSButton buttonWithTitle:@"Export PDF" target:self action:@selector(doExportPDF:)];
    _exportPDFButton.translatesAutoresizingMaskIntoConstraints = NO;

    _vascularPlanButton = [NSButton buttonWithTitle:@"Vascular Planning" target:self action:@selector(doVascularPlan:)];
    _vascularPlanButton.translatesAutoresizingMaskIntoConstraints = NO;

    NSButton *closeButton = [NSButton buttonWithTitle:@"Close" target:self action:@selector(closeReport:)];
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    closeButton.keyEquivalent = @"\033";

    [content addSubview:_exportPDFButton];
    [content addSubview:_vascularPlanButton];
    [content addSubview:closeButton];

    // --- Constraints ---
    NSDictionary *v = NSDictionaryOfVariableBindings(_reportView, _centrePointControl,
                                                      _exportPDFButton, _vascularPlanButton, closeButton);
    NSArray *hFormats = @[
        @"H:|-8-[_reportView]-8-|",
        @"H:|-8-[_centrePointControl]-(>=8)-|",
        @"H:|-8-[_exportPDFButton]-8-[_vascularPlanButton]-(>=8)-[closeButton]-8-|",
    ];
    NSArray *vFormats = @[
        @"V:|-8-[_reportView]-8-[_centrePointControl]-8-[_exportPDFButton]-8-|",
    ];
    for (NSString *fmt in hFormats)
        [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:fmt options:0 metrics:nil views:v]];
    for (NSString *fmt in vFormats)
        [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:fmt options:0 metrics:nil views:v]];

    for (NSView *vw in @[_vascularPlanButton, closeButton])
        [content addConstraint:[NSLayoutConstraint constraintWithItem:vw attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_exportPDFButton attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
}

// ---------------------------------------------------------------------------
#pragma mark - Segmented control
// ---------------------------------------------------------------------------

- (void)updateSegmentedControl {
    NSArray *pts    = [_viewerController point2DList];
    NSInteger count = (NSInteger)pts.count;

    [self.centrePointControl setSegmentCount:count + 1];
    [self.centrePointControl setLabel:NSLocalizedString(@"All", nil) forSegment:0];

    for (NSInteger i = 0; i < count; i++) {
        [self.centrePointControl setLabel:[self displayNameForROIIndex:i] forSegment:i + 1];
    }

    [self.centrePointControl setSelectedSegment:0];

    [self.reportView setNeedsDisplay:YES];
}

- (nullable NSString *)nameOfSelectedCentrePoint {
    return [self.centrePointControl labelForSegment:self.centrePointControl.selectedSegment];
}

- (NSString *)displayNameForROIIndex:(NSInteger)roiIndex {
    for (PointPair *pp in self.filter.pairsResultsArray) {
        if (pp.p1ROIIndex == roiIndex && pp.p1Name.length) return pp.p1Name;
        if (pp.p2ROIIndex == roiIndex && pp.p2Name.length) return pp.p2Name;
    }

    NSArray *pts = [self.viewerController point2DList];
    if (roiIndex >= 0 && roiIndex < (NSInteger)pts.count) {
        ROI *roi = pts[(NSUInteger)roiIndex];
        return roi.name ?: [NSString stringWithFormat:@"Point %ld", (long)(roiIndex + 1)];
    }
    return [NSString stringWithFormat:@"Point %ld", (long)(roiIndex + 1)];
}

- (NSInteger)calculatedPairCount {
    NSInteger count = 0;
    for (PointPair *pp in self.filter.pairsResultsArray) {
        if (pp.state == PointPairStateCalculated) count++;
    }
    return count;
}

- (double)meanDistanceRatio {
    double sum = 0.0;
    NSInteger count = 0;
    for (PointPair *pp in self.filter.pairsResultsArray) {
        if (pp.state != PointPairStateCalculated) continue;
        sum += pp.distanceRatio;
        count++;
    }
    return count > 0 ? (sum / (double)count) : 0.0;
}

- (double)maxSurfaceDistance {
    double max = 0.0;
    for (PointPair *pp in self.filter.pairsResultsArray) {
        if (pp.state != PointPairStateCalculated) continue;
        if (pp.distanceSurface > max) max = pp.distanceSurface;
    }
    return max;
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

- (IBAction)doExportPDF:(id)sender {
    NSString *patientName = @"";
    DCMPix *pix = _viewerController.pixList.firstObject;
    if (pix) patientName = pix.generatedName ?: @"";

    [MeasurementExporter exportToPDF:_filter.pairsResultsArray
                          reportView:self.reportView
                           patientID:patientName
                    presentingWindow:self.window
                          completion:nil];
}

- (IBAction)doVascularPlan:(id)sender {
    VascularPlanningResult *plan =
        [VascularPlanningReport analyzeWithPairs:_filter.pairsResultsArray];

    NSString *recStr;
    switch (plan.recommendation) {
        case GraftRecommendationPatch:
            recStr = NSLocalizedString(@"Patch (≤25mm)", nil); break;
        case GraftRecommendationCoselliGraft:
            recStr = NSLocalizedString(@"Coselli Graft (25–55mm)", nil); break;
        case GraftRecommendationIndividual:
            recStr = NSLocalizedString(@"Individual Reimplantation (>55mm)", nil); break;
        default:
            recStr = NSLocalizedString(@"Inconclusive — no vessels identified", nil); break;
    }

    NSString *vessels = plan.detectedVessels.count
        ? [plan.detectedVessels componentsJoinedByString:@", "]
        : NSLocalizedString(@"none", nil);

    NSString *msg = [NSString stringWithFormat:
        @"Recommendation: %@\n\nRationale: %@\n\nDetected vessels: %@\n\n%@",
        recStr, plan.rationale, vessels, plan.disclaimer];

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText     = NSLocalizedString(@"Vascular Planning (Coselli)", nil);
    alert.informativeText = msg;
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

// ---------------------------------------------------------------------------
#pragma mark - Calculations
// ---------------------------------------------------------------------------

- (NSInteger)calcMainCentrePoint {
    NSArray<PointPair *> *results = _filter.pairsResultsArray;
    NSInteger totalPts = (NSInteger)[[_viewerController point2DList] count];
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
    for (PointPair *pp in _filter.pairsResultsArray) {
        if (pp.distanceSurface > max) max = pp.distanceSurface;
    }
    return max;
}

@end
