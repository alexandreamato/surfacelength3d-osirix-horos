//
//  PointPairObject.h
//  SurfaceLength3D
//
//  Created by Gary Fielke on 20/08/08.
//  Copyright 2008 TriX Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

enum {
	kPairStateNone=0,
	kPairStateCalculatingDistance,
	kPairStateCalculatedDistance
};

	
@interface PointPairObject : NSObject {

	NSString	*p1Name;
	NSString	*p2Name;
	
	int			state;
	BOOL		displayPath;
	
	double		distanceDirect;
	double		distanceSurface;
	
	NSArray		*pathPoints;
	
	BOOL		clockwise;  // direction of shortest distance from pt1 to pt2 
	NSInteger	p1ROIIndex;
	NSInteger	p2ROIIndex;

	NSColor		*pathColor;
}

@property (nonatomic, copy) NSString	*p1Name;
@property (nonatomic, copy) NSString	*p2Name;
@property (nonatomic, retain) NSArray	*pathPoints;
@property (nonatomic, retain) NSColor	*pathColor;

@property (assign) int			state;
@property (assign) BOOL			displayPath;
@property (assign) double		distanceDirect;
@property (assign) double		distanceSurface;
@property (assign) BOOL			clockwise;

@property (assign)	NSInteger	p1ROIIndex;
@property (assign)	NSInteger	p2ROIIndex;


@end
