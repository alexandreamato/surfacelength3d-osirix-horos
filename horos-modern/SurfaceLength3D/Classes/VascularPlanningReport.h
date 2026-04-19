// VascularPlanningReport.h — surgical decision support for aortic visceral vessel planning
//
// Analyzes geodesic distances between visceral ostia and suggests graft strategy.
// Based on: Coselli JS et al., Crawford Classification, and general vascular surgery principles.
//
// ⚠ DECISION SUPPORT ONLY — Not a substitute for clinical judgement.

#import <Foundation/Foundation.h>

@class PointPair;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, GraftRecommendation) {
    GraftRecommendationPatch,           // All vessels close — single elliptical patch
    GraftRecommendationCoselliGraft,    // Moderate spread — branched Coselli graft
    GraftRecommendationIndividual,      // Wide spread — individual reimplantation / bypasses
    GraftRecommendationInconclusive,    // Insufficient labelled data
};

@interface VascularPlanningResult : NSObject

@property (nonatomic, readonly) GraftRecommendation recommendation;
@property (nonatomic, readonly, copy) NSString *recommendationLabel;
@property (nonatomic, readonly, copy) NSString *rationale;
@property (nonatomic, readonly) double maxInterVesselDistance;   // mm
@property (nonatomic, readonly) double boundingBoxDiameter;       // mm — largest dimension
@property (nonatomic, readonly, copy) NSArray<NSString *> *detectedVessels;
@property (nonatomic, readonly, copy) NSString *disclaimer;

@end


@interface VascularPlanningReport : NSObject

/// Analyses pairs whose names match known visceral vessel labels.
/// Recognised names (any language): Celíaco/Celiac, SMA/Mesentérica, Renal D/R, Renal E/L.
+ (VascularPlanningResult *)analyzeWithPairs:(NSArray<PointPair *> *)pairs;

@end

NS_ASSUME_NONNULL_END
