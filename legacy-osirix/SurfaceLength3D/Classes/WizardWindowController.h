//
//  WizardWindowController.h
//  SurfaceLength3D
//
//  Created by Gary Fielke on 20/08/08.
//  Copyright 2008 TriX Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ViewerController, SurfaceLength3DFilter;

@interface WizardWindowController : NSWindowController {

	ViewerController *viewerController;
	SurfaceLength3DFilter	*filter;

	NSBundle			*pluginBundle;
	
	IBOutlet NSButton	*performVOICutterButton;
	IBOutlet NSButton	*performPlacePointsButton;
	IBOutlet NSButton	*performProcessButton;
	IBOutlet NSButton	*performReportButton;
	IBOutlet NSButton	*skipVOICutterButton;
	IBOutlet NSButton	*skipPlacePointsButton;
	
	IBOutlet NSTextField *voiCutterField;
	IBOutlet NSTextField *placePointsField;
	IBOutlet NSTextField *processField;
	IBOutlet NSTextField *reportField;
	
	
	// about window
	IBOutlet NSPanel		*aboutPanel;
	IBOutlet NSTextField	*versionField;
	
	IBOutlet NSTextField	*stepNumField;
	IBOutlet NSTextField	*stepTitleField;
	IBOutlet NSTextField	*stepDescriptionField;
	int						stepNum;
	IBOutlet NSButton		*backButton;
	IBOutlet NSButton		*skipButton;
	IBOutlet NSButton		*performButton;
	
	NSTimer					*checkSurfaceTimer;
	
	BOOL					haveProcessed;
}

-(id)initWithViewer:(ViewerController*)viewer SurfaceLength3DFilter:(SurfaceLength3DFilter*)cosFilter;


-(IBAction)performVOICutter:(id)sender;
-(IBAction)performPlacePoints:(id)sender;
-(IBAction)performProcess:(id)sender;
-(IBAction)performReport:(id)sender;

-(IBAction)skipVOICutter:(id)sender;
-(IBAction)skipPlacePoints:(id)sender;

-(IBAction)displayAboutWindow:(id)sender;
-(IBAction)performCurrentStep:(id)sender;
-(IBAction)skipCurrentStep:(id)sender;
-(IBAction)backFromCurrentStep:(id)sender;

-(void)updateWizardForStepNumber:(int)step;


@end
