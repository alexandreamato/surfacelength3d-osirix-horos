// GeodesicProcessor.mm — VTK 9.x geodesic path computation for SurfaceLength3D (Horos)
//
// VTK 9.x API changes from original (VTK 5.x):
//   SetInput(data)           → SetInputData(data)
//   SetInput(algo->GetOutput()) → SetInputConnection(algo->GetOutputPort())
//   vtkVolumeRayCastMapper   → removed; use vtkSmartVolumeMapper
//
// Threading model: Dijkstra runs on a GCD background queue; VTK actor creation and
// renderer calls happen on the main thread.

#import "GeodesicProcessor.h"

#ifdef __cplusplus
#define id Id
#include "vtkActor.h"
#include "vtkActorCollection.h"
#include "vtkCellArray.h"
#include "vtkDijkstraGraphGeodesicPath.h"
#include "vtkIdList.h"
#include "vtkMapper.h"
#include "vtkPoints.h"
#include "vtkPointLocator.h"
#include "vtkPolyData.h"
#include "vtkPolyDataMapper.h"
#include "vtkProperty.h"
#include "vtkRenderer.h"
#include "vtkRenderWindow.h"
#include "vtkTubeFilter.h"
#undef id
#endif

#import "ViewerController.h"
#import "SRController.h"
#import "DCMPix.h"
#import "ROI.h"
#import "ProcessWindowController.h"
#import "SurfaceLength3DFilter.h"
#import "PointPair.h"
#import "Constants.h"

// Maximum concurrent paths supported (expand if needed)
static const NSInteger kMaxPaths = 200;

@interface GeodesicProcessor ()

@property (nonatomic, weak) ViewerController       *viewerController;
@property (nonatomic, weak) ProcessWindowController *windowController;
@property (nonatomic, weak) SurfaceLength3DFilter   *pluginFilter;

@end

@implementation GeodesicProcessor {
    vtkActor *_pathActors[kMaxPaths];
}

- (instancetype)init {
    return [self initWithViewerController:nil windowController:nil pluginFilter:nil];
}

- (instancetype)initWithViewerController:(ViewerController *)vc
                        windowController:(ProcessWindowController *)wc
                            pluginFilter:(SurfaceLength3DFilter *)filter {
    self = [super init];
    if (self) {
        _viewerController = vc;
        _windowController = wc;
        _pluginFilter     = filter;
        memset(_pathActors, 0, sizeof(_pathActors));
    }
    return self;
}

- (void)dealloc {
    [self removeAllPaths];
}

// ---------------------------------------------------------------------------
#pragma mark - Surface actor detection
// ---------------------------------------------------------------------------

- (nullable vtkActor *)surfaceActor {
    SRController *srViewer = [self.viewerController openSRViewer];
    if (!srViewer) return nullptr;

    vtkRenderer *rend = (vtkRenderer *)[[srViewer view] vtkRenderer];
    if (!rend) return nullptr;

    vtkActorCollection *actors = rend->GetActors();
    if (!actors) return nullptr;

    vtkActor *actor = nullptr;
    for (actors->InitTraversal(); (actor = actors->GetNextActor()); ) {
        vtkMapper *mapper = actor->GetMapper();
        if (mapper && mapper->GetInput() && mapper->GetInput()->GetNumberOfPoints() > 1000) {
            return actor;
        }
    }
    return nullptr;
}

// ---------------------------------------------------------------------------
#pragma mark - Path display / removal (must be called on main thread)
// ---------------------------------------------------------------------------

- (void)removePathAtIndex:(NSInteger)index {
    NSAssert(NSThread.isMainThread, @"removePathAtIndex: must be called on main thread");
    if (index < 0 || index >= kMaxPaths || !_pathActors[index]) return;

    SRController *srViewer = [self.viewerController openSRViewer];
    vtkRenderer  *rend     = (vtkRenderer *)[[srViewer view] vtkRenderer];

    rend->RemoveActor(_pathActors[index]);
    _pathActors[index]->Delete();
    _pathActors[index] = nullptr;

    [[srViewer view] setNeedsDisplay:YES];
}

- (void)removeAllPaths {
    NSAssert(NSThread.isMainThread, @"removeAllPaths must be called on main thread");
    NSInteger count = (NSInteger)self.pluginFilter.pairsResultsArray.count;
    for (NSInteger i = 0; i < count && i < kMaxPaths; i++) {
        [self removePathAtIndex:i];
    }
}

- (void)displayPathAtIndex:(NSInteger)index {
    NSAssert(NSThread.isMainThread, @"displayPathAtIndex: must be called on main thread");
    if (index < 0 || index >= kMaxPaths) return;

    SRController   *srViewer   = [self.viewerController openSRViewer];
    vtkRenderer    *rend       = (vtkRenderer *)[[srViewer view] vtkRenderer];
    vtkRenderWindow *rendWindow = (vtkRenderWindow *)[[srViewer view] renderWindow];

    PointPair *pp = self.pluginFilter.pairsResultsArray[index];
    NSArray<NSValue *> *pts = pp.pathPoints;
    if (!pts.count) return;

    vtkPoints    *inputPoints = vtkPoints::New();
    vtkCellArray *lines       = vtkCellArray::New();
    lines->InsertNextCell((vtkIdType)pts.count);

    for (NSUInteger i = 0; i < pts.count; i++) {
        SL3DPoint p;
        [pts[i] getValue:&p];
        inputPoints->InsertPoint((vtkIdType)i, p.x, p.y, p.z);
        lines->InsertCellPoint((vtkIdType)i);
    }

    vtkPolyData *inputData = vtkPolyData::New();
    inputData->SetPoints(inputPoints);
    inputData->SetLines(lines);

    // VTK 9.x: SetInputData / SetInputConnection / GetOutputPort
    vtkTubeFilter *tube = vtkTubeFilter::New();
    tube->SetInputData(inputData);
    tube->SetNumberOfSides(8);
    tube->SetRadius(1.0);

    vtkPolyDataMapper *mapper = vtkPolyDataMapper::New();
    mapper->SetInputConnection(tube->GetOutputPort());

    if (_pathActors[index]) {
        _pathActors[index]->Delete();
    }
    _pathActors[index] = vtkActor::New();
    _pathActors[index]->SetMapper(mapper);

    CGFloat r, g, b, a;
    [pp.pathColor getRed:&r green:&g blue:&b alpha:&a];
    _pathActors[index]->GetProperty()->SetColor(r, g, b);

    rend->AddActor(_pathActors[index]);
    rendWindow->Render();

    inputPoints->Delete();
    lines->Delete();
    inputData->Delete();
    tube->Delete();
    mapper->Delete();
}

// ---------------------------------------------------------------------------
#pragma mark - Coordinate helpers
// ---------------------------------------------------------------------------

- (void)convertDataSetPoint:(double *)ds toWorldPoint:(double *)world {
    DCMPix *pix = self.viewerController.pixList.firstObject;
    world[0] = ds[0] + pix.originX;
    world[1] = ds[1] + pix.originY;
    world[2] = ds[2] + pix.originZ;
}

- (void)getROILocation:(double *)loc forIndex:(NSInteger)index {
    NSMutableArray *pts = [self.viewerController point2DList];
    ROI    *roi    = (ROI *)pts[index];
    DCMPix *dcm    = roi.pix;

    float location[3];
    [dcm convertPixX:[roi.points[0] x] pixY:[roi.points[0] y] toDICOMCoords:location];

    DCMPix *origin = self.viewerController.pixList.firstObject;
    loc[0] = location[0] - origin.originX;
    loc[1] = location[1] - origin.originY;
    loc[2] = location[2] - origin.originZ;
}

- (BOOL)isClockwiseFromP1:(double *)p1 p2:(double *)p2 midPath:(double *)mid {
    double e1x = p1[0] - mid[0], e1y = p1[1] - mid[1];
    double e2x = p2[0] - mid[0], e2y = p2[1] - mid[1];
    return (e1x * e2y - e1y * e2x) >= 0;
}

// ---------------------------------------------------------------------------
#pragma mark - Core geodesic computation
// ---------------------------------------------------------------------------

- (void)processAllPathsWithCompletion:(void (^)(void))completion {
    // Capture Dijkstra inputs on the main thread before going to background
    vtkActor *actor = [self surfaceActor];
    if (!actor) {
        if (completion) dispatch_async(dispatch_get_main_queue(), completion);
        return;
    }

    vtkPolyDataMapper *sourceMapper = (vtkPolyDataMapper *)actor->GetMapper();
    vtkPolyData *sourceData = sourceMapper->GetInput();

    // ShallowCopy is thread-safe for reading once construction is done
    vtkPolyData *inData = vtkPolyData::New();
    inData->ShallowCopy(sourceData);

    NSArray<PointPair *> *pairs = [self.pluginFilter.pairsResultsArray copy];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{

        vtkPointLocator *locator = vtkPointLocator::New();
        locator->SetDataSet(inData);
        locator->BuildLocator();

        vtkPoints *surfacePoints = inData->GetPoints();
        double x[3];

        for (NSInteger pathIndex = 0; pathIndex < (NSInteger)pairs.count; pathIndex++) {
            PointPair *pp = pairs[pathIndex];

            // Signal UI that we are computing this pair
            dispatch_async(dispatch_get_main_queue(), ^{
                pp.state = PointPairStateCalculating;
                [self.windowController updateResultsColumn];
            });

            double roiLoc1[3], roiLoc2[3];
            [self getROILocation:roiLoc1 forIndex:pp.p1ROIIndex];
            [self getROILocation:roiLoc2 forIndex:pp.p2ROIIndex];

            // Project each ROI point onto the surface along the direct vector
            // (accounts for ROI points floating in air above the surface)
            auto snapToSurface = [&](double *roiLoc, double *otherLoc) -> vtkIdType {
                vtkIdType initial = locator->FindClosestPoint(roiLoc[0], roiLoc[1], roiLoc[2]);
                surfacePoints->GetPoint(initial, x);
                double dist = sqrt((roiLoc[0]-x[0])*(roiLoc[0]-x[0]) +
                                   (roiLoc[1]-x[1])*(roiLoc[1]-x[1]) +
                                   (roiLoc[2]-x[2])*(roiLoc[2]-x[2]));
                double directDist = pp.distanceDirect;
                if (directDist < 1e-9) return initial;
                double projected[3] = {
                    roiLoc[0] + (otherLoc[0]-roiLoc[0])/directDist * dist,
                    roiLoc[1] + (otherLoc[1]-roiLoc[1])/directDist * dist,
                    roiLoc[2] + (otherLoc[2]-roiLoc[2])/directDist * dist
                };
                return locator->FindClosestPoint(projected[0], projected[1], projected[2]);
            };

            vtkIdType closestPt1 = snapToSurface(roiLoc1, roiLoc2);
            vtkIdType closestPt2 = snapToSurface(roiLoc2, roiLoc1);

            // Dijkstra
            vtkDijkstraGraphGeodesicPath *path = vtkDijkstraGraphGeodesicPath::New();
            path->SetInputData(inData);
            path->SetStopWhenEndReached(1);
            path->SetStartVertex(closestPt1);
            path->SetEndVertex(closestPt2);
            path->Update();

            vtkIdList *idList = path->GetIdList();
            NSInteger midIdx  = idList->GetNumberOfIds() / 2;

            // Walk path segments to accumulate length and collect world-space waypoints
            NSMutableArray<NSValue *> *waypoints = [NSMutableArray array];
            double pathLength = 0.0;
            BOOL   clockwise  = NO;

            // Convert ROI endpoints to world space
            double roiLoc1w[3], roiLoc2w[3];
            [self convertDataSetPoint:roiLoc1 toWorldPoint:roiLoc1w];
            [self convertDataSetPoint:roiLoc2 toWorldPoint:roiLoc2w];

            // Dijkstra returns path from endVertex → startVertex, so start with p2
            SL3DPoint pt3 = { roiLoc2w[0], roiLoc2w[1], roiLoc2w[2] };
            [waypoints addObject:[NSValue valueWithBytes:&pt3 objCType:@encode(SL3DPoint)]];
            double prev[3] = { roiLoc2w[0], roiLoc2w[1], roiLoc2w[2] };

            for (NSInteger k = 0; k < (NSInteger)idList->GetNumberOfIds(); k++) {
                double ds[3], world[3];
                inData->GetPoint(idList->GetId(k), ds);
                [self convertDataSetPoint:ds toWorldPoint:world];

                pt3 = { world[0], world[1], world[2] };
                [waypoints addObject:[NSValue valueWithBytes:&pt3 objCType:@encode(SL3DPoint)]];

                double seg = sqrt((world[0]-prev[0])*(world[0]-prev[0]) +
                                  (world[1]-prev[1])*(world[1]-prev[1]) +
                                  (world[2]-prev[2])*(world[2]-prev[2]));
                pathLength += seg;
                prev[0] = world[0]; prev[1] = world[1]; prev[2] = world[2];

                if (k == midIdx) {
                    clockwise = [self isClockwiseFromP1:roiLoc1 p2:roiLoc2 midPath:ds];
                }
            }
            path->Delete();

            // Last segment from path end to p1
            double lastSeg = sqrt((roiLoc1w[0]-prev[0])*(roiLoc1w[0]-prev[0]) +
                                  (roiLoc1w[1]-prev[1])*(roiLoc1w[1]-prev[1]) +
                                  (roiLoc1w[2]-prev[2])*(roiLoc1w[2]-prev[2]));
            pathLength += lastSeg;
            pt3 = { roiLoc1w[0], roiLoc1w[1], roiLoc1w[2] };
            [waypoints addObject:[NSValue valueWithBytes:&pt3 objCType:@encode(SL3DPoint)]];

            NSArray<NSValue *> *frozenWaypoints = [waypoints copy];
            double frozenLength  = pathLength;
            BOOL   frozenCW      = clockwise;
            NSInteger frozenIdx  = pathIndex;

            // Update model and render on main thread
            dispatch_sync(dispatch_get_main_queue(), ^{
                pp.distanceSurface = frozenLength;
                pp.pathPoints      = frozenWaypoints;
                pp.clockwise       = frozenCW;
                pp.state           = PointPairStateCalculated;

                [self displayPathAtIndex:frozenIdx];
                [self.windowController updateResultsColumn];
            });
        }

        locator->Delete();
        inData->Delete();

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion();
        });
    });
}

@end
