//
//  Processor.h
//  SurfaceLength3D
//
//  Created by Gary Fielke on 11/08/08.
//  Copyright 2008 TriX Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#ifdef __cplusplus
#define id Id
#include "vtkActor.h"
#undef id
#endif

@class ViewerController, ProcessWindowController, SurfaceLength3DFilter;


@interface Processor : NSObject {

	ViewerController		*viewerController;
	ProcessWindowController *windowController;
	SurfaceLength3DFilter			*pluginFilter;

	vtkActor				*pathActor[100];

	NSTimer					*checkSurfaceTimer;
	
}

-(void)setViewerController:(ViewerController*)vc controller:(ProcessWindowController *)wc filter:(SurfaceLength3DFilter*)filter;
-(void)processAllPaths;

-(void)removeAllPaths;
-(void)removePathForIndex:(NSInteger)index;
-(void)displayPathForIndex:(NSInteger)index;

@end
