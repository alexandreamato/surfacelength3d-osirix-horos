# Xcode Project Setup — SurfaceLength3D (Horos / OsiriX Modern)

## 1. Obter o OsiriXAPI.framework

O framework contém todos os headers do OsiriX/Horos **e** o VTK embutido. Não é necessário instalar VTK separadamente.

**Para OsiriX MD:**
```
Clique com botão direito em OsiriX MD.app → "Show Package Contents"
→ Contents/Frameworks/OsiriXAPI.framework
```

**Para Horos:**
```
Clique com botão direito em Horos.app → "Show Package Contents"
→ Contents/Frameworks/OsiriXAPI.framework
```

Copie `OsiriXAPI.framework` para dentro da pasta do projeto.

---

## 2. Criar o projeto no Xcode

1. File → New → Project → macOS → **Bundle** (não "App")
2. Product Name: `SurfaceLength3D`
3. Language: **Objective-C**
4. Apagar o `.m` gerado e o `Info.plist` gerado — usar os deste diretório

---

## 3. Adicionar o framework

- Arrastar `OsiriXAPI.framework` para o grupo do projeto no Xcode
- Em "Add to targets": marcar `SurfaceLength3D`
- **"Embed"** → *Do Not Embed* (o OsiriX/Horos já carrega o framework em runtime)

---

## 4. Build Settings obrigatórios

| Setting | Valor |
|---|---|
| **Other Linker Flags** | **`-undefined dynamic_lookup`** |
| Objective-C ARC | YES |
| C++ Language Dialect | C++17 |
| macOS Deployment Target | 10.15 |
| Wrapper Extension | `osirixplugin` |
| Info.plist File | `SurfaceLength3D/Info.plist` |

> **Por que `-undefined dynamic_lookup`?** O plugin é um bundle carregado em runtime pelo OsiriX/Horos. Os símbolos do framework (ViewerController, ROI, etc.) só existem no processo do app host — não na link time. Esta flag instrui o linker a deixar esses símbolos sem resolução até o carregamento dinâmico.

> **VTK não precisa de instalação separada.** O `OsiriXAPI.framework` já inclui os headers e símbolos VTK necessários.

---

## 5. Header Search Paths

Adicionar ao Build Setting **Header Search Paths**:
```
$(PROJECT_DIR)/OsiriXAPI.framework/Headers
```

Isso expõe os headers VTK do framework (ex: `vtkDijkstraGraphGeodesicPath.h`).

---

## 6. Arquivos a incluir no target

```
SurfaceLength3DFilter.h / .m
Classes/Constants.h / .m
Classes/PointPair.h / .m
Classes/GeodesicProcessor.h / .mm      ← Objective-C++ (extensão .mm)
Classes/WizardWindowController.h / .m
Classes/ProcessWindowController.h / .m
Classes/ReportWindowController.h / .m
Classes/ReportView.h / .m
```

---

## 7. XIB files (criar no Interface Builder)

### SurfaceLength3DWizard.xib
- File's Owner class: `WizardWindowController`
- Outlets: `stepNumField`, `stepTitleField`, `stepDescriptionField`, `backButton`, `skipButton`, `performButton`, `versionField`

### Process.xib
- File's Owner class: `ProcessWindowController`
- NSTableView (`tableView`) com 4 colunas: identifier `pairs`, `direct`, `surface`, `display`
- NSProgressIndicator (`progressIndicator`, spinning, hidden)
- Botões: `doReprocess:`, `closeWindow:`

### Report.xib
- File's Owner class: `ReportWindowController`
- ReportView custom view (`reportView`)
- NSSegmentedControl (`centrePointControl`) → `changeCentrePoint:`
- Botão Close → `closeReport:`

---

## 8. Debug: alias do plugin

Para testar dentro do OsiriX/Horos sem instalação manual:

```bash
# Após build (⌘B), criar alias no diretório do sistema (não ~/Library — tem restrições):
sudo ln -s "$BUILD_DIR/Debug/SurfaceLength3D.osirixplugin" \
           "/Library/Application Support/OsiriX/Plugins/SurfaceLength3D.osirixplugin"
```

Reiniciar o OsiriX/Horos após criar o alias. Para debug interativo, configure o scheme do Xcode com OsiriX/Horos como "Executable".

---

## Diferenças da versão original (OsiriX legacy)

| Aspecto | Legacy (2008) | Esta versão |
|---|---|---|
| SDK | Headers copiados manualmente | **OsiriXAPI.framework** |
| Linker flag | variava | **`-undefined dynamic_lookup`** |
| VTK | 27 libs `.a` estáticas (~221MB) | **Embutido no framework** |
| Memory | `retain`/`release` | **ARC** |
| VTK API | `SetInput()` (VTK 5) | **`SetInputData()`/`SetInputConnection()`** |
| Threading | Main thread bloqueante | **GCD background queue** |
| Wizard | 4 passos (VOI Cutter via AppleScript) | **3 passos** |
