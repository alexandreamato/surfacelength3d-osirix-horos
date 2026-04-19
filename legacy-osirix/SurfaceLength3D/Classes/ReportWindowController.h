//
//  ReportWindowController.h
//  SurfaceLength3D
//
//  Created by Gary Fielke on 20/08/08.
//  Copyright 2008 TriX Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ViewerController, SurfaceLength3DFilter, ReportView;

@interface ReportWindowController : NSWindowController {

	ViewerController *viewerController;
	SurfaceLength3DFilter	*filter;

	IBOutlet ReportView	*reportView;
	IBOutlet NSMatrix	*centrePointRadioButtons;
	IBOutlet NSSegmentedControl	*centrePointControl;

	int					mainCentrePointIndex;
	double				maxDistance;
}

-(IBAction)closeReport:(id)sender;

-(IBAction)changeCentrePoint:(id)sender;
-(void)updateSegmentedControl;

-(int)mainCentrePointIndex;
-(double)maxDistance;

-(ViewerController *)viewerController;
-(SurfaceLength3DFilter	*)filter;

-(NSString*)nameOfSelectedCentrePoint;

@end
