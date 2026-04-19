//
//  ReportView.m
//  SurfaceLength3D
//
//  Created by Gary Fielke on 20/08/08.
//  Copyright 2008 TriX Software. All rights reserved.
//

#import "ReportView.h"
#import "ReportWindowController.h"
#import "PointPairObject.h"
#import "SurfaceLength3DFilter.h"


float kMillimetresToPixelsScaler = 3.0;

@implementation ReportView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}


//--------------------------------------------------------------------------------------------------------------------
// Draw ReportView
// Based on centre point -- plot all lines from this point to the other points
//	 eg centre point 3:  p3 to p1, p3 to p2, p3 to p4, p3 to p5
//--------------------------------------------------------------------------------------------------------------------

- (void)drawRect:(NSRect)rect {
	
	NSRect bounds = [self bounds];
	
	[[NSColor lightGrayColor] set];
	NSRectFill(bounds);
	
	ReportWindowController* reportWC = (ReportWindowController*)[[self window] windowController];

	// get largest distance and scale kMillimetresToPixelsScaler to fit in all points and enlarge when the view enlarges etc
	double minBoundDimension = MIN(NSWidth(bounds), NSHeight(bounds));
	
	kMillimetresToPixelsScaler = minBoundDimension/(reportWC.maxDistance*2.0);
		
	
	// get results array and centre point name
	NSArray *results = reportWC.filter.pairsResultsArray;
	NSString *centrePointName =[reportWC nameOfSelectedCentrePoint];

	
	NSArray *roiList = [reportWC.viewerController point2DList];

	// centre point of view
	NSPoint centrePoint = NSMakePoint(NSMidX(bounds), NSMidY(bounds));
	float markerWidth = 10;

	
	NSInteger ptIndex = -1;
	NSInteger centrePtIndex = -1;
	BOOL plotAllPaths = NO;
	
	// plot All or centred on one point?
	if ([centrePointName isEqualToString:[reportWC.filter localizedString:@"All"]]) {
		centrePtIndex = reportWC.mainCentrePointIndex;
		plotAllPaths = YES;
		centrePointName = [[roiList objectAtIndex:reportWC.mainCentrePointIndex] name];
	}
	else {
		// get index into the results array
		for (PointPairObject *pp in results) {
			
			if ([pp.p1Name isEqualToString:centrePointName]) centrePtIndex = pp.p1ROIIndex;
			else if ([pp.p2Name isEqualToString:centrePointName]) centrePtIndex = pp.p2ROIIndex;
			if (centrePtIndex >= 0) break;
		}
	}
	
	
	float centreLocation[3];
	ROI *centrePtROI = [roiList objectAtIndex:centrePtIndex];
	DCMPix *centreDCM = [centrePtROI pix];
	
	[centreDCM convertPixX: [[[centrePtROI points] objectAtIndex:0] x] 
					   pixY: [[[centrePtROI points] objectAtIndex:0] y]
						toDICOMCoords: centreLocation];
	
	
	
	// font for text on plot
	NSFont *font = [NSFont fontWithName:@"Times" size:14.0];
	NSFont *smallFont = [NSFont fontWithName:@"Times" size:10.0];
	
	NSMutableDictionary *attrsDictionary =	[NSMutableDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName,
												[NSColor redColor], NSForegroundColorAttributeName, nil];

	
	// only used to draw all paths after drawing from centre point if All selected
	NSMutableArray *ptViewCoords = [NSMutableArray arrayWithCapacity:[roiList count]];
	
	for (NSUInteger i=0; i<[roiList count]; i++) [ptViewCoords addObject:[NSValue valueWithPoint:NSZeroPoint]];
	[ptViewCoords replaceObjectAtIndex:centrePtIndex withObject:[NSValue valueWithPoint:centrePoint]];

	
	// loop over each point pair and draw
	for (PointPairObject *pp in results) {
			
		BOOL clockwiseFromCentrePoint = pp.clockwise;
		ptIndex = -1;
		
		// if one of the points is the centre point then the other point is what we want
		if ([pp.p1Name isEqualToString:centrePointName]) ptIndex = pp.p2ROIIndex;
		else if ([pp.p2Name isEqualToString:centrePointName]) {
			ptIndex = pp.p1ROIIndex;
			clockwiseFromCentrePoint = !pp.clockwise;
		}
				
		if (ptIndex >= 0) {
			
			// draw circles for each point
			float ptLocation[3];			
			
			ROI *ptROI = [roiList objectAtIndex:ptIndex];
			DCMPix *ptDCM = [ptROI pix];
			
			[ptDCM convertPixX: [[[ptROI points] objectAtIndex:0] x] 
							   pixY: [[[ptROI points] objectAtIndex:0] y]
								toDICOMCoords: ptLocation];
			
			// calc angle between two points based on the centreLocation and ptLocation
			// then draw circle based on angle and distance from centrePoint
			// distance is hypotenuse and vertical is deltaZ
			// need pp.clockwise also
			
			double deltaZ = ptLocation[2] - centreLocation[2];
			double deltaX;
			if (pp.distanceSurface <= fabs(deltaZ)) deltaX = 0;
			else deltaX = sqrt(pp.distanceSurface*pp.distanceSurface - deltaZ*deltaZ);
			double ptX, ptY;
			
			NSPoint ptViewLocation;
			ptY = centrePoint.y + deltaZ*kMillimetresToPixelsScaler;

			if (deltaZ >= 0) {
				if (clockwiseFromCentrePoint)
					ptX = centrePoint.x - deltaX*kMillimetresToPixelsScaler;
				else 
					ptX = centrePoint.x + deltaX*kMillimetresToPixelsScaler;
			}
			else {
				if (clockwiseFromCentrePoint) 
					ptX = centrePoint.x - deltaX*kMillimetresToPixelsScaler;
				else 
					ptX = centrePoint.x + deltaX*kMillimetresToPixelsScaler;
			}
			ptViewLocation = NSMakePoint(ptX, ptY);

			// add to ptViewCoords for ptIndex
			[ptViewCoords replaceObjectAtIndex:ptIndex withObject:[NSValue valueWithPoint:ptViewLocation]];
			
			//draw circle at point
			[[NSColor blueColor] set];

			NSBezierPath* thePath = [NSBezierPath bezierPath];
			[thePath appendBezierPathWithOvalInRect:NSMakeRect(ptViewLocation.x - markerWidth/2.0, ptViewLocation.y - markerWidth/2.0, markerWidth, markerWidth)];
			[thePath fill];
			
			// draw line back to centre point
			[pp.pathColor set];
			NSBezierPath* theLine = [NSBezierPath bezierPath];
			[theLine setLineWidth:2.0];
			[theLine moveToPoint:ptViewLocation];
			[theLine lineToPoint:centrePoint];
			[theLine stroke];
		
			// write name of point
			CGFloat textYOffset = 10;
			if (ptViewLocation.y < centrePoint.y) textYOffset = -25;
			[attrsDictionary setObject:font forKey:NSFontAttributeName];
			[attrsDictionary setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
			[[ptROI name] drawAtPoint:NSMakePoint(ptViewLocation.x, ptViewLocation.y + textYOffset) withAttributes:attrsDictionary];

			
			// draw distances next to line mid way between two points
			[attrsDictionary setObject:smallFont forKey:NSFontAttributeName];
			[attrsDictionary setObject:pp.pathColor forKey:NSForegroundColorAttributeName];
			NSString *distStr = [NSString stringWithFormat:@"%0.1lf",pp.distanceSurface];
			NSPoint distPoint = NSMakePoint((ptViewLocation.x + centrePoint.x)/2.0, (ptViewLocation.y + centrePoint.y)/2.0);
			double yOffset = 0;
			double xOffset = 0;
			if (fabs(ptViewLocation.x - centrePoint.x) > fabs(ptViewLocation.y - centrePoint.y)) 		// more horizontal
				yOffset = -15.0;
			else 
				xOffset = 10.0;
			
			if (distPoint.x < centrePoint.x) xOffset *= -1.5; 
			if (distPoint.y > centrePoint.y) yOffset *= -1.0;
			
			distPoint.x += xOffset;
			distPoint.y += yOffset;
			
			[distStr drawAtPoint:distPoint withAttributes:attrsDictionary];
		}
			
	}
	
	// draw centre point as red marker
	[[NSColor redColor] set];
	NSBezierPath* thePath = [NSBezierPath bezierPath];
	[thePath appendBezierPathWithOvalInRect:NSMakeRect(centrePoint.x - markerWidth/2.0, centrePoint.y - markerWidth/2.0, markerWidth, markerWidth)];
	[thePath fill];
	

	[attrsDictionary setObject:font forKey:NSFontAttributeName];
	[attrsDictionary setObject:[NSColor redColor] forKey:NSForegroundColorAttributeName];
	[centrePointName drawAtPoint:NSMakePoint(centrePoint.x, centrePoint.y - 25) withAttributes:attrsDictionary];

	BOOL pathAroundTheBack = NO;
		
	// draw lines between point not including the centre point
	if (plotAllPaths) {
		for (PointPairObject *pp in results) {

			pathAroundTheBack = NO;
			
			if ((pp.p1ROIIndex != centrePtIndex) && (pp.p2ROIIndex != centrePtIndex)) {
			
				NSPoint pt1Coords = [[ptViewCoords objectAtIndex:pp.p1ROIIndex] pointValue];
				NSPoint pt2Coords = [[ptViewCoords objectAtIndex:pp.p2ROIIndex] pointValue];

				// check if this path goes around the other side of the aorta compared with the centre point
				// 
				BOOL c_to_p1 = NO;
				double c_p1Distance;
				BOOL p2_to_c = NO;
				double c_p2Distance;
				NSString *p1name, *p2name;
				
				for (PointPairObject *cp in results) {
				
					// get pointpairobject that contains centre point and p1, and then centre point and p2
					if (((cp.p1ROIIndex == pp.p1ROIIndex) && (cp.p2ROIIndex == centrePtIndex)) || 
						((cp.p2ROIIndex == pp.p1ROIIndex) && (cp.p1ROIIndex == centrePtIndex))) {
						
						p1name = cp.p2Name;
						c_to_p1 = cp.clockwise;
						if (cp.p1ROIIndex == pp.p1ROIIndex) {
							c_to_p1 = !cp.clockwise;	// if p1 is the first point then c_to_p1 is !clockwise
							p1name = cp.p1Name;
						}
						c_p1Distance = cp.distanceSurface;
					}
					if (((cp.p1ROIIndex == pp.p2ROIIndex) && (cp.p2ROIIndex == centrePtIndex)) || 
						((cp.p2ROIIndex == pp.p2ROIIndex) && (cp.p1ROIIndex == centrePtIndex))) {
						
						p2name = cp.p1Name;
						p2_to_c = cp.clockwise;
						if (cp.p2ROIIndex == pp.p2ROIIndex) {
							p2_to_c = !cp.clockwise;	// if p2 is the second point then p2_to_c is !clockwise
							p2name = cp.p2Name;
						}
						c_p2Distance = cp.distanceSurface;
					}
				}
				
				// if p2 -> c -> p1 all same direction and p2 to p1 is the same also then it goes around the back
				// also check via distances
				// if 
				if (c_to_p1 == p2_to_c) {
					BOOL p1_to_p2 = pp.clockwise;
					if ([pp.p1Name isEqualToString:p2name]) p1_to_p2 = !p1_to_p2;
					if (p1_to_p2 == c_to_p1) pathAroundTheBack  = YES;
				}
				
				
				// draw line back to centre point
				[pp.pathColor set];
				NSBezierPath* theLine = [NSBezierPath bezierPath];
				[theLine setLineWidth:2.0];
				[theLine moveToPoint:pt1Coords];
				[theLine lineToPoint:pt2Coords];
				
				if (pathAroundTheBack) {
					CGFloat array[2] = {5.0, 2.0};
					[theLine setLineDash:array count:2 phase:0.0];
				}
				[theLine stroke];
				
								
				// draw distances next to line mid way between two points
				[attrsDictionary setObject:smallFont forKey:NSFontAttributeName];
				[attrsDictionary setObject:pp.pathColor forKey:NSForegroundColorAttributeName];				
				
				NSString *distStr = [NSString stringWithFormat:@"%0.1lf",pp.distanceSurface];
				NSPoint distPoint = NSMakePoint((pt1Coords.x + pt2Coords.x)/2.0, (pt1Coords.y + pt2Coords.y)/2.0);
				double yOffset = 0;
				double xOffset = 0;
			
				if (fabs(pt1Coords.x - pt2Coords.x) > fabs(pt1Coords.y - pt2Coords.y)) 		// more horizontal
					yOffset = -15.0;
				else 
					xOffset = 10.0;
				
				if (distPoint.x < centrePoint.x) xOffset *= -1.5; 
				if (distPoint.y > centrePoint.y) yOffset *= -1.0;
					
				distPoint.x += xOffset;
				distPoint.y += yOffset;
				
				[distStr drawAtPoint:distPoint withAttributes:attrsDictionary];
				
			}
		}
	}
}

@end
