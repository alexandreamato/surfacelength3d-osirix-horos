// MeasurementExporter.h — exports PointPair results to CSV or PDF

#import <AppKit/AppKit.h>

@class PointPair;

NS_ASSUME_NONNULL_BEGIN

@interface MeasurementExporter : NSObject

/// Presents NSSavePanel and writes a CSV file with all pair measurements.
+ (void)exportToCSV:(NSArray<PointPair *> *)pairs
          patientID:(nullable NSString *)patientID
    presentingWindow:(NSWindow *)window
         completion:(nullable void (^)(NSURL *_Nullable url, NSError *_Nullable error))completion;

/// Renders reportView to a bitmap, builds a PDF with table + image, and saves it.
+ (void)exportToPDF:(NSArray<PointPair *> *)pairs
         reportView:(NSView *)reportView
          patientID:(nullable NSString *)patientID
    presentingWindow:(NSWindow *)window
         completion:(nullable void (^)(NSURL *_Nullable url, NSError *_Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
