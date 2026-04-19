//
//  Processor.m
//  SurfaceLength3D
//
//  Created by Gary Fielke on 11/08/08.
//  Copyright 2008 TriX Software. All rights reserved.
//

#import "Processor.h"

#ifdef __cplusplus
#define id Id
#include "vtkCommand.h"
#include "vtkProperty.h"
#include "vtkActor.h"
#include "vtkPolyData.h"
#include "vtkRenderer.h"
#include "vtkRenderWindow.h"
#include "vtkRenderWindowInteractor.h"
#include "vtkVolume16Reader.h"
#include "vtkPolyDataMapper.h"
#include "vtkActor.h"
#include "vtkOutlineFilter.h"
#include "vtkImageReader.h"
#include "vtkImageImport.h"
#include "vtkCamera.h"
#include "vtkStripper.h"
#include "vtkLookupTable.h"
#include "vtkImageDataGeometryFilter.h"
#include "vtkProperty.h"
#include "vtkPolyDataNormals.h"
#include "vtkContourFilter.h"
#include "vtkImageData.h"
#include "vtkImageMapToColors.h"
#include "vtkImageActor.h"
#include "vtkLight.h"

#include "vtkPlane.h"
#include "vtkPlanes.h"
#include "vtkPlaneSource.h"
#include "vtkBoxWidget.h"
#include "vtkPlaneWidget.h"
#include "vtkPiecewiseFunction.h"
#include "vtkPiecewiseFunction.h"
#include "vtkColorTransferFunction.h"
#include "vtkVolumeProperty.h"
#include "vtkVolumeRayCastCompositeFunction.h"
#include "vtkVolumeRayCastMapper.h"
#include "vtkVolumeRayCastMIPFunction.h"
#include "vtkFixedPointVolumeRayCastMapper.h"
#include "vtkTransform.h"
#include "vtkSphere.h"
#include "vtkImplicitBoolean.h"
#include "vtkExtractGeometry.h"
#include "vtkDataSetMapper.h"
#include "vtkPicker.h"
#include "vtkCellPicker.h"
#include "vtkPointPicker.h"
#include "vtkLineSource.h"
#include "vtkPolyDataMapper2D.h"
#include "vtkActor2D.h"
#include "vtkExtractPolyDataGeometry.h"
#include "vtkProbeFilter.h"
#include "vtkCutter.h"
#include "vtkTransformPolyDataFilter.h"
#include "vtkXYPlotActor.h"
#include "vtkClipPolyData.h"
#include "vtkBox.h"
#include "vtkCallbackCommand.h"
#include "vtkTextActor.h"
#include "vtkTextProperty.h"
#include "vtkImageFlip.h"
#include "vtkAnnotatedCubeActor.h"
#include "vtkOrientationMarkerWidget.h"
#include "vtkVolumeTextureMapper2D.h"
#include "vtkVolumeTextureMapper3D.h"
//#include "vtkVolumeShearWarpMapper.h"

#include "vtkCellArray.h"
#include "vtkProperty2D.h"

#include "vtkSphereSource.h"
#include "vtkRegularPolygonSource.h"

#include "vtkPoints.h"
#include "vtkImageExport.h"
#include "vtkImageGradientMagnitude.h"
#include "vtkImageThreshold.h"
#include "vtkCoordinate.h"
#include "vtkImageLuminance.h"


#include "vtkDijkstraGraphGeodesicPath.h"
#include "vtkCellLocator.h"
#include "vtkTubeFilter.h"
#include "vtkPointLocator.h"
#include "vtkGlyph3D.h"


#undef id
#else
typedef char* vtkPoints;
#endif

#import "ViewerController.h"
#import "ProcessWindowController.h"
#import "SurfaceLength3DFilter.h"
#import "PointPairObject.h"
#import "Constants.h"
#import "DebugUtils.h"

@interface Processor (ProcessorPrivate)
-(vtkActor*)surfaceActor;
-(void)convDataSetCoords:(double*)dataSet toWorld:(double*)world;
-(void)getROILocation:(double*)loc forIndex:(int)index;
-(BOOL)calcClockwiseFromP1:(double*)p1 P2:(double*)p2 midPath:(double*)midP;
@end

@implementation Processor

//--------------------------------------------------------------------------------------
// set controllers and plugin references for later
//--------------------------------------------------------------------------------------

-(void)setViewerController:(ViewerController*)vc controller:(ProcessWindowController *)wc filter:(SurfaceLength3DFilter*)filter
{
	viewerController = vc;
	windowController = wc;
	pluginFilter = filter;
	
	// setup timer to check every second if we have a surface actor
	// no message or notification is called from OsiriX when surface rendering is done unfortunately (that I could find anyway)
	// so we check ourselves every second for an actor with a larger number of points ( > 1000) 
	checkSurfaceTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkActorsForSurface) userInfo:nil repeats:YES];
	[checkSurfaceTimer retain];
}
	

//--------------------------------------------------------------------------------------
// timer method called every second to check if we have surface
// if we do have surface stop timer and send notification for any interested observers
//--------------------------------------------------------------------------------------

-(void)checkActorsForSurface
{
	if ([self surfaceActor] != NULL) {
		
		[checkSurfaceTimer invalidate];
		[checkSurfaceTimer release];
		checkSurfaceTimer = nil;

		[[NSNotificationCenter defaultCenter] postNotificationName:@"SurfaceRendered" object:nil];
	}
}


//--------------------------------------------------------------------------------------
// remove plot from path is we deselect display checkbox
// here we delete and then reconstruct entirely in displayPathForIndex
// could be more efficient here and not delete completely
//--------------------------------------------------------------------------------------

-(void)removePathForIndex:(NSInteger)index
{
	if (pathActor[index]) {
		SRController *srViewer = [viewerController openSRViewer];		
		vtkRenderer *rend = (vtkRenderer*)[[srViewer view] vtkRenderer];
		
		rend->RemoveActor(pathActor[index]);
		pathActor[index]->Delete();
		pathActor[index] = NULL;	
		
		[[srViewer view] setNeedsDisplay:YES];
	}
}


-(void)removeAllPaths
{
	for (NSUInteger i=0; i<[pluginFilter.pairsResultsArray count]; i++) [self removePathForIndex:i];
}

//--------------------------------------------------------------------------------------
// Create path and display for index into filter.pairsResultsArray
//--------------------------------------------------------------------------------------

-(void)displayPathForIndex:(NSInteger)index
{
	SRController *srViewer = [viewerController openSRViewer];
	
	vtkRenderer *rend = (vtkRenderer*)[[srViewer view] vtkRenderer];
	vtkRenderWindow *rendWindow = (vtkRenderWindow*)[[srViewer view] renderWindow];

	
	PointPairObject *pp = [pluginFilter.pairsResultsArray objectAtIndex:index];
	
	// convert points to polyydata
	NSUInteger i;
	vtkPoints *inputPoints = vtkPoints::New();
	vtkCellArray *lines = vtkCellArray::New();
	lines->InsertNextCell( [pp.pathPoints count] );
	
	double p[3];
	
	for(i=0; i < [pp.pathPoints count]; i++)
    {
		[(NSValue*)[pp.pathPoints objectAtIndex:i] getValue:p];
		inputPoints->InsertPoint(i, p[0],p[1],p[2]);		
		lines->InsertCellPoint(i);
	}
	
	vtkPolyData *inputData = vtkPolyData::New();	
	inputData->SetPoints(inputPoints);
	inputData->SetLines(lines);
	

	// draw tube along path
	vtkTubeFilter *tube = vtkTubeFilter::New();
	tube->SetInput(inputData);
	tube->SetNumberOfSides(8);
	tube->SetRadius(1.0);
	
	vtkPolyDataMapper *glyphMapper = vtkPolyDataMapper::New();
	glyphMapper->SetInput(tube->GetOutput());
	
	if (!pathActor[index]) pathActor[index] = vtkActor::New();
	pathActor[index]->SetMapper(glyphMapper);

	CGFloat rr, gg, bb, aa;
	[pp.pathColor getRed:&rr green:&gg blue:&bb alpha:&aa];
	pathActor[index]->GetProperty()->SetColor(rr, gg, bb);

	rend->AddActor(pathActor[index]);
	rendWindow->Render();
		
	inputPoints->Delete();
	lines->Delete();
	glyphMapper->Delete();
	inputData->Delete();	
	tube->Delete();
}

//--------------------------------------------------------------------------------------
// return surface actor so we can find path along it
//--------------------------------------------------------------------------------------
-(vtkActor*)surfaceActor
{
	SRController *srViewer = [viewerController openSRViewer];
	if (!srViewer) return NULL;

	vtkRenderer *rend = (vtkRenderer*)[[srViewer view] vtkRenderer];
	if (!rend) return NULL;

	vtkActorCollection *actorCollection = rend->GetActors();
	if (!actorCollection) return NULL;
	
	vtkActor *actor;
	int j;
	BOOL haveSurface = NO;
	for (actorCollection->InitTraversal(), j=0; (actor = actorCollection->GetNextActor()); ++j) {
		
		vtkMapper *mapper = actor->GetMapper();
		int numPoints = mapper->GetInput()->GetNumberOfPoints();
		
		if (numPoints > 1000) {
			haveSurface = TRUE;
			break;
		}
	}
	
	if (haveSurface) {
		return actor;
	}
	else return NULL;
}




//--------------------------------------------------------------------------------------
// Loop over all PointPairObjects objects in filter.pairsResultsArray
// Create path from Point1 to Point2 along the surface using vtkDijkstraGraphGeodesicPath
// Also calc distance along path by stepping through each point of returned path
//--------------------------------------------------------------------------------------

-(void)processAllPaths
{	
	SRController *srViewer = [viewerController openSRViewer];
	
	vtkActor *actor = [self surfaceActor];

	vtkPolyDataMapper *mapper = (vtkPolyDataMapper *)actor->GetMapper();
	vtkPolyData *data = mapper->GetInput();
	
	double bounds[6];
	mapper->GetBounds(bounds);
	
	
	vtkPolyData *inData = vtkPolyData::New();
	inData->ShallowCopy(data);

	
	// point values from 	vtkPoints *p = data->GetPoints();
	// which is originally from the actor's mapper
	// are within the bounds of the SR which is from (0,0,0) to (75, 94, 145)
	// whereas the actual x,y,z in world coords is (-167, -24, 224) to (-92, 70, 370)
	
	// so we need to offset the points we pass to locator to make them within (0,0,0) to (75, 94, 145)
	// just subtract the origin (-167, -23, 224) from points
	
	vtkPointLocator *locator = vtkPointLocator::New();
	locator->SetDataSet(inData);
	locator->BuildLocator();
		
	
	// loop through pairs of points to find path distance
	double roiLoc1[3], roiLoc2[3];
	vtkPoints *p = data->GetPoints();
	double x[3];
	double vec12[3], p1a[3], p2a[3];
	int pathIndex=0;
	
	NSArray *resultsArray = pluginFilter.pairsResultsArray;
	
	for (PointPairObject *ptPair in resultsArray) {
		
		NSMutableArray *pointsInPath = [[NSMutableArray alloc] init];
		
		// set state of this pair so it shows in the table that we are calculating
		ptPair.state = kPairStateCalculatingDistance;
		[windowController updateResultsColumn];
		
		NSInteger ptIndex1 = ptPair.p1ROIIndex;
		[self getROILocation:roiLoc1 forIndex:ptIndex1];
		NSInteger ptIndex2 = ptPair.p2ROIIndex;
		[self getROILocation:roiLoc2 forIndex:ptIndex2];
			
		// get closest point on the surface to the point of interest
		vtkIdType initialClosestPoint1 = locator->FindClosestPoint((double)roiLoc1[0], (double)roiLoc1[1], (double)roiLoc1[2]);
		p->GetPoint(initialClosestPoint1, x);


		// get distance from closest point on the surface to the point of reference
		double closestDistance1 = sqrt((roiLoc1[0] - x[0])*(roiLoc1[0] - x[0]) + (roiLoc1[1] - x[1])*(roiLoc1[1] - x[1]) + (roiLoc1[2] - x[2])*(roiLoc1[2] - x[2]));
		
		// get unit vector from point1 to point2, determine the point that is closestDistance1 along this line from point 1, then find closest point on surface to that!
		vec12[0] = (roiLoc2[0] - roiLoc1[0])/ptPair.distanceDirect;
		vec12[1] = (roiLoc2[1] - roiLoc1[1])/ptPair.distanceDirect;
		vec12[2] = (roiLoc2[2] - roiLoc1[2])/ptPair.distanceDirect;
		
		p1a[0] = roiLoc1[0] + vec12[0]* closestDistance1;
		p1a[1] = roiLoc1[1] + vec12[1]* closestDistance1;
		p1a[2] = roiLoc1[2] + vec12[2]* closestDistance1;
	
		vtkIdType closestPoint1 = locator->FindClosestPoint(p1a[0], p1a[1], p1a[2]);
		p->GetPoint(closestPoint1, x);

		
		// same for point 2
		vtkIdType initialClosestPoint2 = locator->FindClosestPoint((double)roiLoc2[0], (double)roiLoc2[1], (double)roiLoc2[2]);
		p->GetPoint(initialClosestPoint2, x);
	
		// get distance from closest point on the surface to the point of reference
		double closestDistance2 = sqrt((roiLoc2[0] - x[0])*(roiLoc2[0] - x[0]) + (roiLoc2[1] - x[1])*(roiLoc2[1] - x[1]) + (roiLoc2[2] - x[2])*(roiLoc2[2] - x[2]));
		
		// get unit vector from point2 to point1, determine the point that is closestDistance2 along this line from point 2, then find closest point on surface to that!
		vec12[0] = (roiLoc1[0] - roiLoc2[0])/ptPair.distanceDirect;
		vec12[1] = (roiLoc1[1] - roiLoc2[1])/ptPair.distanceDirect;
		vec12[2] = (roiLoc1[2] - roiLoc2[2])/ptPair.distanceDirect;
		
		p2a[0] = roiLoc2[0] + vec12[0]* closestDistance2;
		p2a[1] = roiLoc2[1] + vec12[1]* closestDistance2;
		p2a[2] = roiLoc2[2] + vec12[2]* closestDistance2;
		
		vtkIdType closestPoint2 = locator->FindClosestPoint(p2a[0], p2a[1], p2a[2]);
		p->GetPoint(closestPoint2, x);

		
		// set up Dijkstra algorithm
		vtkDijkstraGraphGeodesicPath *path = vtkDijkstraGraphGeodesicPath::New();
		path->SetInput(inData);
		path->SetStopWhenEndReached(1);
		path->SetStartVertex(closestPoint1);
		path->SetEndVertex(closestPoint2);
		path->Update();
		double pathLength = path->GetGeodesicLength();		// not implemented always zero so loop through each line segment output froom Dijkstra algorithm
		
		vtkIdList *list = path->GetIdList();		
		
		int k;
		double p1[3], p2[3], p2w[3], ppLength;
		pathLength = 0;
		Point3 pt3;

		double roiLoc1w[3], roiLoc2w[3];
		
		[self convDataSetCoords:roiLoc1 toWorld:roiLoc1w];
		[self convDataSetCoords:roiLoc2 toWorld:roiLoc2w];

		// start at point 2
		pt3.x = p1[0] = roiLoc2w[0];
		pt3.y = p1[1] = roiLoc2w[1];
		pt3.z = p1[2] = roiLoc2w[2];
		[pointsInPath addObject:[NSValue valueWithBytes:&pt3 objCType:@encode(Point3)]];
		
		int midPointIndex = list->GetNumberOfIds()/2;
		BOOL clockwise = NO;
		
		// loop through each path segment to get total path length - goes from endVertex to startVertex
		for (k=0; k<list->GetNumberOfIds(); k++) {
			
			vtkIdType ptId = list->GetId(k);
			inData->GetPoint(ptId, p2);
		
			[self convDataSetCoords:p2 toWorld:p2w];

			pt3.x = p2w[0];
			pt3.y = p2w[1];
			pt3.z = p2w[2];
			[pointsInPath addObject:[NSValue valueWithBytes:&pt3 objCType:@encode(Point3)]];
		
			ppLength = sqrt((p2w[0]-p1[0])*(p2w[0]-p1[0]) + (p2w[1]-p1[1])*(p2w[1]-p1[1]) + (p2w[2]-p1[2])*(p2w[2]-p1[2]));
			pathLength += ppLength;
			
			// get point of middle of path to work out if we are clockwise or anticlockwise
			if (k == midPointIndex) {		
				clockwise = [self calcClockwiseFromP1:roiLoc1 P2:roiLoc2 midPath:p2];
			}
			
			p1[0] = p2w[0];
			p1[1] = p2w[1];
			p1[2] = p2w[2];
			
		}
		path->Delete();
	
		// from last path point to point 1
		ppLength = sqrt((roiLoc1w[0]-p1[0])*(roiLoc1w[0]-p1[0]) + (roiLoc1w[1]-p1[1])*(roiLoc1w[1]-p1[1]) + (roiLoc1w[2]-p1[2])*(roiLoc1w[2]-p1[2]));
		pathLength += ppLength;
		
		pt3.x = roiLoc1w[0];
		pt3.y = roiLoc1w[1];
		pt3.z = roiLoc1w[2];
		[pointsInPath addObject:[NSValue valueWithBytes:&pt3 objCType:@encode(Point3)]];
		
		// set some values for PointPairObject
		ptPair.distanceSurface = pathLength;
		ptPair.state = kPairStateCalculatedDistance;
		ptPair.pathPoints = pointsInPath;
		ptPair.clockwise = clockwise;
		
		[pointsInPath release];
		
		
		[self displayPathForIndex:pathIndex++];
	}
	
	locator->Delete();
	inData->Delete();
	
	[windowController updateResultsColumn];
}


//--------------------------------------------------------------------------------------
// convert between dataset and world coordinates
//--------------------------------------------------------------------------------------

-(void)convDataSetCoords:(double*)dataSet toWorld:(double*)world
{
	DCMPix *currPix = [[viewerController pixList] objectAtIndex:0];

	world[0] = dataSet[0] + [currPix originX];
	world[1] = dataSet[1] + [currPix originY];
	world[2] = dataSet[2] + [currPix originZ];
}



-(void)getROILocation:(double*)loc forIndex:(int)index
{
	NSMutableArray *pts = [viewerController point2DList];
	double x, y, z;
	float location[3];
	
	ROI *pt = (ROI*)[pts objectAtIndex:index];
		
	DCMPix *curDCM = [pt pix];
	[curDCM convertPixX: [[[pt points] objectAtIndex:0] x] pixY: [[[pt points] objectAtIndex:0] y] toDICOMCoords: location];
		
	x = location[ 0 ];
	y = location[ 1 ];
	z = location[ 2 ];
	
	// subtract origin here - see above notes
	DCMPix *currPix = [[viewerController pixList] objectAtIndex:0];
	
	loc[0] = x - [currPix originX];
	loc[1] = y - [currPix originY];
	loc[2] = z - [currPix originZ];
}


//-----------------------------------------------------------------------------------------
// Determine whether 2 points and the midd point of the path are clockwise or anticlockwise
// from http://www.geocities.com/siliconvalley/2151/math2d.html
//--------------------------------------------------------------------------------------
 
-(BOOL)calcClockwiseFromP1:(double*)p1 P2:(double*)p2 midPath:(double*)midP
{
	BOOL clockwise = FALSE;
	NSPoint e1 = NSMakePoint(p1[0] - midP[0], p1[1] - midP[1]);
	NSPoint e2 = NSMakePoint(p2[0] - midP[0], p2[1] - midP[1]);
	
	if ((e1.x*e2.y - e1.y*e2.x) >= 0) clockwise = TRUE;
	
	return clockwise;
}


@end
