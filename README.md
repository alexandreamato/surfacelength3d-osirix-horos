# SurfaceLength3D — OsiriX / Horos Plugin

A medical imaging plugin that computes **geodesic (surface) distances** between user-defined anatomical points on 3D surface renders of DICOM data, using Dijkstra's shortest-path algorithm on the VTK surface mesh.

Originally developed for OsiriX (2008, TriX Software / Gary Fielke). The modern version targets Horos and OsiriX with an updated VTK 9.x API and contemporary Objective-C patterns.

---

## Publication

This plugin is described in the following peer-reviewed article:

> **Amato ACM.** Surface Length 3D: Plugin do OsiriX para cálculo da distância em superfícies *(Surface Length 3D: An OsiriX plugin for measuring length over surfaces)*. **J Vasc Bras.** 2016;15(4):308-311. DOI: [10.1590/1677-5449.005316](https://doi.org/10.1590/1677-5449.005316)

Available at: [PubMed / PMC](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5829730/) · [SciELO](https://www.scielo.br/j/jvb/a/dN4VDf6DGfZHhjhY4S9nW3C/?lang=en) · [Journal](https://jvascbras.org/journal/jvb/article/doi/10.1590/1677-5449.005316)

---

## Clinical Background

Standard DICOM software measures linear (Euclidean) distances, area, and volume — but **cannot measure distances along curved surfaces**. This is clinically important whenever straight-line distance does not reflect anatomical reality.

### Primary use case: aortic aneurysm surgical planning

When planning repair of thoracoabdominal aortic aneurysms, the surgeon must choose between a **Coselli graft** (multiple separate orifices for visceral vessels) and a **patch** technique. This decision depends on the surface distances between visceral vessel ostia (celiac artery, superior mesenteric artery, renal arteries) on the aortic wall — distances that a Euclidean ruler cannot capture on a curved surface.

### Other clinical applications described in the article

| Specialty | Application |
|---|---|
| Vascular surgery | Distances between visceral ostia on the aorta for graft planning |
| Neurosurgery | Skull surface triangulation to locate subdural hematoma drainage sites |
| Plastic surgery | Surface distances between anatomical landmarks |

### Validation status

Preliminary validation of OsiriX standard distance tools showed **0.3 mm precision with good reliability**. The article explicitly calls for formal validation of the geodesic algorithm using phantom data — this remains an open research opportunity.

---

## How it works

1. **Segment** — isolate the structure of interest in OsiriX/Horos (e.g., the aorta) using the VOI Cutter or segmentation tools
2. **Place Points** — place 2D point ROIs on each anatomical landmark in the MPR viewer (e.g., each visceral ostium)
3. **Process** — the plugin opens the 3D surface renderer, detects the VTK mesh, and runs `vtkDijkstraGraphGeodesicPath` for every pair of points; each path is shown as a colored tube on the 3D render
4. **Report** — a radial 2D plot shows all surface distances from the auto-selected centre point; a table compares Euclidean vs. geodesic distances

---

## Versions

| Folder | Target | VTK | Memory | Status |
|---|---|---|---|---|
| `legacy-osirix/` | OsiriX 3.x (32-bit, macOS ≤ 10.14) | VTK 5.x | Manual retain/release | Historical — see [Releases](../../releases) |
| `horos-modern/` | **Horos 3.x + OsiriX MD** (64-bit, macOS 10.15+) | VTK 9.x | ARC | Active development |

### Does the modern version run on OsiriX?

**Yes.** Horos is a direct fork of OsiriX with an identical plugin API (`PluginFilter`, `ViewerController`, `SRController`, `DCMPix`, `ROI`). To target OsiriX MD instead of Horos, change in `Info.plist`:
- `CFBundleIdentifier` → `com.trixsoftware.osirix.surfacelength3d`

---

## Building (modern version)

### Requirements
- macOS 12+ / Xcode 14+
- `OsiriXAPI.framework` — extracted from `Horos.app/Contents/Frameworks/` or `OsiriX MD.app/Contents/Frameworks/` (includes VTK; no separate VTK installation needed)

### Xcode project
See [`horos-modern/SurfaceLength3D/XcodeProjectSetup.md`](horos-modern/SurfaceLength3D/XcodeProjectSetup.md) for step-by-step instructions, required build settings (`-undefined dynamic_lookup`), XIB wiring, and debug alias setup.

---

## Key changes: legacy → modern

| Aspect | Legacy (OsiriX) | Modern (Horos) |
|---|---|---|
| SDK | Copied header files | **`OsiriXAPI.framework`** |
| Linker flag | variava | **`-undefined dynamic_lookup`** |
| VTK | 27 static `.a` libs (~221 MB) | **Bundled in framework** |
| Memory | `retain` / `release` | **ARC** |
| VTK API | `SetInput()` (VTK 5) | **`SetInputData()` / `SetInputConnection()`** |
| Processing | Main thread (blocks UI) | **GCD background queue** |
| Progress | None | **NSProgressIndicator** |
| Wizard | 4 steps (VOI Cutter via AppleScript) | **3 steps** |

---

## Authors

- **Gary Fielke** — original implementation (TriX Software, 2008)
- **Alexandre Campos Moraes Amato** — clinical conception, modifications, and Horos modernisation

---

## Citation

If you use this plugin in research, please cite:

```
Amato ACM. Surface Length 3D: Plugin do OsiriX para cálculo da distância em superfícies.
J Vasc Bras. 2016;15(4):308-311. https://doi.org/10.1590/1677-5449.005316
```

---

## License

Original code © 2008 TriX Software. Released as open source for educational and research purposes. See individual source files for copyright notices.
