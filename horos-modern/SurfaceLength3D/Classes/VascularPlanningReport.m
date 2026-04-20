#import "VascularPlanningReport.h"
#import "PointPair.h"

// Vessel name recognition — returns YES if the string maps to a known visceral vessel
static BOOL isKnownVesselName(NSString *name) {
    NSString *n = [name lowercaseString];
    NSArray *patterns = @[
        @"cel", @"sma", @"mesenter", @"renal"
    ];
    for (NSString *p in patterns) {
        if ([n containsString:p]) return YES;
    }
    return NO;
}

// ---------------------------------------------------------------------------

@implementation VascularPlanningResult
- (instancetype)initWithRecommendation:(GraftRecommendation)rec
                                 label:(NSString *)label
                             rationale:(NSString *)rationale
                       maxDistance:(double)maxDist
                   boundingDiameter:(double)diameter
                      detectedVessels:(NSArray<NSString *> *)vessels {
    self = [super init];
    if (self) {
        _recommendation          = rec;
        _recommendationLabel     = label;
        _rationale               = rationale;
        _maxInterVesselDistance  = maxDist;
        _boundingBoxDiameter     = diameter;
        _detectedVessels         = [vessels copy];
        _disclaimer              = @"⚠ Decision support tool only. Does not replace the surgeon's clinical judgment. Phantom validation still required (see DOI: 10.1590/1677-5449.005316).";
    }
    return self;
}
@end

// ---------------------------------------------------------------------------

@implementation VascularPlanningReport

+ (VascularPlanningResult *)analyzeWithPairs:(NSArray<PointPair *> *)pairs {

    // Collect pairs where both points are known vessels and measurement is done
    NSMutableSet<NSString *> *detectedSet = [NSMutableSet set];
    NSMutableArray<PointPair *> *vesselPairs = [NSMutableArray array];

    for (PointPair *pp in pairs) {
        if (pp.state != PointPairStateCalculated) continue;
        if (isKnownVesselName(pp.p1Name) && isKnownVesselName(pp.p2Name)) {
            [vesselPairs addObject:pp];
            [detectedSet addObject:pp.p1Name];
            [detectedSet addObject:pp.p2Name];
        }
    }

    if (vesselPairs.count == 0) {
        return [[VascularPlanningResult alloc]
            initWithRecommendation:GraftRecommendationInconclusive
                             label:@"Inconclusive"
                         rationale:@"No visceral vessel pairs recognized. Use anatomical labels: Celiac, Sup. Mesenteric, Right Renal, Left Renal."
                       maxDistance:0 boundingDiameter:0
                    detectedVessels:@[]];
    }

    // Max geodesic distance between any two vessels
    double maxDist = 0;
    for (PointPair *pp in vesselPairs) {
        if (pp.distanceSurface > maxDist) maxDist = pp.distanceSurface;
    }

    // Approximate bounding box diameter: largest surface distance among all pairs
    // (a proxy for the spatial spread of the ostia cluster)
    double diameter = maxDist;

    // Decision thresholds (mm) — based on Coselli graft sizing and general literature
    // Patch: all vessels within ~25mm → single elliptical patch may accommodate all ostia
    // Coselli: spread 25–55mm → standard Coselli 4-branch graft
    // Individual: spread >55mm → individual reimplantation or bypass required
    GraftRecommendation rec;
    NSString *label, *rationale;

    if (diameter <= 25.0) {
        rec = GraftRecommendationPatch;
        label = @"Single patch (island technique)";
        rationale = [NSString stringWithFormat:
            @"Maximum inter-ostial distance: %.1f mm (≤ 25 mm). "
            @"Visceral vessels are clustered — a single elliptical patch can accommodate all ostia in one reimplantation.",
            maxDist];
    } else if (diameter <= 55.0) {
        rec = GraftRecommendationCoselliGraft;
        label = @"Coselli graft (4-branch)";
        rationale = [NSString stringWithFormat:
            @"Maximum inter-ostial distance: %.1f mm (25–55 mm). "
            @"Moderate spread — a 4-branch Coselli branched graft is the standard strategy for this configuration.",
            maxDist];
    } else {
        rec = GraftRecommendationIndividual;
        label = @"Individual reimplantation / bypasses";
        rationale = [NSString stringWithFormat:
            @"Maximum inter-ostial distance: %.1f mm (> 55 mm). "
            @"Wide spread — individual reimplantation of each vessel or separate bypasses should be considered.",
            maxDist];
    }

    return [[VascularPlanningResult alloc]
        initWithRecommendation:rec
                         label:label
                     rationale:rationale
                   maxDistance:maxDist
             boundingDiameter:diameter
                detectedVessels:[detectedSet allObjects]];
}

@end
