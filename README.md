# SurfaceLength3D — OsiriX / Horos Plugin

A medical imaging plugin that computes **geodesic (surface) distances** between user-defined anatomical points on 3D surface renders of DICOM data, using Dijkstra's shortest-path algorithm on the VTK surface mesh.

Originally developed for OsiriX (2008, TriX Software / Gary Fielke). The modern version targets Horos and OsiriX with an updated VTK 9.x API and contemporary Objective-C patterns.

---

## Versions

| Folder | Target | VTK | Memory | Status |
|---|---|---|---|---|
| `legacy-osirix/` | OsiriX 3.x (32-bit era) | VTK 5.x | Manual retain/release | Historical reference |
| `horos-modern/` | **Horos 3.x + OsiriX** | VTK 9.x | ARC | Active development |

### Does the modern version run on OsiriX?

**Yes.** Horos is a direct fork of OsiriX with an identical plugin API (`PluginFilter`, `ViewerController`, `SRController`, `DCMPix`, `ROI`). To target OsiriX instead of Horos, change in `Info.plist`:
- `CFBundleIdentifier` → `com.trixsoftware.osirix.surfacelength3d`
- Bundle extension → `.osirixplugin`

---

## How it works

1. **Place Points** — user places 2D point ROIs in OsiriX/Horos's MPR viewer on the DICOM slices
2. **Process** — plugin opens the 3D surface renderer, detects the VTK mesh, then runs `vtkDijkstraGraphGeodesicPath` for every pair of points
3. **Report** — a radial 2D plot shows surface distances from the auto-selected centre point (the point with minimum total geodesic distance to all others)

Each path is visualised as a colored tube on the 3D surface render. A table shows Euclidean vs. geodesic distances for all point pairs.

---

## Building (modern version)

### Requirements

- macOS 12+ / Xcode 14+
- VTK 9.x (see options below)
- Horos or OsiriX SDK headers

### VTK

**Option A — Homebrew:**
```bash
brew install vtk
```
Set in Xcode Build Settings:
- **Header Search Paths:** `/opt/homebrew/include/vtk-9.x`
- **Library Search Paths:** `/opt/homebrew/lib`
- **Other Linker Flags:** `-lvtkFiltersModeling-9.x -lvtkFiltersCore-9.x -lvtkRenderingCore-9.x -lvtkCommonCore-9.x -lvtkCommonDataModel-9.x`

**Option B — From OsiriX/Horos source:**  
Extract `VTKLibs.zip` and `VTKHeaders.zip` from the Horos source tree and point the Xcode search paths at them.

### Horos/OsiriX SDK headers

Copy the plugin headers from `Horos.app/Contents/Headers/` (or from the OsiriX source) into `horos-modern/SurfaceLength3D/Horos Headers/`. Needed files:
- `PluginFilter.h`, `ViewerController.h`, `SRController.h`
- `DCMPix.h`, `ROI.h`, `MyPoint.h`, `Window3DController.h`

### Xcode project

See `horos-modern/SurfaceLength3D/XcodeProjectSetup.md` for step-by-step instructions to create the Xcode project, configure build settings, and wire up the XIB files.

---

## Key changes: legacy → modern

| Aspect | Legacy (OsiriX) | Modern (Horos) |
|---|---|---|
| Memory | `retain` / `release` | **ARC** |
| VTK API | `SetInput()` | **`SetInputData()` / `SetInputConnection()`** |
| Processing | Main thread (blocks UI) | **GCD background queue** |
| Progress | None | **NSProgressIndicator** |
| Wizard | 4 steps (VOI Cutter via AppleScript) | **3 steps** (VOI Cutter removed) |
| Alerts | `runModal` (blocking) | `beginSheetModalForWindow:completionHandler:` |
| Notifications | String literals | **`NSNotificationName` typed constants** |
| Data model | `PointPairObject` + plain `enum` | `PointPair` with `NS_ENUM`, nullability, generics |

---

## Authors

- **Gary Fielke** — original implementation (TriX Software, 2008)
- **Alexandre Amato** — modifications and Horos modernisation (2026)

---

## License

Original code © 2008 TriX Software. Released as open source for educational and research purposes. See individual source files for copyright notices.
