//
//  SurfaceLength3DFilter.h
//  SurfaceLength3D
//
//  Copyright (c) 2008 TriX Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PluginFilter.h"

@class WizardWindowController, ProcessWindowController, ReportWindowController;


// main Osirix plugin class
@interface SurfaceLength3DFilter : PluginFilter {

	WizardWindowController		*wizardWindowController;
	ProcessWindowController		*processWindowController;
	ReportWindowController		*reportWindowController;
	
	NSMutableArray		*pairsResultsArray;		// array of PointPairObjects
	
	BOOL				surfaceRendered;		// flag to indicate if the 3d surface has been rendered
	
	NSBundle			*pluginBundle;
}

@property (nonatomic, retain) NSMutableArray		*pairsResultsArray;

- (long) filterImage:(NSString*) menuName;

-(void)displayVOICutterWindow;
-(void)displayProcessWindow;
-(void)displayWizardWindow;
-(void)displayResultsWindow;
-(void)displaySurfaceRender;

-(BOOL)surfaceRendered;

-(NSString*)localizedString:(NSString*)key;

@end
