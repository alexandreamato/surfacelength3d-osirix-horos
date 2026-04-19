// SurfaceLength3DFilter.h — Horos plugin entry point

#import <Foundation/Foundation.h>
#import <OsiriXAPI/PluginFilter.h>

@class WizardWindowController, ProcessWindowController, ReportWindowController;

NS_ASSUME_NONNULL_BEGIN

@interface SurfaceLength3DFilter : PluginFilter

@property (nonatomic, strong) NSMutableArray *pairsResultsArray;

- (long)filterImage:(NSString *)menuName;

- (void)displayProcessWindow;
- (void)displaySurfaceRender;
- (void)displayResultsWindow;

@end

NS_ASSUME_NONNULL_END
