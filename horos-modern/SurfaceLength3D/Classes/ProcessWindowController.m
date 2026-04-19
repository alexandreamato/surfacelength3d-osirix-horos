// ProcessWindowController.m
//
// XIB: Process.xib
//   Window containing:
//   - NSTableView (tableView) with columns:
//       "pairs"   — NSTextFieldCell  (Point Pairs)
//       "direct"  — NSTextFieldCell  (Direct mm)
//       "surface" — NSTextFieldCell  (Surface mm)
//       "display" — NSButtonCell checkBox (Display)
//   - NSProgressIndicator (progressIndicator, style=spinning, hidden initially)
//   - NSButton "Reprocess" (reprocessButton)
//   - NSButton "Close"

#import "ProcessWindowController.h"
#import "SurfaceLength3DFilter.h"
#import <OsiriXAPI/ViewerController.h>
#import "GeodesicProcessor.h"
#import "PointPair.h"
#import <OsiriXAPI/ROI.h>
#import <OsiriXAPI/DCMPix.h>
#import "Constants.h"

@interface ProcessWindowController ()

@property (nonatomic, weak)   ViewerController       *viewerController;
@property (nonatomic, weak)   SurfaceLength3DFilter  *filter;
@property (nonatomic, strong) GeodesicProcessor      *processor;
@property (nonatomic, strong) NSMutableArray<PointPair *> *pointPairs;

@property (nonatomic, weak) IBOutlet NSTableView          *tableView;
@property (nonatomic, weak) IBOutlet NSProgressIndicator  *progressIndicator;
@property (nonatomic, weak) IBOutlet NSButton             *reprocessButton;

@end

@implementation ProcessWindowController

- (instancetype)initWithViewer:(ViewerController *)viewer
                  pluginFilter:(SurfaceLength3DFilter *)filter {
    self = [super initWithWindowNibName:@"Process" owner:self];
    if (self) {
        _viewerController = viewer;
        _filter           = filter;
        _pointPairs       = [NSMutableArray array];
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(surfaceRendered:)
                                                 name:SL3DSurfaceRenderedNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// ---------------------------------------------------------------------------
#pragma mark - Setup / refresh
// ---------------------------------------------------------------------------

- (void)renewProcessingTable {
    self.processor = [[GeodesicProcessor alloc] initWithViewerController:self.viewerController
                                                        windowController:self
                                                            pluginFilter:self.filter];
    [self buildPointPairsArray];
    [self.tableView reloadData];
}

- (void)buildPointPairsArray {
    [self.pointPairs removeAllObjects];

    NSMutableArray *pts = [self.viewerController point2DList];
    NSUInteger count = pts.count;

    for (NSUInteger i = 0; i < count; i++) {
        for (NSUInteger j = i + 1; j < count; j++) {

            ROI    *roiA = pts[i], *roiB = pts[j];
            DCMPix *dcmA = roiA.pix, *dcmB = roiB.pix;

            float loc1[3], loc2[3];
            [dcmA convertPixX:[roiA.points[0] x] pixY:[roiA.points[0] y] toDICOMCoords:loc1];
            [dcmB convertPixX:[roiB.points[0] x] pixY:[roiB.points[0] y] toDICOMCoords:loc2];

            double dx = loc2[0]-loc1[0], dy = loc2[1]-loc1[1], dz = loc2[2]-loc1[2];
            double directDist = sqrt(dx*dx + dy*dy + dz*dz);

            PointPair *pp   = [[PointPair alloc] init];
            pp.p1Name        = roiA.name;
            pp.p2Name        = roiB.name;
            pp.p1ROIIndex    = (NSInteger)i;
            pp.p2ROIIndex    = (NSInteger)j;
            pp.distanceDirect = directDist;
            [self.pointPairs addObject:pp];
        }
    }

    // Assign distinct HSV colors
    NSInteger total = (NSInteger)self.pointPairs.count;
    for (NSInteger k = 0; k < total; k++) {
        self.pointPairs[k].pathColor = [NSColor colorWithDeviceHue:k / (double)total
                                                        saturation:1.0
                                                        brightness:1.0
                                                             alpha:1.0];
    }

    self.filter.pairsResultsArray = self.pointPairs;
}

// ---------------------------------------------------------------------------
#pragma mark - Processing
// ---------------------------------------------------------------------------

- (void)surfaceRendered:(NSNotification *)note {
    [self beginProcessing];
}

- (void)beginProcessing {
    [self buildPointPairsArray];

    self.reprocessButton.enabled = NO;
    self.progressIndicator.hidden = NO;
    [self.progressIndicator startAnimation:nil];

    [self.processor processAllPathsWithCompletion:^{
        self.progressIndicator.hidden = YES;
        [self.progressIndicator stopAnimation:nil];
        self.reprocessButton.enabled = YES;
        [[NSNotificationCenter defaultCenter] postNotificationName:SL3DFinishedProcessingNotification object:nil];
    }];
}

- (IBAction)doReprocess:(id)sender {
    [self.processor removeAllPaths];
    for (PointPair *pp in self.filter.pairsResultsArray) pp.state = PointPairStateNone;
    [self.tableView reloadData];
    [self beginProcessing];
}

- (IBAction)closeWindow:(id)sender {
    [self.window performClose:nil];
}

// ---------------------------------------------------------------------------
#pragma mark - Table update
// ---------------------------------------------------------------------------

- (void)updateResultsColumn {
    NSInteger col = [self.tableView columnWithIdentifier:@"surface"];
    if (col >= 0) {
        [self.tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.pointPairs.count)]
                                  columnIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)col]];
    }
}

// ---------------------------------------------------------------------------
#pragma mark - NSTableViewDataSource
// ---------------------------------------------------------------------------

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv {
    return (NSInteger)self.pointPairs.count;
}

- (nullable id)tableView:(NSTableView *)tv
objectValueForTableColumn:(nullable NSTableColumn *)col
                     row:(NSInteger)row {
    PointPair *pp = self.pointPairs[row];
    NSString *ident = col.identifier;

    if ([ident isEqualToString:@"pairs"]) {
        return [NSString stringWithFormat:@"%@ → %@", pp.p1Name, pp.p2Name];
    }
    if ([ident isEqualToString:@"direct"]) {
        return [NSString stringWithFormat:@"%.1f", pp.distanceDirect];
    }
    if ([ident isEqualToString:@"surface"]) {
        switch (pp.state) {
            case PointPairStateCalculated:  return [NSString stringWithFormat:@"%.1f", pp.distanceSurface];
            case PointPairStateCalculating: return NSLocalizedString(@"Calculating…", nil);
            default:                        return @"—";
        }
    }
    if ([ident isEqualToString:@"display"]) {
        return @(pp.displayPath);
    }
    return nil;
}

- (void)tableView:(NSTableView *)tv
   setObjectValue:(nullable id)obj
   forTableColumn:(nullable NSTableColumn *)col
              row:(NSInteger)row {
    if (![col.identifier isEqualToString:@"display"]) return;

    PointPair *pp = self.pointPairs[row];
    pp.displayPath = [obj boolValue];
    if (pp.displayPath) [self.processor displayPathAtIndex:row];
    else                [self.processor removePathAtIndex:row];
}

// ---------------------------------------------------------------------------
#pragma mark - NSTableViewDelegate — color swatch in Display cell
// ---------------------------------------------------------------------------

- (void)tableView:(NSTableView *)tv
  willDisplayCell:(id)cell
   forTableColumn:(nullable NSTableColumn *)col
              row:(NSInteger)row {
    if ([col.identifier isEqualToString:@"display"]) {
        NSButtonCell *btn = (NSButtonCell *)cell;
        btn.backgroundColor = self.pointPairs[row].pathColor;
    }
}

@end
