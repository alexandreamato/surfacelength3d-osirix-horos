#import "AnatomicalLabelSet.h"

@interface AnatomicalLabelSet ()
@property (nonatomic, assign) AnatomicalContext context;
@property (nonatomic, copy)   NSString *name;
@property (nonatomic, copy)   NSArray<NSString *> *labels;
@end

@implementation AnatomicalLabelSet

+ (NSArray<AnatomicalLabelSet *> *)availableSets {
    return @[
        [self setForContext:AnatomicalContextVascular],
        [self setForContext:AnatomicalContextNeurology],
        [self setForContext:AnatomicalContextPlastic],
        [self setForContext:AnatomicalContextGeneric],
    ];
}

+ (instancetype)setForContext:(AnatomicalContext)context {
    AnatomicalLabelSet *s = [[self alloc] init];
    s.context = context;
    switch (context) {
        case AnatomicalContextVascular:
            s.name   = NSLocalizedString(@"Vascular (Aorta)", nil);
            s.labels = @[@"Celiac", @"Sup. Mesenteric", @"Renal R", @"Renal L", @"Aorta"];
            break;
        case AnatomicalContextNeurology:
            s.name   = NSLocalizedString(@"Neurosurgery (Skull)", nil);
            s.labels = @[@"Nasion", @"Inion", @"Bregma", @"Lambda", @"Tragus R", @"Tragus L", @"Pterion R", @"Pterion L"];
            break;
        case AnatomicalContextPlastic:
            s.name   = NSLocalizedString(@"Plastic Surgery (Landmarks)", nil);
            s.labels = @[@"Glabella", @"Nasal Tip", @"Subnasale", @"Menton", @"Canthus R", @"Canthus L", @"Tragus R", @"Tragus L"];
            break;
        case AnatomicalContextGeneric:
            s.name   = NSLocalizedString(@"Generic", nil);
            s.labels = @[@"P1",@"P2",@"P3",@"P4",@"P5",@"P6",@"P7",@"P8",@"P9",@"P10"];
            break;
    }
    return s;
}

+ (NSArray<NSString *> *)allContextNames {
    NSMutableArray *names = [NSMutableArray array];
    for (AnatomicalLabelSet *s in [self availableSets]) [names addObject:s.name];
    return names;
}

+ (NSArray<NSString *> *)pointNamesForContext:(AnatomicalContext)context {
    return [self setForContext:context].labels;
}

- (NSString *)labelForIndex:(NSUInteger)index {
    return self.labels[index % self.labels.count];
}

- (NSString *)description {
    return self.name;
}

@end
