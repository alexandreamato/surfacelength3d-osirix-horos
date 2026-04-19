//
//  ProcessWindowController.h
//  SurfaceLength3D
//
//  Created by Gary Fielke on 20/08/08.
//  Copyright 2008 TriX Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ViewerController, SurfaceLength3DFilter, Processor, ReportWindowController;

@interface ProcessWindowController : NSWindowController {

	ViewerController		*viewerController;
	SurfaceLength3DFilter			*filter;
	Processor				*processor;
	
	IBOutlet NSTableView	*tableView;
	IBOutlet NSButton		*reprocessButton;

	NSMutableArray			*pointPairsArray;		// array of PointPairObjects
	
	ReportWindowController *reportWindowController;
}

@property (nonatomic, retain) NSMutableArray		*pointPairsArray;

-(id)initWithViewer:(ViewerController*)viewer SurfaceLength3DFilter:(SurfaceLength3DFilter*)cosFilter;

-(void)updateResultsColumn;
-(IBAction)closeProcessWindow:(id)sender;
-(IBAction)doProcess:(id)sender;
-(void)renewProcessingTable;

@end
