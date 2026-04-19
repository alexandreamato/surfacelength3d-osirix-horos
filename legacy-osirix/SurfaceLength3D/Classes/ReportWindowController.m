//
//  ReportWindowController.m
//  SurfaceLength3D
//
//  Created by Gary Fielke on 20/08/08.
//  Copyright 2008 TriX Software. All rights reserved.
//

#import "ReportWindowController.h"
#import "ReportView.h"
#import "SurfaceLength3DFilter.h"
#import "ViewerController.h"
#import "ROI.h"
#import "PointPairObject.h"

@interface ReportWindowController (PrivateMethods) 
-(int)calcMainCentrePoint;
-(double)getMaxDistance;
@end
	
@implementation ReportWindowController

-(id)initWithViewer:(ViewerController*)viewer SurfaceLength3DFilter:(SurfaceLength3DFilter*)cosFilter
{
	viewerController = viewer;
	filter = cosFilter;
	
	if (self = [super initWithWindowNibName:@"Report" owner:self]) {
		
		[[self window] setWindowController:self];
		[[self window] setDelegate:self];
		[[self window] setShowsResizeIndicator:YES];
				
		// determine centre with closest points
		mainCentrePointIndex = [self calcMainCentrePoint];
		maxDistance = [self getMaxDistance];
	}
	return self;
}


// setup segmented control with point names
-(void)updateSegmentedControl
{
	// num points
	NSArray *ptsArray = [viewerController point2DList];
	int numPts = [ptsArray count];
	
	[centrePointControl setSegmentCount:numPts+1];

	int i;
	for (i=0; i<numPts; i++) {
	
		ROI *pt = [ptsArray objectAtIndex:i];
		[centrePointControl setLabel:[pt name] forSegment:i+1];
	}

	[centrePointControl setLabel:[filter localizedString:@"All"] forSegment:0];

	[reportView setNeedsDisplay:YES];
}




-(IBAction)closeReport:(id)sender
{
	[[self window] performClose:nil];
}


// redraw report view if we selected a different point on the segmented control to be the centre point
-(IBAction)changeCentrePoint:(id)sender
{
	[reportView setNeedsDisplay:YES];
}


-(NSString*)nameOfSelectedCentrePoint
{
	return [centrePointControl labelForSegment:[centrePointControl selectedSegment]];
}

-(ViewerController *)viewerController
{
	return viewerController;
}

-(SurfaceLength3DFilter	*)filter
{
	return filter;
}



-(int)calcMainCentrePoint
{
	// loop through each point
	// for each point calc total distance between it and all other points
	// point with minimum total distance to other points is the mainCentrePoint
	
	NSArray *results = filter.pairsResultsArray;
	
	int totalNumPoints = [[viewerController point2DList] count];
	int pt;
	int minDistancePtIndex=0;
	double minTotalDistance = 1E6;
	double totalDistance = 0;
	
	for (pt=0; pt<totalNumPoints; pt++) {
		
		totalDistance = 0;
		
		for (PointPairObject *pp in results) {

			if ((pp.p1ROIIndex == pt) || (pp.p2ROIIndex == pt)) {
				totalDistance += pp.distanceSurface;
			}
		}
		
		if (totalDistance < minTotalDistance) {
			minTotalDistance = totalDistance;
			minDistancePtIndex = pt;
		}
	}

	return minDistancePtIndex;
}


-(int)mainCentrePointIndex
{
	return mainCentrePointIndex;
}


-(double)getMaxDistance
{
	double max = 0;
	for (PointPairObject *pp in filter.pairsResultsArray) {
		if (pp.distanceSurface > max) max = pp.distanceSurface;
	}
	return max;
}

-(double)maxDistance
{
	return maxDistance;
}

@end
