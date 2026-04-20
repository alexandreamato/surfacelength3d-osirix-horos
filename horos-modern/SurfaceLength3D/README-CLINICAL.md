# Surface Length 3D: Clinical Use

`Surface Length 3D` measures geodesic distance along a segmented 3D surface in Horos. It is intended for workflows such as aortic branch planning, where straight-line distance is not enough and the path along the vessel surface is clinically more relevant.

## Basic Workflow

1. Open the study in Horos.
2. Create or load the 3D Surface Rendering for the anatomy of interest.
3. Launch the plugin.
4. In `Step 1`, open the MPR viewer and place at least two point ROIs on the relevant landmarks.
5. In `Step 2`, wait for the surface rendering to appear. The plugin will detect the surface and calculate the paths.
6. Review the table of pairwise distances:
   - `Direct (mm)`: Euclidean distance between the landmarks.
   - `Surface (mm)`: geodesic distance constrained to the rendered surface.
   - `Ratio ×`: `Surface / Direct`.
7. In `Step 3`, review the radial report and export PDF if needed.

## Process Window

The Process window is the main verification screen.

- `Surface`: chooses which visible surface actor to use. `Auto (largest)` is usually the correct option.
- `Context`: applies anatomical names to the placed points. For vascular cases, use `Vascular (Aorta)` when appropriate.
- `Line width`: changes the thickness of the rendered 3D paths for visual inspection.
- `Show`: toggles each path on or off.
- `Reprocess`: recalculates all visible point-pair paths using the selected surface.
- `Export CSV`: exports the quantitative results table.
- `Validate Phantom`: runs the current validation backend when available.

## Report Window

The report window provides a compact visual summary.

- `All`: shows the full network of measured relationships.
- Individual point selection: re-centres the radial plot on a chosen landmark.
- `Export PDF`: exports the report figure and summary.
- `Vascular Planning`: opens the Coselli-oriented planning summary when vessel naming matches the vascular context.

## Practical Tips

- Place point ROIs directly on the structure represented by the surface rendering.
- Reprocess after changing the active surface or after moving point ROIs.
- If multiple surfaces are visible, prefer isolating the target anatomy before processing.
- Use the 3D rendered paths as a verification aid, not as the only quality-control step.

## Current Limits

- The plugin depends on Horos runtime behavior and a fragile VTK compatibility layer.
- Surface distance is only as good as the underlying segmentation and rendered mesh.
- Phantom validation is not always available inside the Horos runtime.
- This tool supports planning and measurement review; it does not replace clinical judgment.
