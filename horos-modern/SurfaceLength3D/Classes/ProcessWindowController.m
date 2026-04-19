// ProcessWindowController.m
//
// XIB: Process.xib
//   Window containing:
//   - NSTableView (tableView) with columns:
//       "pairs"   — NSTextFieldCell  (Point Pairs)
//       "direct"  — NSTextFieldCell  (Direct mm)
//       "surface" — NSTextFieldCell  (Surface mm)
//       "ratio"   — NSTextFieldCell  (Surface/Direct ratio)
//       "display" — NSButtonCell checkBox (Display)
//   - NSProgressIndicator (progressIndicator, style=spinning, hidden initially)
//   - NSButton "Reprocess" (reprocessButton)
//   - NSPopUpButton (surfacePopUp) — selects which VTK surface to measure
//   - NSPopUpButton (labelSetPopUp) — selects anatomical label context
//   - NSButton "Export CSV" (exportCSVButton)
//   - NSButton "Validate Phantom" (validateButton)
//   - NSButton "Close"

#import "ProcessWindowController.h"
#import "SurfaceLength3DFilter.h"
#import <OsiriXAPI/ViewerController.h>
#import "GeodesicProcessor.h"
#import "PointPair.h"
#import <OsiriXAPI/ROI.h>
#import <OsiriXAPI/DCMPix.h>
#import "Constants.h"
#import "AnatomicalLabelSet.h"
#import "MeasurementExporter.h"
#import "ValidationPhantom.h"

@interface ProcessWindowController ()

@property (nonatomic, weak)   ViewerController       *viewerController;
@property (nonatomic, weak)   SurfaceLength3DFilter  *filter;
@property (nonatomic, strong) GeodesicProcessor      *processor;
@property (nonatomic, strong) NSMutableArray<PointPair *> *pointPairs;

@property (nonatomic, weak) IBOutlet NSTableView          *tableView;
@property (nonatomic, weak) IBOutlet NSProgressIndicator  *progressIndicator;
@property (nonatomic, weak) IBOutlet NSButton             *reprocessButton;
@property (nonatomic, weak) IBOutlet NSPopUpButton        *surfacePopUp;
@property (nonatomic, weak) IBOutlet NSPopUpButton        *labelSetPopUp;
@property (nonatomic, weak) IBOutlet NSButton             *exportCSVButton;
@property (nonatomic, weak) IBOutlet NSButton             *validateButton;

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
    [self populateLabelSetPopUp];
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
    [self refreshSurfacePopUp];
    [self buildPointPairsArray];
    [self.tableView reloadData];
}

- (void)populateLabelSetPopUp {
    if (!self.labelSetPopUp) return;
    [self.labelSetPopUp removeAllItems];
    [self.labelSetPopUp addItemsWithTitles:[AnatomicalLabelSet allContextNames]];
}

- (void)refreshSurfacePopUp {
    if (!self.surfacePopUp) return;
    [self.surfacePopUp removeAllItems];
    NSArray<NSDictionary *> *surfaces = [self.processor availableSurfaceDescriptions];
    if (!surfaces.count) {
        [self.surfacePopUp addItemWithTitle:NSLocalizedString(@"Auto (maior)", nil)];
        [self.processor setPreferredSurfaceIndex:-1];
        return;
    }
    [self.surfacePopUp addItemWithTitle:NSLocalizedString(@"Auto (maior)", nil)];
    for (NSDictionary *d in surfaces) {
        [self.surfacePopUp addItemWithTitle:d[@"label"]];
    }
    [self.surfacePopUp selectItemAtIndex:0];
    [self.processor setPreferredSurfaceIndex:-1];
}

- (void)buildPointPairsArray {
    [self.pointPairs removeAllObjects];

    NSMutableArray *pts = [self.viewerController point2DList];
    NSUInteger count = pts.count;

    // Apply anatomical label set if available
    AnatomicalContext ctx = (AnatomicalContext)[self.labelSetPopUp indexOfSelectedItem];
    NSArray<NSString *> *labelNames = [AnatomicalLabelSet pointNamesForContext:ctx];

    for (NSUInteger i = 0; i < count; i++) {
        for (NSUInteger j = i + 1; j < count; j++) {

            ROI    *roiA = pts[i], *roiB = pts[j];
            DCMPix *dcmA = roiA.pix, *dcmB = roiB.pix;

            float loc1[3], loc2[3];
            [dcmA convertPixX:[roiA.points[0] x] pixY:[roiA.points[0] y] toDICOMCoords:loc1];
            [dcmB convertPixX:[roiB.points[0] x] pixY:[roiB.points[0] y] toDICOMCoords:loc2];

            double dx = loc2[0]-loc1[0], dy = loc2[1]-loc1[1], dz = loc2[2]-loc1[2];
            double directDist = sqrt(dx*dx + dy*dy + dz*dz);

            PointPair *pp    = [[PointPair alloc] init];
            // Use anatomical label if available, else ROI name
            pp.p1Name        = (i < labelNames.count) ? labelNames[i] : roiA.name;
            pp.p2Name        = (j < labelNames.count) ? labelNames[j] : roiB.name;
            pp.p1ROIIndex    = (NSInteger)i;
            pp.p2ROIIndex    = (NSInteger)j;
            pp.distanceDirect = directDist;
            [self.pointPairs addObject:pp];
        }
    }

    // Assign distinct HSV colors
    NSInteger total = (NSInteger)self.pointPairs.count;
    for (NSInteger k = 0; k < total; k++) {
        self.pointPairs[k].pathColor = [NSColor colorWithDeviceHue:k / (double)MAX(total, 1)
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

    self.reprocessButton.enabled  = NO;
    self.exportCSVButton.enabled  = NO;
    self.progressIndicator.hidden = NO;
    [self.progressIndicator startAnimation:nil];

    [self.processor processAllPathsWithCompletion:^{
        self.progressIndicator.hidden = YES;
        [self.progressIndicator stopAnimation:nil];
        self.reprocessButton.enabled = YES;
        self.exportCSVButton.enabled = YES;
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
#pragma mark - Surface selection
// ---------------------------------------------------------------------------

- (IBAction)doChangeSurface:(id)sender {
    NSInteger sel = [self.surfacePopUp indexOfSelectedItem];
    // Index 0 = Auto; indices 1+ map to surface 0,1,2...
    [self.processor setPreferredSurfaceIndex:sel - 1];
}

// ---------------------------------------------------------------------------
#pragma mark - Label set selection
// ---------------------------------------------------------------------------

- (IBAction)doChangeLabelSet:(id)sender {
    [self buildPointPairsArray];
    [self.tableView reloadData];
}

// ---------------------------------------------------------------------------
#pragma mark - CSV Export
// ---------------------------------------------------------------------------

- (IBAction)doExportCSV:(id)sender {
    NSString *patientName = @"";
    DCMPix *pix = self.viewerController.pixList.firstObject;
    if (pix) patientName = pix.patientName ?: @"";

    [MeasurementExporter exportToCSV:self.filter.pairsResultsArray
                           patientID:patientName
                    presentingWindow:self.window
                          completion:nil];
}

// ---------------------------------------------------------------------------
#pragma mark - Phantom Validation
// ---------------------------------------------------------------------------

- (IBAction)doValidatePhantom:(id)sender {
    NSButton *btn = (NSButton *)sender;
    btn.enabled = NO;

    [ValidationPhantom validateShape:PhantomShapeSphere
                              radius:50.0
                      meshResolution:64
                          completion:^(ValidationPhantomResult *sphereResult) {

        [ValidationPhantom validateShape:PhantomShapeCylinder
                                  radius:50.0
                          meshResolution:64
                              completion:^(ValidationPhantomResult *cylResult) {

            btn.enabled = YES;

            NSString *msg = [NSString stringWithFormat:@"%@\n\n%@",
                             sphereResult.summary, cylResult.summary];

            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText     = NSLocalizedString(@"Validação de Fantasma Geométrico", nil);
            alert.informativeText = msg;
            [alert addButtonWithTitle:@"OK"];
            [alert runModal];
        }];
    }];
}

// ---------------------------------------------------------------------------
#pragma mark - Table update
// ---------------------------------------------------------------------------

- (void)updateResultsColumn {
    NSInteger surfaceCol = [self.tableView columnWithIdentifier:@"surface"];
    NSInteger ratioCol   = [self.tableView columnWithIdentifier:@"ratio"];
    NSIndexSet *rows     = [NSIndexSet indexSetWithIndexesInRange:
                            NSMakeRange(0, self.pointPairs.count)];
    if (surfaceCol >= 0)
        [self.tableView reloadDataForRowIndexes:rows
                                  columnIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)surfaceCol]];
    if (ratioCol >= 0)
        [self.tableView reloadDataForRowIndexes:rows
                                  columnIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)ratioCol]];
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
            case PointPairStateCalculating: return NSLocalizedString(@"Calculando…", nil);
            default:                        return @"—";
        }
    }
    if ([ident isEqualToString:@"ratio"]) {
        if (pp.state != PointPairStateCalculated) return @"—";
        return [NSString stringWithFormat:@"×%.2f", pp.distanceRatio];
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
