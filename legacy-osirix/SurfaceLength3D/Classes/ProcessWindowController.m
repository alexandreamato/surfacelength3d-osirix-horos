//
//  ProcessWindowController.m
//  SurfaceLength3D
//
//  Created by Gary Fielke on 20/08/08.
//  Copyright 2008 TriX Software. All rights reserved.
//

#import "ProcessWindowController.h"
#import "SurfaceLength3DFilter.h"
#import "ViewerController.h"
#import "Processor.h"
#import "PointPairObject.h"
#import "ReportWindowController.h"
#import "Constants.h"

@interface ProcessWindowController (PrivateMethods)
-(void)createPointsArray;
-(void)beginProcessing;
@end

@implementation ProcessWindowController

@synthesize pointPairsArray;


-(id)initWithViewer:(ViewerController*)viewer SurfaceLength3DFilter:(SurfaceLength3DFilter*)cosFilter
{
	viewerController = viewer;
	filter = cosFilter;
	
	if (self = [super initWithWindowNibName:@"Process" owner:self]) {
		
		[[self window] setWindowController:self];
		[[self window] setDelegate:self];
		[[self window] setShowsResizeIndicator:YES];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(surfaceRendered:) name:@"SurfaceRendered" object:nil];
	}
	return self;
}


-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[pointPairsArray release];
	[super dealloc];
}


- (void)windowDidLoad
{
	NSMutableArray *pp = [[NSMutableArray alloc] init];
	self.pointPairsArray = pp;
	[pp release];
	
	[[[tableView tableColumnWithIdentifier:@"Point Pairs"] headerCell] setStringValue:[filter localizedString:@"Point Pairs"]];
	[[[tableView tableColumnWithIdentifier:@"Distance Direct"] headerCell] setStringValue:[filter localizedString:@"Distance Direct (mm)"]];
	[[[tableView tableColumnWithIdentifier:@"Distance Surface"] headerCell] setStringValue:[filter localizedString:@"Distance Surface (mm)"]];
	[[[tableView tableColumnWithIdentifier:@"Display"] headerCell] setStringValue:[filter localizedString:@"Display"]];
}


-(void)renewProcessingTable
{
	if (processor) [processor release];
	
	processor = [[Processor alloc] init];
	[processor setViewerController:viewerController controller:self filter:filter];
	
	[self createPointsArray];
	[tableView reloadData];

}



//--------------------------------------------------------------------------------------
// Have received the notification that the rendered surface now exists
// so go ahead and process points
//--------------------------------------------------------------------------------------
-(void)surfaceRendered:(NSNotification*)aNotification
{
	[self beginProcessing];
	[reprocessButton setEnabled:TRUE];
}


//--------------------------------------------------------------------------------------
// create array of PointPairObjects - one object for each pair of points
// assign created array to filter.pairsResultsArray
//--------------------------------------------------------------------------------------
-(void)createPointsArray
{	
	NSMutableArray *pts = [viewerController point2DList];
	float location1[3], location2[3];
	double sliceLocation1, sliceLocation2;
	double directDistanceSlice;			
	// determine line between all combinations of points
	// ie for 5 points 0-1, 0-2, 0-3, 0-4, 1-2, 1-3, 1-4, 2-3, 2-4, 3-4
	
	NSUInteger pt1, pt2;
	int startPt2=1;

	[pointPairsArray removeAllObjects];
	
	// pt1 from 0 to 4
	for (pt1=0; pt1<[pts count]; pt1++) {
		
		for (pt2 = startPt2; pt2<[pts count]; pt2++) {
			
			// get ROI for each point used as one of the current pair
			ROI *ptA = (ROI*)[pts objectAtIndex:pt1];
			DCMPix *curDCM1 = [ptA pix];
			
			ROI *ptB = (ROI*)[pts objectAtIndex:pt2];
			DCMPix *curDCM2 = [ptB pix];
			
			// convert point coords
			sliceLocation1 = [curDCM1 sliceLocation];
			[curDCM1 convertPixX: [[[ptA points] objectAtIndex:0] x] pixY: [[[ptA points] objectAtIndex:0] y] toDICOMCoords: location1];
			
			sliceLocation2 = [curDCM2 sliceLocation];
			[curDCM2 convertPixX: [[[ptB points] objectAtIndex:0] x] pixY: [[[ptB points] objectAtIndex:0] y] toDICOMCoords: location2];
			
			// calc direct distance between pairs
			directDistanceSlice = sqrt((location2[0]-location1[0])*(location2[0]-location1[0]) + 
									   (location2[1]-location1[1])*(location2[1]-location1[1]) +
									   (location2[2]-location1[2])*(location2[2]-location1[2]));
			
			// create new PointPairObject
			PointPairObject *ppObject = [[PointPairObject alloc] init];
			ppObject.p1Name = [ptA name];
			ppObject.p2Name = [ptB name];
			ppObject.p1ROIIndex = pt1;
			ppObject.p2ROIIndex = pt2;
			ppObject.state = kPairStateNone;
			ppObject.displayPath = YES;
			ppObject.distanceDirect = directDistanceSlice;
			ppObject.distanceSurface = 0.0;
			ppObject.clockwise = 0;
			[pointPairsArray addObject:ppObject];
			[ppObject release];
		}
		startPt2++;
	}
	
	// created array now assign to filter.pairsResultsArray
	filter.pairsResultsArray = pointPairsArray;
	
	
	// set path color for each pair
	NSInteger countPairs = [filter.pairsResultsArray count];
	NSInteger i;
	for (i=0; i<countPairs; i++) {
		PointPairObject *pp = [filter.pairsResultsArray objectAtIndex:i];
		NSColor *ppColor = [NSColor colorWithDeviceHue:i/(double)countPairs saturation:1.0 brightness:1.0 alpha:1.0];
		pp.pathColor = ppColor;
	}
}

//--------------------------------------------------------------------------------------
// do the processing
//--------------------------------------------------------------------------------------
-(void)beginProcessing
{
	[self createPointsArray];
	
	// create processor object
	if (!processor) {
		processor = [[Processor alloc] init];
		[processor setViewerController:viewerController controller:self filter:filter];
	}
	
	[processor processAllPaths];
	
	// post notification when processing done
	[[NSNotificationCenter defaultCenter] postNotificationName:@"FinishedProcessing" object:nil];
}



//--------------------------------------------------------------------------------------
// update results column of table as we are processing paths
//--------------------------------------------------------------------------------------
-(void)updateResultsColumn
{	
	NSRect columnRect = [tableView rectOfColumn:[tableView columnWithIdentifier:@"Distance Surface"]];
	
	[tableView displayRect:columnRect];	
}

-(IBAction)doProcess:(id)sender;
{
	[reprocessButton setEnabled:FALSE];

	// remove paths if they have been plotted previously
	[processor removeAllPaths];
	
	// clear results and reprocess (first process is automatic)
	for (PointPairObject *pp in filter.pairsResultsArray) {
		pp.state = kPairStateNone;
	}
	[self updateResultsColumn];
	
	[self beginProcessing];	
	
	[reprocessButton setEnabled:TRUE];

}


-(IBAction)closeProcessWindow:(id)sender
{
	[[self window] performClose:nil];
}


//--------------------------------------------------------------------------------------
// NSTableView datasource methods
//--------------------------------------------------------------------------------------

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [pointPairsArray count];
}
	
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	id objValue = nil;
	PointPairObject *pp = (PointPairObject*)[pointPairsArray objectAtIndex:rowIndex];

	if ([[aTableColumn identifier] isEqualToString:@"Point Pairs"]) {
		objValue = [NSString stringWithFormat:@"%@ to %@",pp.p1Name, pp.p2Name];
	}
	else if ([[aTableColumn identifier] isEqualToString:@"Distance Direct"]) {
		objValue = [NSNumber numberWithDouble:pp.distanceDirect];
	}
	else if ([[aTableColumn identifier] isEqualToString:@"Distance Surface"]) {

		if (pp.state == kPairStateCalculatedDistance) objValue = [NSString stringWithFormat:@"%0.1lf",pp.distanceSurface];
		else if (pp.state == kPairStateNone) objValue = @"-";
		else if (pp.state == kPairStateCalculatingDistance) objValue = [filter localizedString:@"Calculating..."];		
	}
	else if ([[aTableColumn identifier] isEqualToString:@"Display"]) {
		objValue = [NSNumber numberWithBool:pp.displayPath];
	}
	
	return objValue;
}



- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if ([[aTableColumn identifier] isEqualToString:@"Display"]) {
			
		PointPairObject *pp = (PointPairObject*)[pointPairsArray objectAtIndex:rowIndex];
		pp.displayPath = [anObject boolValue];
		if (pp.displayPath) [processor displayPathForIndex:rowIndex];
		else [processor removePathForIndex:rowIndex];
	}
}


//--------------------------------------------------------------------------------------
// to display background color in cell containing the checkbox so we know which 
// path on the surface rendering is which
//--------------------------------------------------------------------------------------

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if ([[aTableColumn identifier] isEqualToString:@"Display"]) {
	
		PointPairObject *pp = (PointPairObject*)[pointPairsArray objectAtIndex:rowIndex];

		[aCell setBackgroundColor:pp.pathColor];
	}
}



@end
