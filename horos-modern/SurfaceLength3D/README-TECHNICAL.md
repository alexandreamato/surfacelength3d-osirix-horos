# SurfaceLength3D Technical Notes

## Scope
`SurfaceLength3D` is a Horos plugin that measures geodesic distance between ROI landmarks on a 3D surface rendering and displays those paths back on the surface.

Active code lives in:
- `Classes/`
- `SurfaceLength3DFilter.m`

Historical code in `legacy-osirix/` is reference only.

## Current Workflow
1. User creates the VOI / 3D surface in Horos.
2. User places point ROIs in the viewer.
3. `ProcessWindowController` builds `PointPair` objects and triggers `GeodesicProcessor`.
4. `GeodesicProcessor`:
   - finds the largest valid surface actor or the user-selected one;
   - reads the actor matrix safely from the Horos VTK 8 runtime;
   - deep-copies mesh vertices and polygons on the main thread;
   - builds CSR adjacency;
   - runs custom Dijkstra in the background;
   - stores world-space path points;
   - renders paths back into the SR view as manual tube geometry.
5. `ReportWindowController` / `ReportView` show the radial report and `MeasurementExporter` writes CSV/PDF.

## Important Runtime Constraint
Horos embeds `VTK 8.x`, but this project is compiled with `VTK 9.x` headers.

This means normal VTK virtual dispatch is unsafe. The plugin therefore uses a compatibility layer in:
- `Classes/SL3DVTKCompat.h`

That file centralizes:
- safe VTK destruction with `SL3DDelete`
- verified VTK 8 field offsets
- mapper / polygon-count accessors
- matrix extraction from actors
- point transforms
- manual tube-mesh generation for displayed paths

If you need to touch low-level VTK interaction, start there first.

## Stability Strategy
The plugin currently prefers stability over perfect ownership semantics.

Notable choices:
- VTK path actors/mappers are removed from the renderer conservatively.
- Explicit destruction of transient display objects is minimized because Horos can crash under the mixed VTK 8/9 ABI.
- Path thickness is implemented as manual polygonal tube geometry, not `SetLineWidth` or `vtkTubeFilter`.

## Files By Responsibility
- `GeodesicProcessor.mm`: surface detection, mesh copy, CSR build, Dijkstra, path display.
- `SL3DVTKCompat.h`: all VTK ABI-compat helpers.
- `ProcessWindowController.m`: processing UI, reprocess, line-width slider, phantom validation entry.
- `ReportWindowController.m`: report state, center-point naming, summary metrics.
- `ReportView.m`: radial report drawing, legend, summary overlay.
- `MeasurementExporter.m`: CSV and PDF export.
- `ValidationPhantom.mm`: currently returns a stub result inside Horos because safe analytic VTK phantom generation is not available in this runtime.

## Known Limitations
- Phantom validation is informative only in the Horos runtime; true analytic validation still needs a standalone-safe backend.
- Some VTK warnings remain because Horos headers expose deprecated macOS APIs.
- The plugin still depends on verified offsets for some Horos VTK 8 internals.

## Safe Change Guidelines
- Keep ROI/DCMPix access on the main thread.
- Deep-copy VTK mesh data before background work.
- Prefer explicit base dispatch and compatibility helpers over direct VTK convenience methods.
- Avoid introducing new VTK filters unless they are proven safe in Horos.
