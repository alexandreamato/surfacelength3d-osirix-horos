// ValidationPhantom.mm — geometric validation of the Dijkstra geodesic algorithm
// Creates synthetic meshes with analytically known distances and measures % error.

#import "ValidationPhantom.h"

#ifdef __cplusplus
#define id Id
#include "vtkDijkstraGraphGeodesicPath.h"
#include "vtkPointLocator.h"
#include "vtkPolyData.h"
#include "vtkSphereSource.h"
#include "vtkCylinderSource.h"
#include "vtkTriangleFilter.h"
#include "vtkPoints.h"
#include "vtkIdList.h"
#include "vtkMath.h"
#undef id
#endif

// ---------------------------------------------------------------------------
#pragma mark - PhantomTestCase
// ---------------------------------------------------------------------------

@interface PhantomTestCase ()
@property (nonatomic, copy) NSString *label;
@property (nonatomic) double analyticalDistance;
@property (nonatomic) double measuredDistance;
@end

@implementation PhantomTestCase
- (double)absoluteError { return fabs(self.measuredDistance - self.analyticalDistance); }
- (double)percentError  {
    if (self.analyticalDistance < 1e-9) return 0;
    return (self.absoluteError / self.analyticalDistance) * 100.0;
}
@end

// ---------------------------------------------------------------------------
#pragma mark - ValidationPhantomResult
// ---------------------------------------------------------------------------

@interface ValidationPhantomResult ()
@property (nonatomic) PhantomShape shape;
@property (nonatomic) double radius;
@property (nonatomic) NSInteger meshResolution;
@property (nonatomic, copy) NSArray<PhantomTestCase *> *testCases;
@end

@implementation ValidationPhantomResult

- (BOOL)available {
    return self.testCases.count > 0;
}

- (double)meanPercentError {
    if (!self.testCases.count) return 0;
    double sum = 0;
    for (PhantomTestCase *tc in self.testCases) sum += tc.percentError;
    return sum / self.testCases.count;
}

- (double)maxPercentError {
    double max = 0;
    for (PhantomTestCase *tc in self.testCases) {
        if (tc.percentError > max) max = tc.percentError;
    }
    return max;
}

- (NSString *)summary {
    NSString *shapeName = (self.shape == PhantomShapeSphere) ? @"Sphere" : @"Cylinder";
    if (!self.testCases.count)
        return [NSString stringWithFormat:
            @"%@ R=%.0fmm, res=%ld: phantom validation unavailable in Horos runtime (VTK ABI mismatch).",
            shapeName, self.radius, (long)self.meshResolution];
    return [NSString stringWithFormat:
        @"%@ R=%.0fmm, res=%ld: mean error=%.2f%%, max error=%.2f%%\n"
        @"Based on %lu test cases with analytically known distances.\n"
        @"Error < 1%% = excellent, < 2%% = acceptable for surgical planning.",
        shapeName, self.radius, (long)self.meshResolution,
        self.meanPercentError, self.maxPercentError,
        (unsigned long)self.testCases.count];
}

@end

// ---------------------------------------------------------------------------
#pragma mark - ValidationPhantom
// ---------------------------------------------------------------------------

@implementation ValidationPhantom

+ (void)validateShape:(PhantomShape)shape
               radius:(double)radius
       meshResolution:(NSInteger)resolution
           completion:(void (^)(ValidationPhantomResult *))completion {

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{

        ValidationPhantomResult *result = [self runValidation:shape radius:radius resolution:resolution];

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(result);
        });
    });
}

+ (ValidationPhantomResult *)runValidation:(PhantomShape)shape
                                    radius:(double)R
                                resolution:(NSInteger)res {

    // VTK source/filter objects (vtkSphereSource, vtkCylinderSource, vtkTriangleFilter)
    // use virtual methods whose vtable layout differs between Horos's embedded VTK 8 and
    // the VTK 9.5 headers we compile against. Calling them crashes. Return a stub result.
    ValidationPhantomResult *stub = [[ValidationPhantomResult alloc] init];
    stub.shape          = shape;
    stub.radius         = R;
    stub.meshResolution = res;
    stub.testCases      = @[];
    return stub;

    // --- unreachable below; kept for future standalone (non-Horos) build ---
    vtkPolyData *mesh = nullptr;
    vtkSphereSource    *sphere   = nullptr;
    vtkCylinderSource  *cylinder = nullptr;
    vtkTriangleFilter  *triFilter = vtkTriangleFilter::New();

    if (shape == PhantomShapeSphere) {
        sphere = vtkSphereSource::New();
        sphere->SetRadius(R);
        sphere->SetThetaResolution((int)res);
        sphere->SetPhiResolution((int)res);
        sphere->SetStartPhi(0.0001);  // avoid degenerate poles
        sphere->SetEndPhi(179.999);
        sphere->Update();
        triFilter->SetInputConnection(sphere->GetOutputPort());
    } else {
        cylinder = vtkCylinderSource::New();
        cylinder->SetRadius(R);
        cylinder->SetHeight(R * 4.0);
        cylinder->SetResolution((int)res);
        cylinder->SetCapping(NO);
        cylinder->Update();
        triFilter->SetInputConnection(cylinder->GetOutputPort());
    }
    triFilter->Update();
    mesh = triFilter->GetOutput();

    // Build test cases with analytically known distances
    NSMutableArray<PhantomTestCase *> *cases = [NSMutableArray array];

    if (shape == PhantomShapeSphere) {
        // Test cases: pairs of (phi1,theta1) -> (phi2,theta2) in radians
        // Analytical great-circle distance = R * arccos(P1·P2 / R²)
        NSArray *testAngles = @[
            // @[phi1, theta1, phi2, theta2]
            @[@(0.0),        @(0.0),    @(M_PI/2.0),  @(0.0)],    // Quarter meridian
            @[@(0.0),        @(0.0),    @(M_PI/4.0),  @(0.0)],    // 1/8 meridian
            @[@(M_PI/4.0),   @(0.0),    @(M_PI/4.0),  @(M_PI/2)], // Parallel arc
            @[@(M_PI/6.0),   @(0.0),    @(M_PI/3.0),  @(M_PI/3)], // Diagonal
            @[@(M_PI/8.0),   @(0.0),    @(5*M_PI/8.0),@(0.0)],    // Near-hemispherical
        ];

        vtkPointLocator *locator = vtkPointLocator::New();
        locator->SetDataSet(mesh);
        locator->BuildLocator();

        for (NSUInteger i = 0; i < testAngles.count; i++) {
            NSArray *a = testAngles[i];
            double phi1   = [a[0] doubleValue], theta1 = [a[1] doubleValue];
            double phi2   = [a[2] doubleValue], theta2 = [a[3] doubleValue];

            // Cartesian coordinates on sphere (VTK sphere: z up, equator in XY)
            double x1 = R * sin(phi1) * cos(theta1);
            double y1 = R * sin(phi1) * sin(theta1);
            double z1 = R * cos(phi1);

            double x2 = R * sin(phi2) * cos(theta2);
            double y2 = R * sin(phi2) * sin(theta2);
            double z2 = R * cos(phi2);

            double dot     = x1*x2 + y1*y2 + z1*z2;
            double cosAngle = dot / (R * R);
            cosAngle = MAX(-1.0, MIN(1.0, cosAngle));  // clamp for numerical safety
            double analytical = R * acos(cosAngle);

            vtkIdType id1 = locator->FindClosestPoint(x1, y1, z1);
            vtkIdType id2 = locator->FindClosestPoint(x2, y2, z2);

            double measured = [self dijkstraDistance:mesh from:id1 to:id2];

            PhantomTestCase *tc = [[PhantomTestCase alloc] init];
            tc.label = [NSString stringWithFormat:@"Case %lu (φ=%.0f°→%.0f°)",
                        (unsigned long)(i+1), phi1*180/M_PI, phi2*180/M_PI];
            tc.analyticalDistance = analytical;
            tc.measuredDistance   = measured;
            [cases addObject:tc];
        }
        locator->Delete();

    } else {
        // Cylinder: analytical geodesic = sqrt(deltaZ² + (R*deltaTheta)²)
        // (unwrapped cylinder is flat — geodesic is a straight line on the unrolled surface)
        NSArray *testPoints = @[
            // @[z1, theta1, z2, theta2]
            @[@(0.0),    @(0.0),    @(R),       @(0.0)],     // Along axis
            @[@(0.0),    @(0.0),    @(0.0),     @(M_PI/2)],  // Around circumference
            @[@(0.0),    @(0.0),    @(R),       @(M_PI/2)],  // Helical
            @[@(-R),     @(0.0),    @(R),       @(M_PI)],    // Long helix
        ];

        vtkPointLocator *locator = vtkPointLocator::New();
        locator->SetDataSet(mesh);
        locator->BuildLocator();

        for (NSUInteger i = 0; i < testPoints.count; i++) {
            NSArray *a = testPoints[i];
            double z1 = [a[0] doubleValue], t1 = [a[1] doubleValue];
            double z2 = [a[2] doubleValue], t2 = [a[3] doubleValue];

            double x1 = R * cos(t1), y1 = R * sin(t1);
            double x2 = R * cos(t2), y2 = R * sin(t2);

            double dz    = z2 - z1;
            double dTheta = t2 - t1;
            double analytical = sqrt(dz*dz + (R*dTheta)*(R*dTheta));

            vtkIdType id1 = locator->FindClosestPoint(x1, y1, z1);
            vtkIdType id2 = locator->FindClosestPoint(x2, y2, z2);

            double measured = [self dijkstraDistance:mesh from:id1 to:id2];

            PhantomTestCase *tc = [[PhantomTestCase alloc] init];
            tc.label = [NSString stringWithFormat:@"Case %lu (Δz=%.0f, Δθ=%.0f°)",
                        (unsigned long)(i+1), dz, dTheta*180/M_PI];
            tc.analyticalDistance = analytical;
            tc.measuredDistance   = measured;
            [cases addObject:tc];
        }
        locator->Delete();
    }

    triFilter->Delete();
    if (sphere)   sphere->Delete();
    if (cylinder) cylinder->Delete();

    ValidationPhantomResult *result = [[ValidationPhantomResult alloc] init];
    result.shape          = shape;
    result.radius         = R;
    result.meshResolution = res;
    result.testCases      = cases;
    return result;
}

+ (double)dijkstraDistance:(vtkPolyData *)mesh from:(vtkIdType)id1 to:(vtkIdType)id2 {
    vtkDijkstraGraphGeodesicPath *path = vtkDijkstraGraphGeodesicPath::New();
    path->SetInputData(mesh);
    path->SetStartVertex(id1);
    path->SetEndVertex(id2);
    path->SetStopWhenEndReached(1);
    path->Update();

    vtkIdList *ids = path->GetIdList();
    vtkPoints *pts = mesh->GetPoints();
    double length  = 0.0;
    double prev[3], curr[3];

    if (ids->GetNumberOfIds() < 2) { path->Delete(); return 0; }

    pts->GetPoint(ids->GetId(0), prev);
    for (vtkIdType k = 1; k < ids->GetNumberOfIds(); k++) {
        pts->GetPoint(ids->GetId(k), curr);
        double dx = curr[0]-prev[0], dy = curr[1]-prev[1], dz = curr[2]-prev[2];
        length += sqrt(dx*dx + dy*dy + dz*dz);
        prev[0] = curr[0]; prev[1] = curr[1]; prev[2] = curr[2];
    }
    path->Delete();
    return length;
}

@end
