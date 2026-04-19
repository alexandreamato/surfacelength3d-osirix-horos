#import "SurfaceLength3DFilter.h"
#import "WizardWindowController.h"
#import "ProcessWindowController.h"
#import "ReportWindowController.h"
#import "Constants.h"

@interface SurfaceLength3DFilter ()

@property (nonatomic, strong) WizardWindowController   *wizardWC;
@property (nonatomic, strong) ProcessWindowController  *processWC;
@property (nonatomic, strong) ReportWindowController   *reportWC;

@end

@implementation SurfaceLength3DFilter

// ---------------------------------------------------------------------------
#pragma mark - Horos plugin lifecycle
// ---------------------------------------------------------------------------

- (void)initPlugin {}

- (long)filterImage:(NSString *)menuName {
    self.pairsResultsArray = [NSMutableArray array];

    [viewerController checkEverythingLoaded];
    [viewerController computeInterval];

    [self displayWizardWindow];
    return 0;
}

// ---------------------------------------------------------------------------
#pragma mark - Window display
// ---------------------------------------------------------------------------

- (void)displayWizardWindow {
    if (!self.wizardWC) {
        self.wizardWC = [[WizardWindowController alloc] initWithViewer:viewerController
                                                          pluginFilter:self];
    }
    self.wizardWC.window.level = NSFloatingWindowLevel;
    [self.wizardWC.window makeKeyAndOrderFront:nil];
}

- (void)displayProcessWindow {
    if (!self.processWC) {
        self.processWC = [[ProcessWindowController alloc] initWithViewer:viewerController
                                                            pluginFilter:self];
    }
    [self.processWC renewProcessingTable];
    self.processWC.window.level = NSFloatingWindowLevel;
    [self.processWC.window makeKeyAndOrderFront:nil];
}

- (void)displaySurfaceRender {
    [viewerController SRViewer:nil];
}

- (void)displayResultsWindow {
    if (!self.reportWC) {
        self.reportWC = [[ReportWindowController alloc] initWithViewer:viewerController
                                                          pluginFilter:self];
    }
    [self.reportWC updateSegmentedControl];
    self.reportWC.window.level = NSFloatingWindowLevel;
    [self.reportWC.window makeKeyAndOrderFront:nil];
}

@end
