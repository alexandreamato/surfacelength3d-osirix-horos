# Xcode Project Setup — SurfaceLength3D (Horos Modern)

## Criar o projeto no Xcode

1. File → New → Project → macOS → Bundle (não "App")
2. Product Name: `SurfaceLength3D`
3. Bundle Identifier: `com.trixsoftware.horos.surfacelength3d`
4. Language: Objective-C
5. **Apagar** o arquivo `.m` gerado automaticamente e o `Info.plist` gerado — usar os deste diretório

---

## Build Settings obrigatórios

| Setting | Valor |
|---|---|
| Objective-C Automatic Reference Counting | **YES** |
| C++ Language Dialect | **C++17** |
| macOS Deployment Target | **10.15** (mínimo Horos 3.x) |
| Other Linker Flags | `-ObjC` |
| Product Bundle Identifier | `com.trixsoftware.horos.surfacelength3d` |
| Wrapper Extension | `horosPlugin` (ou `osirixplugin` — Horos aceita os dois) |
| Info.plist File | `SurfaceLength3D/Info.plist` |

---

## Dependências VTK (VTK 9.x)

### Opção A — VTK via Homebrew (desenvolvimento local)
```bash
brew install vtk
```
Depois no Xcode:
- **Header Search Paths**: `/opt/homebrew/include/vtk-9.x`
- **Library Search Paths**: `/opt/homebrew/lib`
- **Other Linker Flags**: `-lvtkFiltersCore-9.x -lvtkFiltersModeling-9.x -lvtkRenderingCore-9.x -lvtkCommonCore-9.x -lvtkCommonDataModel-9.x`

### Opção B — VTK estático (mesma abordagem do original)
Copiar as VTKLibs e VTKHeaders do OsiriX / Horos source:
- **Header Search Paths**: caminho para `VTKHeaders/`
- **Library Search Paths**: caminho para `VTKLibs/`
- Linkar todas as `.a` do VTK 9.x

---

## Headers do Horos SDK

Copiar os headers da pasta `horos/Headers/` do Horos.app para `Horos Headers/` no projeto:
- `PluginFilter.h`
- `ViewerController.h`
- `ROI.h`
- `DCMPix.h`
- `SRController.h`
- `Window3DController.h`
- `MyPoint.h`

Os headers do Horos são compatíveis com os do OsiriX — podem ser copiados da pasta `OsiriX Headers/` do projeto original se necessário.

---

## Arquivos a incluir no target

```
SurfaceLength3DFilter.h / .m
Classes/Constants.h / .m
Classes/PointPair.h / .m
Classes/GeodesicProcessor.h / .mm      ← Objective-C++
Classes/WizardWindowController.h / .m
Classes/ProcessWindowController.h / .m
Classes/ReportWindowController.h / .m
Classes/ReportView.h / .m
```

---

## XIB files (criar no Xcode com Interface Builder)

### SurfaceLength3DWizard.xib
- Window com 3 elementos de texto: `stepNumField`, `stepTitleField`, `stepDescriptionField`
- Botões: `backButton` (Back), `skipButton` (Skip), `performButton` (Perform)
- Label de versão: `versionField`
- Owner class: `WizardWindowController`

### Process.xib
- NSTableView (`tableView`) com 4 colunas:
  - identifier `pairs` — NSTextField
  - identifier `direct` — NSTextField (alinhado à direita)
  - identifier `surface` — NSTextField (alinhado à direita)
  - identifier `display` — NSButtonCell (checkbox)
- NSProgressIndicator (`progressIndicator`, estilo spinning, escondido inicialmente)
- NSButton `reprocessButton` → action `doReprocess:`
- NSButton Close → action `closeWindow:`
- Owner class: `ProcessWindowController`

### Report.xib
- NSView custom class `ReportView` (`reportView`) preenchendo a janela
- NSSegmentedControl (`centrePointControl`) → action `changeCentrePoint:`
- NSButton Close → action `closeReport:`
- Owner class: `ReportWindowController`

---

## Diferenças da versão original (OsiriX)

| Aspecto | Original (OsiriX) | Esta versão (Horos Modern) |
|---|---|---|
| Memory management | Manual retain/release | **ARC** |
| VTK API | VTK 5.x (`SetInput`) | **VTK 9.x** (`SetInputData`/`SetInputConnection`) |
| Processing thread | Main thread (bloqueante) | **GCD background queue** |
| Wizard steps | 4 (inclui VOI Cutter via AppleScript) | **3** (VOI Cutter removido) |
| NSAlert | `runModal` (bloqueante) | `beginSheetModalForWindow:completionHandler:` |
| Notification names | Strings literais | **NSNotificationName constants** |
| Data model | `PointPairObject` | `PointPair` com `NS_ENUM` e nullability |
| Progress feedback | Nenhum | **NSProgressIndicator** durante computation |
| VTK headers incluídos | ~50 (a maioria não usados) | Somente os necessários (9 headers) |
