//
//  WizardWindowController.m
//  SurfaceLength3D
//
//  Created by Gary Fielke on 20/08/08.
//  Copyright 2008 TriX Software. All rights reserved.
//

#import "WizardWindowController.h"
#import "SurfaceLength3DFilter.h"
#import "ViewerController.h"

@implementation WizardWindowController

//--------------------------------------------------------------------------------------
// Initialise Wizard window controller
// save references to viewerController and main plugin object (SurfaceLength3DFilter)
//--------------------------------------------------------------------------------------

-(id)initWithViewer:(ViewerController*)viewer SurfaceLength3DFilter:(SurfaceLength3DFilter*)cosFilter
{
	viewerController = viewer;
	filter = cosFilter;
	
	if (self = [super initWithWindowNibName:@"SurfaceLength3DWizard" owner:self]) {
		
		[[self window] setWindowController:self];
		[[self window] setDelegate:self];
		[[self window] setShowsResizeIndicator:YES];

		pluginBundle = [[NSBundle bundleForClass:[self class]] retain];
		
		NSString *versionString = [[pluginBundle infoDictionary] objectForKey:@"CFBundleVersion"];		
		[versionField setStringValue:[NSString stringWithFormat:@"%@ %@",[filter localizedString:@"Version"],versionString]];

		stepNum = 1;
		[self updateWizardForStepNumber:stepNum];
		haveProcessed = NO;

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(finishedProcessing:) name:@"FinishedProcessing" object:nil];
	}
	return self;
}


//- (void)windowWillClose:(NSNotification *)notification
//{
//	NSLog(@"Window will close.... and release his memory...");
//	
//	[self release];
//}

- (void) dealloc
{
	[pluginBundle release];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[super dealloc];
}


//--------------------------------------------------------------------------------------
// Button action method to perform VOI Cutter
//--------------------------------------------------------------------------------------
-(IBAction)performVOICutter:(id)sender
{
	[filter displayVOICutterWindow];
	
	[performPlacePointsButton setEnabled:TRUE];
	[skipPlacePointsButton setEnabled:TRUE];
}


//--------------------------------------------------------------------------------------
// Button action method to place points
//--------------------------------------------------------------------------------------
-(IBAction)performPlacePoints:(id)sender
{
	[viewerController orthogonalMPRViewer:nil];
	[performProcessButton setEnabled:TRUE];
}

//--------------------------------------------------------------------------------------
// Button action method to generate paths between points and display
// check if we have at least one pair of points - if not display alert
//--------------------------------------------------------------------------------------
-(IBAction)performProcess:(id)sender
{
	NSMutableArray *pts = [viewerController point2DList];

	if ([pts count] < 2) {
			
		NSAlert *alert = [[NSAlert alloc] init];
		[alert addButtonWithTitle:@"OK"];
		[alert setMessageText:[filter localizedString:@"Not enough points placed."]];
		[alert setInformativeText:[filter localizedString:@"At least two points need to be placed before processing can occur."]];
		[alert setAlertStyle:NSWarningAlertStyle];
		[alert runModal];
		[alert release];

	}
	else {
		
		[filter displaySurfaceRender];
	
		[filter displayProcessWindow];
	}
}


//--------------------------------------------------------------------------------------
// Button action method to do report
//--------------------------------------------------------------------------------------
-(IBAction)performReport:(id)sender
{
	[filter displayResultsWindow];
}


-(IBAction)skipVOICutter:(id)sender
{
	[performPlacePointsButton setEnabled:TRUE];
	[skipPlacePointsButton setEnabled:TRUE];
}

-(IBAction)skipPlacePoints:(id)sender
{
	[performProcessButton setEnabled:TRUE];
}



-(void)finishedVOICutter
{
	[self skipVOICutter:nil];
}

-(void)finishedPlacePoints
{
	[self skipPlacePoints:nil];
}

-(void)finishedProcessing:(NSNotification*)aNotification
{
	haveProcessed = YES;
	[performReportButton setEnabled:TRUE];
	stepNum++;
	[self updateWizardForStepNumber:stepNum];
	
	// automatically bring up result window when processing finished
	[filter displayResultsWindow];
}


-(IBAction)displayAboutWindow:(id)sender
{
	[aboutPanel orderFront:sender];
}



-(IBAction)performCurrentStep:(id)sender
{
	switch (stepNum) {
		case 1: [self performVOICutter:nil]; break;
		case 2: [self performPlacePoints:nil]; break;
		case 3: [self performProcess:nil]; break;
		case 4: [self performReport:nil]; break;
	}
}


-(IBAction)skipCurrentStep:(id)sender
{
	stepNum++;
	[self updateWizardForStepNumber:stepNum];
}

-(IBAction)backFromCurrentStep:(id)sender
{
	stepNum--;
	[self updateWizardForStepNumber:stepNum];
}


-(void)updateWizardForStepNumber:(int)step
{
	[stepNumField setStringValue:[NSString stringWithFormat:@"%d",step]];
		
	if (step == 1) {
		[stepTitleField setStringValue:NSLocalizedStringFromTableInBundle(@"Step1Title", nil, pluginBundle, @"")];
		[stepDescriptionField setStringValue:NSLocalizedStringFromTableInBundle(@"Step1Description", nil, pluginBundle, @"")];
		[backButton setEnabled:NO];
		[skipButton setHidden:NO];
	}
	else if (step == 2) {
		[stepTitleField setStringValue:NSLocalizedStringFromTableInBundle(@"Step2Title", nil, pluginBundle, @"")];
		[stepDescriptionField setStringValue:NSLocalizedStringFromTableInBundle(@"Step2Description", nil, pluginBundle, @"")];
		[backButton setEnabled:YES];
		[skipButton setHidden:NO];
	}
	else if (step == 3) {
		[stepTitleField setStringValue:NSLocalizedStringFromTableInBundle(@"Step3Title", nil, pluginBundle, @"")];
		[stepDescriptionField setStringValue:NSLocalizedStringFromTableInBundle(@"Step3Description", nil, pluginBundle, @"")];
		[skipButton setHidden:!haveProcessed];
	}
	else if (step == 4) {
		[stepTitleField setStringValue:NSLocalizedStringFromTableInBundle(@"Step4Title", nil, pluginBundle, @"")];
		[stepDescriptionField setStringValue:NSLocalizedStringFromTableInBundle(@"Step3Description", nil, pluginBundle, @"")];
		[skipButton setHidden:YES];
	}	
}


@end
