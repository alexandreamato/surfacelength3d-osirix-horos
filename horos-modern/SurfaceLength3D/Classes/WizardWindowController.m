// WizardWindowController.m
//
// XIB: SurfaceLength3DWizard.xib
//   Window with three sections (Step 1-3), each with a title label, description label,
//   and an "Perform" button. A shared Back/Next/Skip row at the bottom.
//   Outlets: stepNumField, stepTitleField, stepDescriptionField,
//            backButton, skipButton, performButton.

#import "WizardWindowController.h"
#import "SurfaceLength3DFilter.h"
#import "ViewerController.h"
#import "Constants.h"

static const NSInteger kTotalSteps = 3;

@interface WizardWindowController ()

@property (nonatomic, weak) ViewerController      *viewerController;
@property (nonatomic, weak) SurfaceLength3DFilter *filter;
@property (nonatomic, assign) NSInteger stepNum;
@property (nonatomic, assign) BOOL haveProcessed;

// XIB outlets
@property (nonatomic, weak) IBOutlet NSTextField       *stepNumField;
@property (nonatomic, weak) IBOutlet NSTextField       *stepTitleField;
@property (nonatomic, weak) IBOutlet NSTextField       *stepDescriptionField;
@property (nonatomic, weak) IBOutlet NSButton          *backButton;
@property (nonatomic, weak) IBOutlet NSButton          *skipButton;
@property (nonatomic, weak) IBOutlet NSButton          *performButton;
@property (nonatomic, weak) IBOutlet NSTextField       *versionField;

@end

@implementation WizardWindowController

- (instancetype)initWithViewer:(ViewerController *)viewer
                  pluginFilter:(SurfaceLength3DFilter *)filter {
    self = [super initWithWindowNibName:@"SurfaceLength3DWizard" owner:self];
    if (self) {
        _viewerController = viewer;
        _filter           = filter;
        _stepNum          = 1;
        _haveProcessed    = NO;
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];

    NSBundle *bundle = [NSBundle bundleForClass:self.class];
    NSString *version = bundle.infoDictionary[@"CFBundleShortVersionString"]
                        ?: bundle.infoDictionary[@"CFBundleVersion"]
                        ?: @"";
    self.versionField.stringValue = [NSString stringWithFormat:@"v%@", version];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(finishedProcessing:)
                                                 name:SL3DFinishedProcessingNotification
                                               object:nil];
    [self updateWizardForStep:self.stepNum];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// ---------------------------------------------------------------------------
#pragma mark - Step logic
// ---------------------------------------------------------------------------

- (void)updateWizardForStep:(NSInteger)step {
    self.stepNumField.stringValue = [NSString stringWithFormat:@"%ld", (long)step];
    self.backButton.enabled  = (step > 1);
    self.skipButton.hidden   = (step == kTotalSteps && !self.haveProcessed);

    NSBundle *bundle = [NSBundle bundleForClass:self.class];
    NSString *titleKey = [NSString stringWithFormat:@"Step%ldTitle", (long)step];
    NSString *descKey  = [NSString stringWithFormat:@"Step%ldDescription", (long)step];

    self.stepTitleField.stringValue       = NSLocalizedStringFromTableInBundle(titleKey, nil, bundle, @"");
    self.stepDescriptionField.stringValue = NSLocalizedStringFromTableInBundle(descKey,  nil, bundle, @"");
    self.performButton.enabled            = YES;
}

- (IBAction)performCurrentStep:(id)sender {
    switch (self.stepNum) {
        case 1: [self performPlacePoints]; break;
        case 2: [self performProcess];     break;
        case 3: [self performReport];      break;
    }
}

- (IBAction)skipCurrentStep:(id)sender {
    if (self.stepNum < kTotalSteps) {
        self.stepNum++;
        [self updateWizardForStep:self.stepNum];
    }
}

- (IBAction)backFromCurrentStep:(id)sender {
    if (self.stepNum > 1) {
        self.stepNum--;
        [self updateWizardForStep:self.stepNum];
    }
}

// ---------------------------------------------------------------------------
#pragma mark - Step actions
// ---------------------------------------------------------------------------

// Step 1 — open MPR viewer so the user can place 2D point ROIs
- (void)performPlacePoints {
    [self.viewerController orthogonalMPRViewer:nil];
    self.stepNum = 2;
    [self updateWizardForStep:self.stepNum];
}

// Step 2 — validate point count, open 3D surface renderer, begin computation
- (void)performProcess {
    NSMutableArray *pts = [self.viewerController point2DList];
    if (pts.count < 2) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText     = NSLocalizedString(@"Not enough points placed.", nil);
        alert.informativeText = NSLocalizedString(@"Place at least two points in the MPR viewer before processing.", nil);
        alert.alertStyle      = NSAlertStyleWarning;
        [alert beginSheetModalForWindow:self.window completionHandler:nil];
        return;
    }

    [self.filter displaySurfaceRender];
    [self.filter displayProcessWindow];
}

// Step 3 — show radial distance report
- (void)performReport {
    [self.filter displayResultsWindow];
}

// ---------------------------------------------------------------------------
#pragma mark - Notifications
// ---------------------------------------------------------------------------

- (void)finishedProcessing:(NSNotification *)note {
    self.haveProcessed = YES;
    self.performButton.enabled = YES;
    self.stepNum = 3;
    [self updateWizardForStep:self.stepNum];
    [self.filter displayResultsWindow];
}

@end
