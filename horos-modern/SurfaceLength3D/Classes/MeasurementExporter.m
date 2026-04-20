#import "MeasurementExporter.h"
#import "PointPair.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@implementation MeasurementExporter

// ---------------------------------------------------------------------------
#pragma mark - CSV
// ---------------------------------------------------------------------------

+ (void)exportToCSV:(NSArray<PointPair *> *)pairs
          patientID:(nullable NSString *)patientID
    presentingWindow:(NSWindow *)window
         completion:(nullable void (^)(NSURL *_Nullable, NSError *_Nullable))completion {

    NSSavePanel *panel  = [NSSavePanel savePanel];
    panel.title         = NSLocalizedString(@"Export Measurements (CSV)", nil);
    panel.nameFieldStringValue = [self defaultFilenameWithExtension:@"csv" patientID:patientID];
    if (@available(macOS 11.0, *)) {
        UTType *csvType = [UTType typeWithFilenameExtension:@"csv"];
        panel.allowedContentTypes = csvType ? @[csvType] : @[UTTypePlainText];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        panel.allowedFileTypes = @[@"csv"];
#pragma clang diagnostic pop
    }

    [panel beginSheetModalForWindow:window completionHandler:^(NSModalResponse result) {
        if (result != NSModalResponseOK) { if (completion) completion(nil, nil); return; }

        NSError *error = nil;
        NSString *csv  = [self buildCSV:pairs patientID:patientID];
        BOOL ok = [csv writeToURL:panel.URL atomically:YES encoding:NSUTF8StringEncoding error:&error];
        if (completion) completion(ok ? panel.URL : nil, error);
    }];
}

+ (NSString *)buildCSV:(NSArray<PointPair *> *)pairs patientID:(nullable NSString *)patientID {
    NSMutableString *s = [NSMutableString string];

    // Header block
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    [s appendFormat:@"# Surface Length 3D — Measurement Export\n"];
    [s appendFormat:@"# Date: %@\n", [df stringFromDate:[NSDate date]]];
    if (patientID.length) {
        NSString *safeID = [[patientID componentsSeparatedByCharactersInSet:
                             [NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@" "];
        [s appendFormat:@"# Patient: %@\n", safeID];
    }
    [s appendString:@"# Algorithm: Dijkstra geodesic (custom CSR)\n"];
    [s appendString:@"# NOTE: Algorithm requires phantom validation before clinical use\n#\n"];

    // Column headers
    [s appendString:@"Point 1,Point 2,Direct (mm),Surface (mm),Ratio (surface/direct),Direction\n"];

    for (PointPair *pp in pairs) {
        if (pp.state != PointPairStateCalculated) continue;
        [s appendFormat:@"%@,%@,%.3f,%.3f,%.4f,%@\n",
            [self csvEscape:pp.p1Name],
            [self csvEscape:pp.p2Name],
            pp.distanceDirect,
            pp.distanceSurface,
            pp.distanceRatio,
            pp.clockwise ? @"CW" : @"CCW"];
    }
    return s;
}

+ (NSString *)csvEscape:(NSString *)s {
    if ([s containsString:@","] || [s containsString:@"\""]) {
        return [NSString stringWithFormat:@"\"%@\"", [s stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""]];
    }
    return s;
}

// ---------------------------------------------------------------------------
#pragma mark - PDF
// ---------------------------------------------------------------------------

+ (void)exportToPDF:(NSArray<PointPair *> *)pairs
         reportView:(NSView *)reportView
          patientID:(nullable NSString *)patientID
    presentingWindow:(NSWindow *)window
         completion:(nullable void (^)(NSURL *_Nullable, NSError *_Nullable))completion {

    NSSavePanel *panel  = [NSSavePanel savePanel];
    panel.title         = NSLocalizedString(@"Export Report (PDF)", nil);
    panel.nameFieldStringValue = [self defaultFilenameWithExtension:@"pdf" patientID:patientID];
    if (@available(macOS 11.0, *)) {
        panel.allowedContentTypes = @[UTTypePDF];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        panel.allowedFileTypes = @[@"pdf"];
#pragma clang diagnostic pop
    }

    [panel beginSheetModalForWindow:window completionHandler:^(NSModalResponse result) {
        if (result != NSModalResponseOK) { if (completion) completion(nil, nil); return; }

        NSError *error = nil;
        NSData *pdf    = [self buildPDF:pairs reportView:reportView patientID:patientID];
        BOOL ok = [pdf writeToURL:panel.URL options:NSDataWritingAtomic error:&error];
        if (completion) completion(ok ? panel.URL : nil, error);
    }];
}

+ (NSData *)buildPDF:(NSArray<PointPair *> *)pairs
          reportView:(NSView *)reportView
           patientID:(nullable NSString *)patientID {

    // Page geometry
    NSRect pageRect = NSMakeRect(0, 0, 595, 842); // A4 points
    NSMutableData *pdfData = [NSMutableData data];

    CGDataConsumerRef consumer = CGDataConsumerCreateWithCFData((__bridge CFMutableDataRef)pdfData);
    CGContextRef ctx = CGPDFContextCreate(consumer, &pageRect, NULL);
    CGDataConsumerRelease(consumer);

    CGPDFContextBeginPage(ctx, NULL);

    // Flip once so drawing code can use top-left style coordinates.
    CGContextTranslateCTM(ctx, 0, pageRect.size.height);
    CGContextScaleCTM(ctx, 1, -1);

    NSGraphicsContext *nsCtx = [NSGraphicsContext graphicsContextWithCGContext:ctx flipped:YES];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:nsCtx];

    CGFloat margin = 40, y = margin;
    CGFloat width  = pageRect.size.width - 2*margin;

    // --- Title ---
    NSDictionary *titleAttrs = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:16],
        NSForegroundColorAttributeName: [NSColor blackColor]
    };
    [@"Surface Length 3D — Measurement Report" drawAtPoint:NSMakePoint(margin, margin) withAttributes:titleAttrs];
    y = margin + 24;

    // --- Meta ---
    NSDictionary *metaAttrs = @{
        NSFontAttributeName: [NSFont systemFontOfSize:10],
        NSForegroundColorAttributeName: [NSColor darkGrayColor]
    };
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateStyle = NSDateFormatterMediumStyle;
    df.timeStyle = NSDateFormatterShortStyle;
    NSString *metaLine = [NSString stringWithFormat:@"Date: %@%@",
        [df stringFromDate:[NSDate date]],
        patientID.length ? [NSString stringWithFormat:@"   Patient: %@", patientID] : @""];
    [metaLine drawAtPoint:NSMakePoint(margin, y) withAttributes:metaAttrs];
    y += 18;

    // Disclaimer
    NSDictionary *warnAttrs = @{
        NSFontAttributeName: [NSFont systemFontOfSize:8],
        NSForegroundColorAttributeName: [NSColor redColor]
    };
    [@"⚠ For research use only. Algorithm requires phantom validation before clinical use." drawAtPoint:NSMakePoint(margin, y) withAttributes:warnAttrs];
    y += 20;

    NSInteger calcCount = 0;
    double ratioSum = 0.0, maxSurface = 0.0;
    for (PointPair *pp in pairs) {
        if (pp.state != PointPairStateCalculated) continue;
        calcCount++;
        ratioSum += pp.distanceRatio;
        if (pp.distanceSurface > maxSurface) maxSurface = pp.distanceSurface;
    }
    double meanRatio = calcCount > 0 ? (ratioSum / (double)calcCount) : 0.0;

    NSDictionary *summaryTitleAttrs = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:11],
        NSForegroundColorAttributeName: [NSColor blackColor]
    };
    NSDictionary *summaryAttrs = @{
        NSFontAttributeName: [NSFont systemFontOfSize:10],
        NSForegroundColorAttributeName: [NSColor colorWithWhite:0.2 alpha:1.0]
    };
    NSRect summaryRect = NSMakeRect(margin, y, width, 40);
    [[NSColor colorWithWhite:0.96 alpha:1.0] setFill];
    NSRectFill(summaryRect);
    [@"Summary" drawAtPoint:NSMakePoint(margin + 6, y + 5) withAttributes:summaryTitleAttrs];
    [[NSString stringWithFormat:@"Calculated paths: %ld   Max surface: %.1f mm   Mean ratio: x%.2f",
                                 (long)calcCount, maxSurface, meanRatio]
        drawAtPoint:NSMakePoint(margin + 78, y + 6)
      withAttributes:summaryAttrs];
    y += 48;

    // --- Report view snapshot ---
    CGFloat imgSize = MIN(width, 260);
    NSBitmapImageRep *bitmap = [reportView bitmapImageRepForCachingDisplayInRect:reportView.bounds];
    [reportView cacheDisplayInRect:reportView.bounds toBitmapImageRep:bitmap];
    NSImage *img = [[NSImage alloc] initWithSize:reportView.bounds.size];
    [img addRepresentation:bitmap];
    [img drawInRect:NSMakeRect(margin + (width - imgSize)/2, y, imgSize, imgSize)
           fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];
    y += imgSize + 12;

    // --- Table header ---
    NSDictionary *hdrAttrs = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:9],
        NSForegroundColorAttributeName: [NSColor whiteColor]
    };
    NSRect hdrRect = NSMakeRect(margin, y, width, 14);
    [[NSColor colorWithWhite:0.2 alpha:1.0] setFill];
    NSRectFill(hdrRect);

    CGFloat cols[] = { 0, 120, 240, 330, 420, 510 };
    NSArray *headers = @[@"Point 1", @"Point 2", @"Direct (mm)", @"Surface (mm)", @"Ratio", @"Dir."];
    for (NSUInteger i = 0; i < headers.count && i < 6; i++) {
        [headers[i] drawAtPoint:NSMakePoint(margin + cols[i] + 2, y + 2) withAttributes:hdrAttrs];
    }
    y += 14;

    // --- Table rows ---
    NSDictionary *cellAttrs = @{
        NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:9 weight:NSFontWeightRegular],
        NSForegroundColorAttributeName: [NSColor blackColor]
    };
    BOOL alternate = NO;
    for (PointPair *pp in pairs) {
        if (pp.state != PointPairStateCalculated) continue;
        if (alternate) {
            [[NSColor colorWithWhite:0.93 alpha:1.0] setFill];
            NSRectFill(NSMakeRect(margin, y, width, 13));
        }
        NSArray *values = @[
            pp.p1Name, pp.p2Name,
            [NSString stringWithFormat:@"%.1f", pp.distanceDirect],
            [NSString stringWithFormat:@"%.1f", pp.distanceSurface],
            [NSString stringWithFormat:@"%.3f", pp.distanceRatio],
            pp.clockwise ? @"CW" : @"CCW"
        ];
        for (NSUInteger i = 0; i < values.count && i < 6; i++) {
            [values[i] drawAtPoint:NSMakePoint(margin + cols[i] + 2, y + 1) withAttributes:cellAttrs];
        }
        y += 13;
        alternate = !alternate;
    }

    [NSGraphicsContext restoreGraphicsState];
    CGPDFContextEndPage(ctx);
    CGPDFContextClose(ctx);
    CGContextRelease(ctx);

    return pdfData;
}

// ---------------------------------------------------------------------------
#pragma mark - Helpers
// ---------------------------------------------------------------------------

+ (NSString *)defaultFilenameWithExtension:(NSString *)ext patientID:(nullable NSString *)pid {
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"yyyy-MM-dd_HHmm";
    NSString *date = [df stringFromDate:[NSDate date]];
    if (pid.length) return [NSString stringWithFormat:@"SL3D_%@_%@.%@", pid, date, ext];
    return [NSString stringWithFormat:@"SL3D_%@.%@", date, ext];
}

@end
