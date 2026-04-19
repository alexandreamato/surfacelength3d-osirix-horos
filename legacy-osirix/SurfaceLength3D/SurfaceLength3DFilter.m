//
//  SurfaceLength3DFilter.m
//  SurfaceLength3D
//
//  Copyright (c) 2008 TriX Software. All rights reserved.
//

#import "SurfaceLength3DFilter.h"
#import "DebugUtils.h"
#import "dicomFile.h"
#import "WizardWindowController.h"
#import "ProcessWindowController.h"
#import "ReportWindowController.h"
#import "Constants.h"


@implementation SurfaceLength3DFilter

@synthesize pairsResultsArray;


- (void)initPlugin
{
}


// entry method for OsiriX plugins
- (long) filterImage:(NSString*) menuName
{
	DebugNSLog(@"SurfaceLength3DFilter - start");
	
	pluginBundle = [[NSBundle bundleForClass:[self class]] retain];

	surfaceRendered = NO;
	
	[viewerController checkEverythingLoaded];
	[viewerController computeInterval];

	DebugNSLog(@"SurfaceLength3DFilter - checked");
	
	// observe when 3d surface has been rendered so we can set flag
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(surfaceRendered:) name:@"SurfaceRendered" object:nil];
	
	// display wizard window	
	[self displayWizardWindow];
	
	DebugNSLog(@"SurfaceLength3DFilter - displayed wizard window ");

	return 0;
}


// received notification that surface has been rendered
-(void)surfaceRendered:(NSNotification*)aNotification
{
	surfaceRendered = TRUE;
}

-(BOOL)surfaceRendered
{
	return surfaceRendered;
}


//--------------------------------------------------------------------------------------
// Display VOI Cutter window
// this is done using an Applescript application to select the correct menu items 
// Plugins -> CM.... -> VOI Cutter
// this launches as another task 
//
// I could have just incorporated the code from the plugin since it is downloadable in source form
// but I wasn't sure if that was the right thing to do from a licensing point of view
//
//--------------------------------------------------------------------------------------

-(void)displayVOICutterWindow
{
	[[viewerController window] makeKeyAndOrderFront:nil];

	NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
	
	NSString *appPath = [[thisBundle resourcePath] stringByAppendingPathComponent:@"OsirixLaunchVOICutterPlugin.app"];
	
	NSTask *aTask = [[NSTask alloc] init];
    [aTask setLaunchPath:[appPath stringByAppendingPathComponent:@"Contents/MacOS/applet"]];
    [aTask setArguments:[NSArray array]];
    [aTask launch];
}


//--------------------------------------------------------------------------------------
// Display Wizard window
// Display window by initialising window controller and showing the window
//--------------------------------------------------------------------------------------
-(void)displayWizardWindow
{
	if (!wizardWindowController) {
		wizardWindowController = [[WizardWindowController alloc] initWithViewer:viewerController SurfaceLength3DFilter:self];
	}
	
	// put in level above normal windows so it is always above OsiriX
	[[wizardWindowController window] setLevel:NSFloatingWindowLevel];
	[[wizardWindowController window] makeKeyAndOrderFront:nil];
}


//--------------------------------------------------------------------------------------
// Display Process window
// Display window by initialising window controller and showing the window
//--------------------------------------------------------------------------------------
-(void)displayProcessWindow
{
	if (!processWindowController) {
		processWindowController = [[ProcessWindowController alloc] initWithViewer:viewerController SurfaceLength3DFilter:self];
	}
	
	// reset Processor object in case we have already been through here before and we need to 
	[processWindowController renewProcessingTable];
	
	[[processWindowController window] setLevel:NSFloatingWindowLevel];
	[[processWindowController window] makeKeyAndOrderFront:nil];
}

 

//--------------------------------------------------------------------------------------
// Display Surface window
// Display window by calling SRViewer from OsiriX's viewController
//--------------------------------------------------------------------------------------
-(void)displaySurfaceRender
{
	[viewerController SRViewer:nil];
}


//--------------------------------------------------------------------------------------
// Display Results window
// Display window by initialising window controller and showing the window
//--------------------------------------------------------------------------------------

-(void)displayResultsWindow
{
	if (!reportWindowController) {
		reportWindowController = [[ReportWindowController alloc] initWithViewer:viewerController SurfaceLength3DFilter:self];
	}
	
	[reportWindowController updateSegmentedControl];
	[[reportWindowController window] setLevel:NSFloatingWindowLevel];
	[[reportWindowController window] makeKeyAndOrderFront:nil];
}


-(NSString*)localizedString:(NSString*)key
{
	return NSLocalizedStringFromTableInBundle(key, nil, pluginBundle, @"");
}


@end
