// AnatomicalLabelSet.h — preset label sets for clinical contexts

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, AnatomicalContext) {
    AnatomicalContextVascular   = 0,   // Celíaco, SMA, Renal D, Renal E, Aorta
    AnatomicalContextNeurology  = 1,   // Naso, Inio, Tragus D, Tragus E, Bregma, Lambda
    AnatomicalContextPlastic    = 2,   // Canto D/E, Ponta nasal, Mento, ...
    AnatomicalContextGeneric    = 3,   // P1, P2, P3 ... (padrão)
};

@interface AnatomicalLabelSet : NSObject

@property (nonatomic, readonly) AnatomicalContext context;
@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly, copy) NSArray<NSString *> *labels;

+ (NSArray<AnatomicalLabelSet *> *)availableSets;
+ (instancetype)setForContext:(AnatomicalContext)context;

/// Display names for all contexts, ordered by enum value — use to populate a pop-up menu.
+ (NSArray<NSString *> *)allContextNames;

/// Point label list for a specific context — use to name ROI points.
+ (NSArray<NSString *> *)pointNamesForContext:(AnatomicalContext)context;

/// Returns the label at index, cycling if more points than labels exist.
- (NSString *)labelForIndex:(NSUInteger)index;

@end

NS_ASSUME_NONNULL_END
