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
            s.labels = @[@"Celíaco", @"Mesentérica Sup.", @"Renal D", @"Renal E", @"Aorta"];
            break;
        case AnatomicalContextNeurology:
            s.name   = NSLocalizedString(@"Neurocirurgia (Crânio)", nil);
            s.labels = @[@"Naso", @"Ínio", @"Bregma", @"Lambda", @"Tragus D", @"Tragus E", @"Pterion D", @"Pterion E"];
            break;
        case AnatomicalContextPlastic:
            s.name   = NSLocalizedString(@"Plástica (Landmarks)", nil);
            s.labels = @[@"Glabela", @"Ponta Nasal", @"Subnasal", @"Mento", @"Canto D", @"Canto E", @"Tragus D", @"Tragus E"];
            break;
        case AnatomicalContextGeneric:
            s.name   = NSLocalizedString(@"Genérico", nil);
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
