//
//  PointPairObject.m
//  SurfaceLength3D
//
//  Created by Gary Fielke on 20/08/08.
//  Copyright 2008 TriX Software. All rights reserved.
//

#import "PointPairObject.h"


@implementation PointPairObject

@synthesize p1Name, p2Name, state, displayPath, pathColor, distanceDirect, distanceSurface;
@synthesize pathPoints, clockwise, p1ROIIndex, p2ROIIndex;

-(NSString*)description
{
	return [NSString stringWithFormat:@"%@ to %@: %0.1lf, %@",p1Name, p2Name, distanceSurface, clockwise ? @"cw" : @"ccw"];
}
@end
