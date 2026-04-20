// ProcessWindowController.m — programmatic UI (no XIB)

#import "ProcessWindowController.h"
#import "SurfaceLength3DFilter.h"
#import <Horos/ViewerController.h>
#import "GeodesicProcessor.h"
#import "PointPair.h"
#import <Horos/ROI.h>
#import <Horos/DCMPix.h>
#import "Constants.h"
#import "AnatomicalLabelSet.h"
#import "MeasurementExporter.h"
#import "ValidationPhantom.h"

@interface ProcessWindowController () <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, weak)   ViewerController       *viewerController;
@property (nonatomic, weak)   SurfaceLength3DFilter  *filter;
@property (nonatomic, strong) GeodesicProcessor      *processor;
@property (nonatomic, strong) NSMutableArray<PointPair *> *pointPairs;

@property (nonatomic, strong) NSTableView          *tableView;
@property (nonatomic, strong) NSProgressIndicator  *progressIndicator;
@property (nonatomic, strong) NSButton             *reprocessButton;
@property (nonatomic, strong) NSPopUpButton        *surfacePopUp;
@property (nonatomic, strong) NSPopUpButton        *labelSetPopUp;
@property (nonatomic, strong) NSButton             *exportCSVButton;
@property (nonatomic, strong) NSButton             *validateButton;
@property (nonatomic, strong) NSTimer              *surfaceTimer;
@property (nonatomic, strong) NSSlider             *lineWidthSlider;
@property (nonatomic, strong) NSTextField          *lineWidthValueLabel;

@end

@implementation ProcessWindowController

- (instancetype)initWithViewer:(ViewerController *)viewer
                  pluginFilter:(SurfaceLength3DFilter *)filter {
    NSWindow *win = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 700, 420)
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
                    backing:NSBackingStoreBuffered
                      defer:NO];
    win.title = @"Surface Length 3D — Process";
    win.releasedWhenClosed = NO;
    self = [super initWithWindow:win];
    if (self) {
        _viewerController = viewer;
        _filter           = filter;
        _pointPairs       = [NSMutableArray array];
        _processor        = [[GeodesicProcessor alloc] initWithViewerController:_viewerController
                                                               windowController:self
                                                                   pluginFilter:_filter];
        [self buildUI];
        [self populateLabelSetPopUp];
        [win center];
    }
    return self;
}

- (void)buildUI {
    NSView *content = self.window.contentView;

    // --- Table ---
    NSScrollView *scroll = [[NSScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.hasVerticalScroller = YES;
    scroll.hasHorizontalScroller = NO;
    scroll.borderType = NSBezelBorder;

    _tableView = [[NSTableView alloc] init];
    _tableView.dataSource = self;
    _tableView.delegate   = self;
    _tableView.usesAlternatingRowBackgroundColors = YES;
    _tableView.allowsColumnResizing = YES;

    NSArray *cols = @[
        @{@"id": @"pairs",   @"title": @"Point Pair",   @"width": @200, @"editable": @NO},
        @{@"id": @"direct",  @"title": @"Direct (mm)",  @"width": @90,  @"editable": @NO},
        @{@"id": @"surface", @"title": @"Surface (mm)", @"width": @110, @"editable": @NO},
        @{@"id": @"ratio",   @"title": @"Ratio ×",      @"width": @80,  @"editable": @NO},
        @{@"id": @"display", @"title": @"Show",         @"width": @60,  @"editable": @YES},
    ];
    for (NSDictionary *c in cols) {
        NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:c[@"id"]];
        col.title = c[@"title"];
        col.width = [c[@"width"] doubleValue];
        col.editable = [c[@"editable"] boolValue];
        if ([c[@"id"] isEqualToString:@"display"]) {
            NSButtonCell *cell = [[NSButtonCell alloc] init];
            cell.buttonType = NSButtonTypeSwitch;
            cell.title = @"";
            col.dataCell = cell;
        }
        [_tableView addTableColumn:col];
    }

    scroll.documentView = _tableView;
    [content addSubview:scroll];

    // --- Progress ---
    _progressIndicator = [[NSProgressIndicator alloc] init];
    _progressIndicator.style = NSProgressIndicatorStyleSpinning;
    _progressIndicator.displayedWhenStopped = NO;
    _progressIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:_progressIndicator];

    // --- Surface popup ---
    NSTextField *surfaceLabel = [NSTextField labelWithString:@"Surface:"];
    surfaceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:surfaceLabel];

    _surfacePopUp = [[NSPopUpButton alloc] init];
    _surfacePopUp.translatesAutoresizingMaskIntoConstraints = NO;
    [_surfacePopUp addItemWithTitle:NSLocalizedString(@"Auto (largest)", nil)];
    [_surfacePopUp setTarget:self];
    [_surfacePopUp setAction:@selector(doChangeSurface:)];
    [content addSubview:_surfacePopUp];

    // --- Label set popup ---
    NSTextField *labelSetLabel = [NSTextField labelWithString:@"Context:"];
    labelSetLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:labelSetLabel];

    _labelSetPopUp = [[NSPopUpButton alloc] init];
    _labelSetPopUp.translatesAutoresizingMaskIntoConstraints = NO;
    [_labelSetPopUp setTarget:self];
    [_labelSetPopUp setAction:@selector(doChangeLabelSet:)];
    [content addSubview:_labelSetPopUp];

    // --- Line width ---
    NSTextField *lineWidthLabel = [NSTextField labelWithString:@"Line width:"];
    lineWidthLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:lineWidthLabel];

    _lineWidthSlider = [NSSlider sliderWithValue:3.0 minValue:1.0 maxValue:12.0 target:self action:@selector(doChangeLineWidth:)];
    _lineWidthSlider.translatesAutoresizingMaskIntoConstraints = NO;
    _lineWidthSlider.numberOfTickMarks = 12;
    _lineWidthSlider.allowsTickMarkValuesOnly = NO;
    [content addSubview:_lineWidthSlider];

    _lineWidthValueLabel = [NSTextField labelWithString:@"3.0 pt"];
    _lineWidthValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:_lineWidthValueLabel];

    // --- Buttons ---
    _reprocessButton = [NSButton buttonWithTitle:@"Reprocess" target:self action:@selector(doReprocess:)];
    _reprocessButton.translatesAutoresizingMaskIntoConstraints = NO;

    _exportCSVButton = [NSButton buttonWithTitle:@"Export CSV" target:self action:@selector(doExportCSV:)];
    _exportCSVButton.translatesAutoresizingMaskIntoConstraints = NO;
    _exportCSVButton.enabled = NO;

    _validateButton = [NSButton buttonWithTitle:@"Validate Phantom" target:self action:@selector(doValidatePhantom:)];
    _validateButton.translatesAutoresizingMaskIntoConstraints = NO;

    NSButton *closeButton = [NSButton buttonWithTitle:@"Close" target:self action:@selector(closeWindow:)];
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    closeButton.keyEquivalent = @"\033";

    [content addSubview:_reprocessButton];
    [content addSubview:_exportCSVButton];
    [content addSubview:_validateButton];
    [content addSubview:closeButton];

    // --- Constraints ---
    NSDictionary *v = NSDictionaryOfVariableBindings(scroll, _progressIndicator,
        surfaceLabel, _surfacePopUp, labelSetLabel, _labelSetPopUp,
        lineWidthLabel, _lineWidthSlider, _lineWidthValueLabel,
        _reprocessButton, _exportCSVButton, _validateButton, closeButton);

    NSArray *hFormats = @[
        @"H:|-8-[scroll]-8-|",
        @"H:|-8-[surfaceLabel]-4-[_surfacePopUp(150)]-12-[labelSetLabel]-4-[_labelSetPopUp(150)]-12-[lineWidthLabel]-4-[_lineWidthSlider(120)]-4-[_lineWidthValueLabel(44)]-(>=8)-[_progressIndicator(20)]-8-|",
        @"H:|-8-[_reprocessButton]-8-[_exportCSVButton]-8-[_validateButton]-(>=8)-[closeButton]-8-|",
    ];
    NSArray *vFormats = @[
        @"V:|-8-[scroll]-8-[_surfacePopUp]-8-[_reprocessButton]-8-|",
    ];
    for (NSString *fmt in hFormats)
        [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:fmt options:0 metrics:nil views:v]];
    for (NSString *fmt in vFormats)
        [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:fmt options:0 metrics:nil views:v]];

    // Align controls in toolbar row
    for (NSView *vw in @[surfaceLabel, labelSetLabel, _labelSetPopUp, lineWidthLabel, _lineWidthSlider, _lineWidthValueLabel, _progressIndicator])
        [content addConstraint:[NSLayoutConstraint constraintWithItem:vw attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_surfacePopUp attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
    // Align buttons in bottom row
    for (NSView *vw in @[_exportCSVButton, _validateButton, closeButton])
        [content addConstraint:[NSLayoutConstraint constraintWithItem:vw attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_reprocessButton attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(surfaceRendered:)
                                                 name:SL3DSurfaceRenderedNotification
                                               object:nil];
}

- (void)dealloc {
    [self.surfaceTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// ---------------------------------------------------------------------------
#pragma mark - Setup / refresh
// ---------------------------------------------------------------------------

- (void)renewProcessingTable {
    [self.processor removeAllPaths];
    [self refreshSurfacePopUp];
    [self buildPointPairsArray];
    [self.tableView reloadData];
    [self startSurfacePolling];
}

- (void)startSurfacePolling {
    [self.surfaceTimer invalidate];
    self.surfaceTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                         target:self
                                                       selector:@selector(pollForSurface:)
                                                       userInfo:nil
                                                        repeats:YES];
}

- (void)pollForSurface:(NSTimer *)timer {
    NSArray *surfaces = [self.processor availableSurfaceDescriptions];
    NSLog(@"[SL3D] pollForSurface: found %lu surface(s)", (unsigned long)surfaces.count);
    if (surfaces.count > 0) {
        [timer invalidate];
        self.surfaceTimer = nil;
        [self beginProcessing];
    }
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
    [self.surfacePopUp addItemWithTitle:NSLocalizedString(@"Auto (largest)", nil)];
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
            pp.p1Name        = (i < labelNames.count) ? labelNames[i] : roiA.name;
            pp.p2Name        = (j < labelNames.count) ? labelNames[j] : roiB.name;
            pp.p1ROIIndex    = (NSInteger)i;
            pp.p2ROIIndex    = (NSInteger)j;
            pp.distanceDirect = directDist;
            [self.pointPairs addObject:pp];
        }
    }

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
    [self.surfaceTimer invalidate];
    self.surfaceTimer = nil;

    if (!self.reprocessButton.enabled) return;  // already processing

    [self buildPointPairsArray];

    self.reprocessButton.enabled  = NO;
    self.exportCSVButton.enabled  = NO;
    [self.progressIndicator startAnimation:nil];

    [self.processor processAllPathsWithCompletion:^{
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
    [self.processor setPreferredSurfaceIndex:sel - 1];
}

// ---------------------------------------------------------------------------
#pragma mark - Label set selection
// ---------------------------------------------------------------------------

- (IBAction)doChangeLabelSet:(id)sender {
    [self buildPointPairsArray];
    [self.tableView reloadData];
}

- (IBAction)doChangeLineWidth:(id)sender {
    double width = self.lineWidthSlider.doubleValue;
    self.lineWidthValueLabel.stringValue = [NSString stringWithFormat:@"%.1f pt", width];
    self.processor.pathLineWidth = width;
    [self.processor applyCurrentLineWidthToVisiblePaths];
}

// ---------------------------------------------------------------------------
#pragma mark - CSV Export
// ---------------------------------------------------------------------------

- (IBAction)doExportCSV:(id)sender {
    NSString *patientName = @"";
    DCMPix *pix = self.viewerController.pixList.firstObject;
    if (pix) patientName = pix.generatedName ?: @"";

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
            NSMutableString *msg = [NSMutableString string];
            if (!sphereResult.available || !cylResult.available) {
                [msg appendString:@"Validation phantom is currently unavailable inside the Horos runtime because Horos embeds VTK 8 while this plugin is compiled against VTK 9 headers.\n\n"];
                [msg appendString:@"The production geodesic path pipeline remains active, but analytic phantom verification still needs either a standalone build or a future Horos-safe validation backend.\n\n"];
            }
            [msg appendFormat:@"%@\n\n%@", sphereResult.summary, cylResult.summary];
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText     = NSLocalizedString(@"Geometric Phantom Validation", nil);
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

    if ([ident isEqualToString:@"pairs"])
        return [NSString stringWithFormat:@"%@ → %@", pp.p1Name, pp.p2Name];
    if ([ident isEqualToString:@"direct"])
        return [NSString stringWithFormat:@"%.1f", pp.distanceDirect];
    if ([ident isEqualToString:@"surface"]) {
        switch (pp.state) {
            case PointPairStateCalculated:  return [NSString stringWithFormat:@"%.1f", pp.distanceSurface];
            case PointPairStateCalculating: return NSLocalizedString(@"Computing…", nil);
            default:                        return @"—";
        }
    }
    if ([ident isEqualToString:@"ratio"]) {
        if (pp.state != PointPairStateCalculated) return @"—";
        return [NSString stringWithFormat:@"×%.2f", pp.distanceRatio];
    }
    if ([ident isEqualToString:@"display"])
        return @(pp.displayPath);
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
#pragma mark - NSTableViewDelegate
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
