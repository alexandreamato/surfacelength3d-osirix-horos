// GeodesicProcessor.mm — VTK 8 geodesic path computation for SurfaceLength3D (Horos)
//
// VTK ABI NOTE: Horos embeds VTK 8.x; we compile with VTK 9.x headers. VTK 9 added
// virtual methods to vtkObjectBase, shifting ALL vtable slots by ~2.  We avoid
// virtual dispatch on Horos-owned VTK objects by:
//   1. Reading struct fields at VTK-8 byte offsets (verified by disassembling Horos)
//   2. Calling only non-virtual methods confirmed as standalone T symbols in Horos
//   3. A custom Dijkstra replaces vtkDijkstraGraphGeodesicPath (absent from Horos binary)
//
// Threading: Dijkstra runs on a GCD background queue; actor creation and renderer
// calls happen on the main thread.

#import "GeodesicProcessor.h"

#ifdef __cplusplus
#define id Id
#include "vtkActorCollection.h"
#include "vtkIdList.h"
#include "vtkPolyDataMapper.h"
#include <algorithm>
#include <queue>
#include <unordered_map>
#include <utility>
#include <vector>
#undef id
#endif

#import <Horos/ViewerController.h>
#import <Horos/SRController.h>
#import <Horos/SRView.h>
#import <Horos/DCMPix.h>
#import <Horos/ROI.h>
#import "ProcessWindowController.h"
#import "SurfaceLength3DFilter.h"
#import "PointPair.h"
#import "Constants.h"
#import "SL3DVTKCompat.h"

// Typed accessor so srViewer.view returns SRView* instead of id
@interface SRController (TypedView)
@property (readonly) SRView *view;
@end

// Runtime helper — aRenderer is @protected; access via ivar offset
#import <objc/runtime.h>
static inline vtkRenderer *SL3DGetRenderer(SRView *v) {
    Ivar iv = class_getInstanceVariable([v class], "aRenderer");
    if (!iv) return nullptr;
    return *reinterpret_cast<vtkRenderer **>(reinterpret_cast<uint8_t *>((__bridge void *)v) + ivar_getOffset(iv));
}

// ---------------------------------------------------------------------------
// SL3DDijkstra — shortest path on COPIED mesh buffers.
//   CSR (Compressed Sparse Row) adjacency: just 3 large heap allocations
//   instead of numPts small ones, eliminating fragmentation / bad_alloc risk.
// ---------------------------------------------------------------------------
struct SL3DAdjCSR {
    std::vector<vtkIdType> ptr;   // size numPts+1; ptr[v] = start index in list[] for v
    std::vector<vtkIdType> list;  // flat directed edge list
};

static void SL3DBuildAdjCSR(const vtkIdType *polys, vtkIdType numPolys,
                              vtkIdType numPts, SL3DAdjCSR &adj) {
    fprintf(stderr, "[SL3D] buildAdj: start numPts=%lld numPolys=%lld\n",
            (long long)numPts, (long long)numPolys); fflush(stderr);

    // Pass 1: count degree for each vertex
    adj.ptr.assign((size_t)(numPts + 1), 0);
    fprintf(stderr, "[SL3D] buildAdj: ptr allocated size=%zu\n", adj.ptr.size()); fflush(stderr);

    vtkIdType pos = 0;
    for (vtkIdType p = 0; p < numPolys; p++) {
        vtkIdType n = polys[pos++];
        if (n >= 2 && n <= 32) {
            for (vtkIdType j = 0; j < n; j++) {
                vtkIdType a = polys[pos + j];
                vtkIdType b = polys[pos + (j + 1) % n];
                // Use at() so out-of-range throws std::out_of_range (caught by try-catch above)
                if (a >= 0 && a < numPts) adj.ptr.at((size_t)(a + 1))++;
                if (b >= 0 && b < numPts) adj.ptr.at((size_t)(b + 1))++;
            }
            pos += n;
        } else if (n >= 2) {
            pos += n;
        }
    }
    fprintf(stderr, "[SL3D] buildAdj: pass1 done pos=%lld\n", (long long)pos); fflush(stderr);

    // Prefix-sum to get offsets
    for (vtkIdType i = 1; i <= numPts; i++)
        adj.ptr.at((size_t)i) += adj.ptr.at((size_t)(i - 1));
    vtkIdType totalEdges = adj.ptr.at((size_t)numPts);
    fprintf(stderr, "[SL3D] buildAdj: prefix-sum done totalEdges=%lld\n",
            (long long)totalEdges); fflush(stderr);

    // Pass 2: fill edges
    adj.list.resize((size_t)totalEdges);
    fprintf(stderr, "[SL3D] buildAdj: list allocated size=%zu\n", adj.list.size()); fflush(stderr);

    std::vector<vtkIdType> fill(adj.ptr.begin(), adj.ptr.begin() + (size_t)numPts);
    fprintf(stderr, "[SL3D] buildAdj: fill allocated\n"); fflush(stderr);

    pos = 0;
    for (vtkIdType p = 0; p < numPolys; p++) {
        vtkIdType n = polys[pos++];
        if (n >= 2 && n <= 32) {
            for (vtkIdType j = 0; j < n; j++) {
                vtkIdType a = polys[pos + j];
                vtkIdType b = polys[pos + (j + 1) % n];
                if (a >= 0 && a < numPts) {
                    vtkIdType &fa = fill.at((size_t)a);
                    adj.list.at((size_t)fa) = b;
                    fa++;
                }
                if (b >= 0 && b < numPts) {
                    vtkIdType &fb = fill.at((size_t)b);
                    adj.list.at((size_t)fb) = a;
                    fb++;
                }
            }
            pos += n;
        } else if (n >= 2) {
            pos += n;
        }
    }
    fprintf(stderr, "[SL3D] adj CSR built: numPts=%lld totalEdges=%lld\n",
            (long long)numPts, (long long)totalEdges);
    fflush(stderr);
}

static std::vector<vtkIdType> SL3DDijkstra(const float *verts,
                                            const SL3DAdjCSR &adj,
                                            vtkIdType startId, vtkIdType endId) {
    vtkIdType numPts = (vtkIdType)adj.ptr.size() - 1;
    if (startId == endId) return {startId};
    if (startId < 0 || startId >= numPts || endId < 0 || endId >= numPts) return {};
    if (adj.ptr[(size_t)(startId+1)] == adj.ptr[(size_t)startId]) return {};
    if (adj.ptr[(size_t)(endId+1)]   == adj.ptr[(size_t)endId])   return {};

    using WV = std::pair<double, vtkIdType>;
    std::priority_queue<WV, std::vector<WV>, std::greater<WV>> pq;
    std::vector<double>    dist((size_t)numPts, std::numeric_limits<double>::max());
    std::vector<vtkIdType> prev((size_t)numPts, -1);

    dist[(size_t)startId] = 0.0;
    pq.push({0.0, startId});

    while (!pq.empty()) {
        auto [d, u] = pq.top(); pq.pop();
        if (u == endId) break;
        if (d > dist[(size_t)u]) continue;

        if (u < 0 || u >= numPts) continue;
        float ux = verts[u*3], uy = verts[u*3+1], uz = verts[u*3+2];
        for (vtkIdType i = adj.ptr[(size_t)u]; i < adj.ptr[(size_t)(u+1)]; i++) {
            vtkIdType v = adj.list[(size_t)i];
            if (v < 0 || v >= numPts) continue;
            float dx = ux - verts[v*3], dy = uy - verts[v*3+1], dz = uz - verts[v*3+2];
            double nd = d + std::sqrt((double)dx*dx + (double)dy*dy + (double)dz*dz);
            if (nd < dist[(size_t)v]) {
                dist[(size_t)v] = nd; prev[(size_t)v] = u; pq.push({nd, v});
            }
        }
    }

    std::vector<vtkIdType> path;
    if (prev[(size_t)endId] == -1) return path;
    for (vtkIdType cur = endId; cur != startId; ) {
        path.push_back(cur);
        vtkIdType p = prev[(size_t)cur];
        if (p == -1) { path.clear(); return path; }
        cur = p;
    }
    path.push_back(startId);
    std::reverse(path.begin(), path.end());
    return path;
}

// Maximum concurrent paths supported (expand if needed)
static const NSInteger kMaxPaths = 200;

@interface GeodesicProcessor ()

@property (nonatomic, weak) ViewerController       *viewerController;
@property (nonatomic, weak) ProcessWindowController *windowController;
@property (nonatomic, weak) SurfaceLength3DFilter   *pluginFilter;
@property (nonatomic, assign) NSInteger              preferredSurfaceIndex; // -1 = auto

@end

@implementation GeodesicProcessor {
    vtkActor  *_pathActors[kMaxPaths];
    vtkMapper *_pathMappers[kMaxPaths];
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
        _pathLineWidth    = 3.0;
        memset(_pathActors,  0, sizeof(_pathActors));
        memset(_pathMappers, 0, sizeof(_pathMappers));
    }
    return self;
}

- (void)dealloc {
    // Do not touch cached VTK actors here.
    //
    // The Horos SR scene may already have been rebuilt or destroyed by the time
    // ARC releases this processor (for example when reopening the Process
    // window). In that case our cached actor pointers are stale and calling
    // RemoveActor/UnRegister on them can segfault immediately.
    //
    // Path cleanup must happen only through explicit UI-driven calls while the
    // owning SR viewer is known to still be alive.
}

// ---------------------------------------------------------------------------
#pragma mark - Surface actor detection
// ---------------------------------------------------------------------------

- (NSArray<NSDictionary *> *)availableSurfaceDescriptions {
    SRController *srViewer = [self.viewerController openSRViewer];
    if (!srViewer) return @[];

    vtkRenderer *rend = SL3DGetRenderer(srViewer.view);
    if (!rend) return @[];

    vtkActorCollection *actors = rend->GetActors();
    if (!actors) return @[];

    NSMutableArray *result = [NSMutableArray array];
    // GetNumberOfItems() reads wrong struct offset under VTK9/VTK8 ABI mismatch.
    // Use GetItemAsObject() returning nil as the end-of-collection sentinel instead.
    for (NSInteger i = 0; ; i++) {
        vtkActor *actor = (vtkActor *)actors->GetItemAsObject((int)i);
        if (!actor) break;
        vtkMapper *mapper = SL3DGetMapper(actor);
        vtkPolyData *pd = mapper ? (vtkPolyData *)mapper->GetInput() : nullptr;
        NSInteger polys = pd ? (NSInteger)SL3DGetPolyDataPolygonCount(pd) : -1;
        NSLog(@"[SL3D] availSurface: actor[%ld]=%p mapper=%p pd=%p polys=%ld",
              (long)i, actor, mapper, pd, (long)polys);
        if (polys < 500) continue;
        [result addObject:@{
            @"index":    @(result.count),
            @"polys":    @(polys),
            @"label":    [NSString stringWithFormat:@"Surface %ld (%ld polygons)",
                          (long)(result.count + 1), (long)polys]
        }];
    }
    return result;
}

- (nullable vtkActor *)surfaceActor {
    SRController *srViewer = [self.viewerController openSRViewer];
    if (!srViewer) { NSLog(@"[SL3D] surfaceActor: openSRViewer returned nil"); return nullptr; }

    vtkRenderer *rend = SL3DGetRenderer(srViewer.view);
    if (!rend) { NSLog(@"[SL3D] surfaceActor: SL3DGetRenderer returned nil"); return nullptr; }

    vtkActorCollection *actors = rend->GetActors();
    if (!actors) { NSLog(@"[SL3D] surfaceActor: GetActors returned nil"); return nullptr; }

    vtkActor *bestActor   = nullptr;
    vtkIdType bestPolys   = 0;
    vtkActor *chosenActor = nullptr;
    NSInteger qualifying  = 0;

    for (NSInteger i = 0; ; i++) {
        vtkActor *actor = (vtkActor *)actors->GetItemAsObject((int)i);
        if (!actor) break;
        vtkMapper *mapper = SL3DGetMapper(actor);
        vtkPolyData *pd = mapper ? (vtkPolyData *)mapper->GetInput() : nullptr;
        vtkIdType polys = pd ? SL3DGetPolyDataPolygonCount(pd) : -1;
        NSLog(@"[SL3D] surfaceActor: actor[%ld]=%p mapper=%p pd=%p polys=%lld",
              (long)i, actor, mapper, pd, (long long)polys);
        if (polys < 500) continue;

        if (polys > bestPolys) { bestPolys = polys; bestActor = actor; }
        if (qualifying == self.preferredSurfaceIndex) chosenActor = actor;
        qualifying++;
    }

    NSLog(@"[SL3D] surfaceActor: qualifying=%ld bestPolys=%lld bestActor=%p",
          (long)qualifying, (long long)bestPolys, bestActor);
    if (self.preferredSurfaceIndex >= 0 && chosenActor) return chosenActor;
    return bestActor;
}

// ---------------------------------------------------------------------------
#pragma mark - Path display / removal (must be called on main thread)
// ---------------------------------------------------------------------------

- (void)removePathAtIndex:(NSInteger)index {
    NSAssert(NSThread.isMainThread, @"removePathAtIndex: must be called on main thread");
    if (index < 0 || index >= kMaxPaths || !_pathActors[index]) return;

    SRController *srViewer = [self.viewerController openSRViewer];
    vtkRenderer  *rend     = SL3DGetRenderer(srViewer.view);

    // Keep lifetime management conservative: removing the actor from the scene
    // is stable, but destroying VTK objects has repeatedly crashed Horos under
    // the mixed VTK 8 runtime / VTK 9 headers setup.
    rend->vtkRenderer::RemoveActor(_pathActors[index]);
    _pathActors[index] = nullptr;
    _pathMappers[index] = nullptr;

    [srViewer.view setNeedsDisplay:YES];
}

- (void)removeAllPaths {
    NSAssert(NSThread.isMainThread, @"removeAllPaths must be called on main thread");
    NSInteger count = (NSInteger)self.pluginFilter.pairsResultsArray.count;
    for (NSInteger i = 0; i < count && i < kMaxPaths; i++) {
        [self removePathAtIndex:i];
    }
}

- (void)applyCurrentLineWidthToVisiblePaths {
    NSAssert(NSThread.isMainThread, @"applyCurrentLineWidthToVisiblePaths must be called on main thread");

    SRController *srViewer = [self.viewerController openSRViewer];
    if (!srViewer) return;

    for (NSInteger i = 0; i < kMaxPaths; i++) {
        if (!_pathActors[i] || !_pathMappers[i]) continue;
        [self displayPathAtIndex:i];
    }

    [srViewer.view setNeedsDisplay:YES];
}

- (void)displayPathAtIndex:(NSInteger)index {
    NSAssert(NSThread.isMainThread, @"displayPathAtIndex: must be called on main thread");
    if (index < 0 || index >= kMaxPaths) return;

    SRController *srViewer = [self.viewerController openSRViewer];
    if (!srViewer) { NSLog(@"[SL3D] displayPath %ld: srViewer nil", (long)index); return; }
    vtkRenderer *rend = SL3DGetRenderer(srViewer.view);
    if (!rend) { NSLog(@"[SL3D] displayPath %ld: rend nil", (long)index); return; }

    PointPair *pp = self.pluginFilter.pairsResultsArray[index];
    NSArray<NSValue *> *pts = pp.pathPoints;
    if (pts.count < 2) { NSLog(@"[SL3D] displayPath %ld: pathPoints too short", (long)index); return; }
    NSLog(@"[SL3D] displayPath %ld: pts=%lu color=%@", (long)index, (unsigned long)pts.count, pp.pathColor);

    vtkPolyData *inputData = SL3DBuildTubePolyData(pts, SL3DTubeRadiusForWidth(self.pathLineWidth));
    if (!inputData) {
        NSLog(@"[SL3D] displayPath %ld: failed to build tube polydata", (long)index);
        return;
    }

    // Connect mapper via vtkAlgorithm::SetInputDataObject — T symbol, bypasses
    // inline SetInputData which internally makes virtual SetInputDataInternal call.
    if (!_pathActors[index]) {
        _pathActors[index] = vtkActor::New();
        rend->vtkRenderer::AddActor(_pathActors[index]);
    }
    if (!_pathMappers[index]) {
        _pathMappers[index] = vtkPolyDataMapper::New();
        *reinterpret_cast<vtkMapper **>(
            reinterpret_cast<uint8_t *>(_pathActors[index]) + 0x178) = _pathMappers[index];
    }
    static_cast<vtkAlgorithm *>(_pathMappers[index])->vtkAlgorithm::SetInputDataObject(0, inputData);

    // GetProperty: explicit dispatch, then SetColor explicit dispatch
    vtkProperty *prop = _pathActors[index]->vtkActor::GetProperty();
    if (prop) {
        CGFloat r, g, b, a;
        [pp.pathColor getRed:&r green:&g blue:&b alpha:&a];
        prop->vtkProperty::SetColor((double)r, (double)g, (double)b);
    }

    [srViewer.view setNeedsDisplay:YES];

    SL3DDelete(inputData);
    // actor/mapper kept alive via cached arrays; deleting VTK objects in normal
    // UI flows remains crash-prone in Horos.
    NSLog(@"[SL3D] displayPath %ld: actor added, view marked dirty", (long)index);
}

// ---------------------------------------------------------------------------
#pragma mark - Coordinate helpers
// ---------------------------------------------------------------------------

- (void)getROILocation:(double *)loc forIndex:(NSInteger)index {
    NSMutableArray *pts = [self.viewerController point2DList];
    ROI    *roi = (ROI *)pts[index];
    DCMPix *dcm = roi.pix;

    float location[3];
    [dcm convertPixX:[roi.points[0] x] pixY:[roi.points[0] y] toDICOMCoords:location];
    loc[0] = location[0];
    loc[1] = location[1];
    loc[2] = location[2];
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
    vtkActor *actor = [self surfaceActor];
    if (!actor) {
        NSLog(@"[SL3D] processAll: surfaceActor returned nil — aborting");
        if (completion) dispatch_async(dispatch_get_main_queue(), completion);
        return;
    }

    vtkPolyDataMapper *sourceMapper = (vtkPolyDataMapper *)SL3DGetMapper(actor);
    if (!sourceMapper) {
        NSLog(@"[SL3D] processAll: SL3DGetMapper returned nil — aborting");
        if (completion) dispatch_async(dispatch_get_main_queue(), completion);
        return;
    }
    vtkPolyData *sourceData = sourceMapper->GetInput();

    // Prefer the actor's cached model->world matrix. It is the authoritative
    // transform that Horos uses to place the surface mesh in patient space.
    // Read it directly from vtkProp3D ivars to avoid vtkProp3D::GetMatrix(),
    // which crashes under the VTK 8/9 ABI mismatch.
    //
    // Fallback to the old DCMPix-derived matrix only if the actor matrix is not
    // available. That fallback is known to place paths incorrectly in z.
    SL3DMatrix44 fwdMat = {}, invMat = {};
    for (int i = 0; i < 4; i++) fwdMat.m[i][i] = invMat.m[i][i] = 1.0;
    if (SL3DGetActorMatrix(actor, fwdMat)) {
        SL3DInvertMatrix44(fwdMat.m, invMat.m);
        NSLog(@"[SL3D] actorMat[0]: %.3f %.3f %.3f %.3f",
              fwdMat.m[0][0], fwdMat.m[0][1], fwdMat.m[0][2], fwdMat.m[0][3]);
        NSLog(@"[SL3D] actorMat[1]: %.3f %.3f %.3f %.3f",
              fwdMat.m[1][0], fwdMat.m[1][1], fwdMat.m[1][2], fwdMat.m[1][3]);
        NSLog(@"[SL3D] actorMat[2]: %.3f %.3f %.3f %.3f",
              fwdMat.m[2][0], fwdMat.m[2][1], fwdMat.m[2][2], fwdMat.m[2][3]);
    } else {
        NSMutableArray<DCMPix *> *pixList = [self.viewerController pixList];
        DCMPix *pix0 = pixList.count > 0 ? pixList[0] : nil;
        DCMPix *pix1 = pixList.count > 1 ? pixList[1] : nil;

        if (pix0) {
            double ox = pix0.originX, oy = pix0.originY, oz = pix0.originZ;

            float orient[6] = {};
            [pix0 orientation:orient];
            double rx = orient[0], ry = orient[1], rz = orient[2];
            double cx = orient[3], cy = orient[4], cz = orient[5];

            double nx, ny, nz;
            if (pix1) {
                double dx = pix1.originX - pix0.originX;
                double dy = pix1.originY - pix0.originY;
                double dz = pix1.originZ - pix0.originZ;
                double len = sqrt(dx*dx + dy*dy + dz*dz);
                if (len > 1e-6) { nx = dx/len; ny = dy/len; nz = dz/len; }
                else             { nx = ry*cz - rz*cy; ny = rz*cx - rx*cz; nz = rx*cy - ry*cx; }
            } else {
                nx = ry*cz - rz*cy; ny = rz*cx - rx*cz; nz = rx*cy - ry*cx;
            }

            NSLog(@"[SL3D] actorMat unavailable; falling back to DCMPix");
            NSLog(@"[SL3D] DCMPix pix0 origin=(%.2f,%.2f,%.2f) si=%.3f",
                  ox, oy, oz, (double)pix0.sliceInterval);

            fwdMat.m[0][0] = rx;  fwdMat.m[0][1] = cx;  fwdMat.m[0][2] = nx;  fwdMat.m[0][3] = ox;
            fwdMat.m[1][0] = ry;  fwdMat.m[1][1] = cy;  fwdMat.m[1][2] = ny;  fwdMat.m[1][3] = oy;
            fwdMat.m[2][0] = rz;  fwdMat.m[2][1] = cz;  fwdMat.m[2][2] = nz;  fwdMat.m[2][3] = oz;
            fwdMat.m[3][0] = 0;   fwdMat.m[3][1] = 0;   fwdMat.m[3][2] = 0;   fwdMat.m[3][3] = 1;
            SL3DInvertMatrix44(fwdMat.m, invMat.m);
        } else {
            NSLog(@"[SL3D] actorMat and DCMPix unavailable — using identity transform");
        }
    }

    NSArray<PointPair *> *pairs = [self.pluginFilter.pairsResultsArray copy];
    NSLog(@"[SL3D] processAll: sourceData=%p polys=%lld pairs=%lu",
          sourceData, (long long)(sourceData ? SL3DGetPolyDataPolygonCount(sourceData) : -1),
          (unsigned long)pairs.count);

    // -----------------------------------------------------------------
    // DEEP-COPY mesh data on main thread.
    // Horos's VTK render thread may free/replace the mesh at any time.
    // After this copy the background block never touches VTK-owned memory.
    // -----------------------------------------------------------------
    // Read vertex float buffer pointer
    vtkPoints    *meshPts = *reinterpret_cast<vtkPoints **>(
        reinterpret_cast<uint8_t *>(sourceData) + 0xe8);
    vtkDataArray *meshDA  = meshPts ? *reinterpret_cast<vtkDataArray **>(
        reinterpret_cast<uint8_t *>(meshPts) + 0x68) : nullptr;
    void *vbuf = meshDA ? *reinterpret_cast<void **>(
        reinterpret_cast<uint8_t *>(meshDA) + 0xe0) : nullptr;
    float *srcVerts = vbuf ? *reinterpret_cast<float **>(
        reinterpret_cast<uint8_t *>(vbuf) + 0x30) : nullptr;

    // Read polygon flat-buffer pointer
    void *polysArr = *reinterpret_cast<void **>(
        reinterpret_cast<uint8_t *>(sourceData) + 0x150);
    vtkIdType numPolys = SL3DReadCellArrayCount(polysArr);
    void *pIA  = polysArr ? *reinterpret_cast<void **>(
        reinterpret_cast<uint8_t *>(polysArr) + 0x48) : nullptr;
    void *pBuf = pIA ? *reinterpret_cast<void **>(
        reinterpret_cast<uint8_t *>(pIA) + 0xe0) : nullptr;
    vtkIdType *srcPolys = pBuf ? *reinterpret_cast<vtkIdType **>(
        reinterpret_cast<uint8_t *>(pBuf) + 0x30) : nullptr;

    if (!srcVerts || !srcPolys || numPolys <= 0) {
        NSLog(@"[SL3D] processAll: invalid mesh pointers — aborting");
        if (completion) dispatch_async(dispatch_get_main_queue(), completion);
        return;
    }

    // Scan polygon buffer (on main thread, safer) to find numPts and total buffer size
    vtkIdType maxVertId = 0, totalPolyBufSize = 0, pos = 0;
    for (vtkIdType p = 0; p < numPolys; p++) {
        vtkIdType n = srcPolys[pos++];
        totalPolyBufSize++;
        if (n >= 2 && n <= 32) {
            for (vtkIdType j = 0; j < n; j++)
                if (srcPolys[pos+j] > maxVertId) maxVertId = srcPolys[pos+j];
            pos += n; totalPolyBufSize += n;
        } else if (n >= 2) {
            pos += n; totalPolyBufSize += n;
        }
    }
    vtkIdType numPts = maxVertId + 1;
    NSLog(@"[SL3D] mesh copy: numPts=%lld numPolys=%lld polyBufElems=%lld",
          (long long)numPts, (long long)numPolys, (long long)totalPolyBufSize);

    // Guard against integer overflow before multiplying untrusted mesh dimensions
    const vtkIdType kMaxSafePts = (vtkIdType)(SIZE_MAX / (3 * sizeof(float)));
    const vtkIdType kMaxSafePoly = (vtkIdType)(SIZE_MAX / sizeof(vtkIdType));
    if (numPts <= 0 || numPts > kMaxSafePts || totalPolyBufSize <= 0 || totalPolyBufSize > kMaxSafePoly) {
        NSLog(@"[SL3D] processAll: mesh dimensions out of safe range — aborting");
        if (completion) dispatch_async(dispatch_get_main_queue(), completion);
        return;
    }

    // Deep-copy — ARC-managed NSData owns the buffers; background block retains them
    NSData *copiedVerts = [NSData dataWithBytes:srcVerts
                                         length:(NSUInteger)(numPts * 3 * sizeof(float))];
    NSData *copiedPolys = [NSData dataWithBytes:srcPolys
                                         length:(NSUInteger)(totalPolyBufSize * sizeof(vtkIdType))];

    // Collect all ROI world coords on main thread (ROI/DCMPix are main-thread-only)
    NSMutableArray<NSArray *> *roiCoords = [NSMutableArray arrayWithCapacity:pairs.count];
    for (PointPair *pp in pairs) {
        double l1[3] = {}, l2[3] = {};
        [self getROILocation:l1 forIndex:pp.p1ROIIndex];
        [self getROILocation:l2 forIndex:pp.p2ROIIndex];
        NSLog(@"[SL3D] ROI '%@'/'%@': l1=(%.2f,%.2f,%.2f) l2=(%.2f,%.2f,%.2f)",
              pp.p1Name, pp.p2Name, l1[0],l1[1],l1[2], l2[0],l2[1],l2[2]);
        [roiCoords addObject:@[@(l1[0]),@(l1[1]),@(l1[2]),@(l2[0]),@(l2[1]),@(l2[2])]];
    }

    // Capture copies by value; background block never touches VTK objects again
    vtkIdType capturedNumPts = numPts;
    vtkIdType capturedNumPolys = numPolys;
    fprintf(stderr, "[SL3D] dispatch_async firing\n"); fflush(stderr);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        fprintf(stderr, "[SL3D] BG ENTERED numPts=%lld numPolys=%lld\n",
                (long long)capturedNumPts, (long long)capturedNumPolys);
        fflush(stderr);
      try {
        const float     *verts = (const float *)copiedVerts.bytes;
        const vtkIdType *polys = (const vtkIdType *)copiedPolys.bytes;

        // Build adjacency once; reuse for all pairs — CSR: 3 large allocs, no fragmentation
        SL3DAdjCSR adj;
        SL3DBuildAdjCSR(polys, capturedNumPolys, capturedNumPts, adj);

        for (NSInteger pathIndex = 0; pathIndex < (NSInteger)pairs.count; pathIndex++) {
            PointPair *pp = pairs[pathIndex];

            dispatch_async(dispatch_get_main_queue(), ^{
                pp.state = PointPairStateCalculating;
                [self.windowController updateResultsColumn];
            });

            NSArray *rc = roiCoords[pathIndex];
            double roiLoc1[3] = { [rc[0] doubleValue], [rc[1] doubleValue], [rc[2] doubleValue] };
            double roiLoc2[3] = { [rc[3] doubleValue], [rc[4] doubleValue], [rc[5] doubleValue] };

            // Transform ROI world coords → mesh object space
            double meshLoc1[3], meshLoc2[3];
            SL3DTransformPoint(invMat.m, roiLoc1, meshLoc1);
            SL3DTransformPoint(invMat.m, roiLoc2, meshLoc2);

            vtkIdType closestPt1 = SL3DFindClosestInBuffer(verts, capturedNumPts, meshLoc1);
            vtkIdType closestPt2 = SL3DFindClosestInBuffer(verts, capturedNumPts, meshLoc2);
            NSLog(@"[SL3D] pair %ld: roi1=(%.1f,%.1f,%.1f) mesh1=(%.1f,%.1f,%.1f) snap1=%lld(%.1f,%.1f,%.1f)",
                  (long)pathIndex, roiLoc1[0],roiLoc1[1],roiLoc1[2],
                  meshLoc1[0],meshLoc1[1],meshLoc1[2],
                  (long long)closestPt1, verts[closestPt1*3],verts[closestPt1*3+1],verts[closestPt1*3+2]);
            NSLog(@"[SL3D] pair %ld: roi2=(%.1f,%.1f,%.1f) mesh2=(%.1f,%.1f,%.1f) snap2=%lld(%.1f,%.1f,%.1f)",
                  (long)pathIndex, roiLoc2[0],roiLoc2[1],roiLoc2[2],
                  meshLoc2[0],meshLoc2[1],meshLoc2[2],
                  (long long)closestPt2, verts[closestPt2*3],verts[closestPt2*3+1],verts[closestPt2*3+2]);

            std::vector<vtkIdType> pathIds = SL3DDijkstra(verts, adj, closestPt1, closestPt2);
            NSLog(@"[SL3D] pair %ld: Dijkstra pathSize=%lu",
                  (long)pathIndex, (unsigned long)pathIds.size());

            if (pathIds.size() < 2) {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    pp.state = PointPairStateNone;
                    [self.windowController updateResultsColumn];
                });
                continue;
            }

            NSMutableArray<NSValue *> *waypoints = [NSMutableArray array];
            double pathLength = 0.0;
            BOOL   clockwise  = NO;
            double prevWorld[3] = {0.0, 0.0, 0.0};
            BOOL havePrevWorld = NO;

            NSInteger midIdx = (NSInteger)(pathIds.size() / 2);
            for (NSInteger k = 0; k < (NSInteger)pathIds.size(); k++) {
                vtkIdType vid = pathIds[(NSUInteger)k];
                double mesh[3] = { verts[vid*3], verts[vid*3+1], verts[vid*3+2] };
                double world[3];
                SL3DTransformPoint(fwdMat.m, mesh, world);

                SL3DPoint pt3 = { world[0], world[1], world[2] };
                [waypoints addObject:[NSValue valueWithBytes:&pt3 objCType:@encode(SL3DPoint)]];

                if (havePrevWorld) {
                    double seg = std::sqrt((world[0]-prevWorld[0])*(world[0]-prevWorld[0]) +
                                           (world[1]-prevWorld[1])*(world[1]-prevWorld[1]) +
                                           (world[2]-prevWorld[2])*(world[2]-prevWorld[2]));
                    pathLength += seg;
                }
                prevWorld[0] = world[0]; prevWorld[1] = world[1]; prevWorld[2] = world[2];
                havePrevWorld = YES;

                if (k == midIdx) {
                    clockwise = [self isClockwiseFromP1:roiLoc1 p2:roiLoc2 midPath:world];
                }
            }

            NSArray<NSValue *> *frozenWaypoints = [waypoints copy];
            double    frozenLength = pathLength;
            BOOL      frozenCW     = clockwise;
            NSInteger frozenIdx    = pathIndex;

            dispatch_sync(dispatch_get_main_queue(), ^{
                pp.distanceSurface = frozenLength;
                pp.pathPoints      = frozenWaypoints;
                pp.clockwise       = frozenCW;
                pp.state           = PointPairStateCalculated;
                [self displayPathAtIndex:frozenIdx];
                [self.windowController updateResultsColumn];
            });
        }

        dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(); });
      } catch (const std::exception &cppEx) {
        fprintf(stderr, "[SL3D] C++ EXCEPTION in bg block: %s\n", cppEx.what());
        fflush(stderr);
        dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(); });
      } catch (...) {
        fprintf(stderr, "[SL3D] UNKNOWN C++ EXCEPTION in bg block\n");
        fflush(stderr);
        dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(); });
      }
    });
}

@end
