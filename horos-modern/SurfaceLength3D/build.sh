#!/bin/bash
set -e

PROJ="$(cd "$(dirname "$0")"; pwd)"
BUILD="$PROJ/build"
CLASSES="$PROJ/Classes"
FWDIR="$PROJ"
SDK="$(xcrun --show-sdk-path)"
VTK_INC="/opt/homebrew/Cellar/vtk/9.5.2_3/include/vtk-9.5"
HOROS_HDR="$PROJ/Horos Headers"

mkdir -p "$BUILD"

CFLAGS="-fobjc-arc -mmacosx-version-min=12.0 -isysroot $SDK \
  -F$FWDIR -I$CLASSES -I$PROJ \
  -I\"$HOROS_HDR\" \
  -w -O2"

CPPFLAGS="$CFLAGS -std=c++17 -I$VTK_INC"

echo "=== Compiling ObjC sources ==="
for f in \
  "$PROJ/SurfaceLength3DFilter.m" \
  "$CLASSES/Constants.m" \
  "$CLASSES/PointPair.m" \
  "$CLASSES/AnatomicalLabelSet.m" \
  "$CLASSES/MeasurementExporter.m" \
  "$CLASSES/VascularPlanningReport.m" \
  "$CLASSES/WizardWindowController.m" \
  "$CLASSES/ProcessWindowController.m" \
  "$CLASSES/ReportWindowController.m" \
  "$CLASSES/ReportView.m"
do
  base="$(basename "$f" .m)"
  echo "  $base.m"
  eval xcrun clang $CFLAGS -c \"$f\" -o "$BUILD/$base.o"
done

echo "=== Compiling ObjC++ sources ==="
for f in \
  "$CLASSES/GeodesicProcessor.mm" \
  "$CLASSES/ValidationPhantom.mm"
do
  base="$(basename "$f" .mm)"
  echo "  $base.mm"
  eval xcrun clang++ $CPPFLAGS -c \"$f\" -o "$BUILD/$base.o"
done

echo "=== Linking bundle ==="
OBJS=(
  "$BUILD/SurfaceLength3DFilter.o"
  "$BUILD/Constants.o"
  "$BUILD/PointPair.o"
  "$BUILD/AnatomicalLabelSet.o"
  "$BUILD/MeasurementExporter.o"
  "$BUILD/VascularPlanningReport.o"
  "$BUILD/WizardWindowController.o"
  "$BUILD/ProcessWindowController.o"
  "$BUILD/ReportWindowController.o"
  "$BUILD/ReportView.o"
  "$BUILD/GeodesicProcessor.o"
  "$BUILD/ValidationPhantom.o"
)

xcrun clang++ -bundle \
  -mmacosx-version-min=12.0 \
  -isysroot "$SDK" \
  -F"$FWDIR" \
  -framework Horos \
  -framework AppKit \
  -framework Foundation \
  -undefined dynamic_lookup \
  "${OBJS[@]}" \
  -o "$BUILD/SurfaceLength3D"

echo "=== Packaging plugin ==="
PLUGIN="$BUILD/SurfaceLength3D.horosplugin"
rm -rf "$PLUGIN"
mkdir -p "$PLUGIN/Contents/MacOS"
cp "$BUILD/SurfaceLength3D" "$PLUGIN/Contents/MacOS/"
cp "$PROJ/Info.plist"       "$PLUGIN/Contents/"

echo "=== Installing ==="
INSTALL_DIR="$HOME/Library/Application Support/Horos/Plugins"
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/SurfaceLength3D.horosplugin"
cp -r "$PLUGIN" "$INSTALL_DIR/"

echo ""
echo "Done: $INSTALL_DIR/SurfaceLength3D.horosplugin"
