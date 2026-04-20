// WizardWindowController.m — programmatic UI (no XIB)

#import "WizardWindowController.h"
#import "SurfaceLength3DFilter.h"
#import <Horos/ViewerController.h>
#import "Constants.h"

static const NSInteger kTotalSteps = 3;

static NSString *const kStepTitles[] = {
    @"", @"Step 1: Place Points", @"Step 2: Process", @"Step 3: Report"
};
static NSString *const kStepDescs[] = {
    @"",
    @"Open the MPR viewer and place at least two ROI points on the anatomy of interest.",
    @"Wait for the 3D surface rendering, then start the geodesic calculation.",
    @"View the radial chart of surface distances between the points."
};

@interface WizardWindowController ()
@property (nonatomic, weak) ViewerController      *viewerController;
@property (nonatomic, weak) SurfaceLength3DFilter *filter;
@property (nonatomic, assign) NSInteger stepNum;
@property (nonatomic, assign) BOOL haveProcessed;

@property (nonatomic, strong) NSTextField *stepTitleField;
@property (nonatomic, strong) NSTextField *stepDescField;
@property (nonatomic, strong) NSTextField *stepNumField;
@property (nonatomic, strong) NSTextField *versionField;
@property (nonatomic, strong) NSButton    *backButton;
@property (nonatomic, strong) NSButton    *skipButton;
@property (nonatomic, strong) NSButton    *performButton;
@end

@implementation WizardWindowController

- (instancetype)initWithViewer:(ViewerController *)viewer
                  pluginFilter:(SurfaceLength3DFilter *)filter {
    NSWindow *win = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 440, 240)
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                    backing:NSBackingStoreBuffered
                      defer:NO];
    win.title = @"Surface Length 3D";
    win.releasedWhenClosed = NO;
    self = [super initWithWindow:win];
    if (self) {
        _viewerController = viewer;
        _filter           = filter;
        _stepNum          = 1;
        _haveProcessed    = NO;
        [self buildUI];
        [self updateWizardForStep:_stepNum];
        [win center];
    }
    return self;
}

- (void)buildUI {
    NSView *content = self.window.contentView;

    // Version label (top-right)
    NSBundle *bundle = [NSBundle bundleForClass:self.class];
    NSString *ver = bundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"";
    _versionField = [NSTextField labelWithString:[NSString stringWithFormat:@"v%@", ver]];
    _versionField.font = [NSFont systemFontOfSize:10];
    _versionField.textColor = [NSColor secondaryLabelColor];
    _versionField.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:_versionField];

    // Step number
    _stepNumField = [NSTextField labelWithString:@"Step 1 of 3"];
    _stepNumField.font = [NSFont boldSystemFontOfSize:11];
    _stepNumField.textColor = [NSColor secondaryLabelColor];
    _stepNumField.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:_stepNumField];

    // Step title
    _stepTitleField = [NSTextField labelWithString:@""];
    _stepTitleField.font = [NSFont boldSystemFontOfSize:15];
    _stepTitleField.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:_stepTitleField];

    // Step description
    _stepDescField = [NSTextField wrappingLabelWithString:@""];
    _stepDescField.font = [NSFont systemFontOfSize:13];
    _stepDescField.textColor = [NSColor labelColor];
    _stepDescField.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:_stepDescField];

    // Buttons
    _backButton    = [NSButton buttonWithTitle:@"◀ Back"      target:self action:@selector(backFromCurrentStep:)];
    _skipButton    = [NSButton buttonWithTitle:@"Skip ▶"      target:self action:@selector(skipCurrentStep:)];
    _performButton = [NSButton buttonWithTitle:@"Execute Step" target:self action:@selector(performCurrentStep:)];
    _performButton.bezelStyle = NSBezelStyleRounded;
    _performButton.keyEquivalent = @"\r";

    for (NSButton *b in @[_backButton, _skipButton, _performButton])
        b.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:_backButton];
    [content addSubview:_skipButton];
    [content addSubview:_performButton];

    NSDictionary *v = NSDictionaryOfVariableBindings(_versionField, _stepNumField,
                      _stepTitleField, _stepDescField, _backButton, _skipButton, _performButton);
    NSArray *h = @[
        @"H:|-16-[_stepNumField]-(>=8)-[_versionField]-16-|",
        @"H:|-16-[_stepTitleField]-16-|",
        @"H:|-16-[_stepDescField]-16-|",
        @"H:|-16-[_backButton]-8-[_skipButton]-(>=8)-[_performButton]-16-|",
    ];
    NSArray *vt = @[
        @"V:|-16-[_stepNumField]-4-[_stepTitleField]-8-[_stepDescField(>=60)]-16-[_performButton]-16-|",
    ];
    for (NSString *fmt in h)
        [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:fmt options:0 metrics:nil views:v]];
    for (NSString *fmt in vt)
        [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:fmt options:0 metrics:nil views:v]];
    // Align back/skip/perform vertically with perform button
    [content addConstraint:[NSLayoutConstraint constraintWithItem:_backButton attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_performButton attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
    [content addConstraint:[NSLayoutConstraint constraintWithItem:_skipButton attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_performButton attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
    [content addConstraint:[NSLayoutConstraint constraintWithItem:_versionField attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_stepNumField attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(finishedProcessing:)
                                                 name:SL3DFinishedProcessingNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)updateWizardForStep:(NSInteger)step {
    _stepNumField.stringValue  = [NSString stringWithFormat:@"Step %ld of %ld", (long)step, (long)kTotalSteps];
    _stepTitleField.stringValue = kStepTitles[step];
    _stepDescField.stringValue  = kStepDescs[step];
    _backButton.enabled         = (step > 1);
    _skipButton.hidden          = !(step < kTotalSteps || _haveProcessed);
    _performButton.enabled      = YES;
}

- (IBAction)performCurrentStep:(id)sender {
    switch (self.stepNum) {
        case 1: [self performPlacePoints]; break;
        case 2: [self performProcess];     break;
        case 3: [self performReport];      break;
    }
}

- (IBAction)skipCurrentStep:(id)sender {
    if (self.stepNum < kTotalSteps) { self.stepNum++; [self updateWizardForStep:self.stepNum]; }
}

- (IBAction)backFromCurrentStep:(id)sender {
    if (self.stepNum > 1) { self.stepNum--; [self updateWizardForStep:self.stepNum]; }
}

- (void)performPlacePoints {
    [self.viewerController orthogonalMPRViewer:nil];
    self.stepNum = 2;
    [self updateWizardForStep:self.stepNum];
}

- (void)performProcess {
    NSMutableArray *pts = [self.viewerController point2DList];
    if (pts.count < 2) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText     = @"Insufficient Points";
        alert.informativeText = @"Place at least two ROI points in the MPR viewer before processing.";
        alert.alertStyle      = NSAlertStyleWarning;
        [alert beginSheetModalForWindow:self.window completionHandler:nil];
        return;
    }
    [self.filter displaySurfaceRender];
    [self.filter displayProcessWindow];
}

- (void)performReport {
    [self.filter displayResultsWindow];
}

- (void)finishedProcessing:(NSNotification *)note {
    self.haveProcessed = YES;
    self.stepNum = 3;
    [self updateWizardForStep:self.stepNum];
    [self.filter displayResultsWindow];
}

@end
