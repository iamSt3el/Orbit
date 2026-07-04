# File Manager M3 Expressive Design System — Implementation Plan (Plan 3 of 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the plain, unstyled QML shell from Plan 2 with a genuine Material 3 Expressive design system: real M3 color/type/shape/elevation/motion tokens, ripple + spring-physics interactions, and M3 components (buttons, list items, top app bar) built on top of them.

**Architecture:** A `qml/tokens/` directory of `pragma Singleton` QML files (Color, Type, Shape, Elevation, Motion) provides the design system's values. A `qml/shapes/` directory vendors the quickshell project's `MatrialShapes` library (a QtQuick-only, Quickshell-independent polygon shape-morphing engine) unmodified, for a future component that genuinely needs arbitrary-polygon morphing (e.g. an extend-on-hover FAB) — this plan vendors it but does not wire it into anything yet, see the note in Task 3. A `qml/components/` directory holds reusable M3 building blocks (`Ripple`, `Icon`, `Button`) adapted from quickshell's `RippleEffect.qml`/`MaterialIconSymbol.qml`/`CustomButton.qml`, repointed at this project's own tokens instead of quickshell's. `main.qml` is rebuilt on top of these: a top app bar, an M3 list item delegate for `FileListModel` (from Plan 2, unchanged), and a tonal "New folder" button wired to the existing `createFolder` invokable (also from Plan 2, unchanged) — no bridge/backend code changes in this plan.

**Tech Stack:** QML/Qt Quick (no Qt Quick Controls), `matugen` (Rust, shelled out from a small workspace tool) for M3 tonal-palette generation, QML `SpringAnimation` for component motion, `Easing.BezierCurve` for screen-level transitions, Material Symbols Rounded variable font for icons.

## Global Constraints

- No Qt Quick Controls — every component is built from `Rectangle`/`Item`/`Canvas`/`MouseArea`, per the design spec.
- One fixed palette generated from seed `#6750A4` using the M3 **tonal-spot** scheme (Google's standard scheme type — not `scheme-expressive`, which is a *different* matugen scheme variant that shifts hue for chromatic variety and is unrelated to the "M3 Expressive" 2025 design update this project targets). Light and dark variants both ship; no dynamic/wallpaper-based color.
- Component-level motion (button press corner-radius change, list-item hover) uses QML `SpringAnimation`. Screen-level transitions use `Easing.BezierCurve` duration/easing pairs from the M3 motion spec. These are two different systems — do not use springs for screen transitions or easing curves for component presses.
- The vendored `MatrialShapes` polygon-morph engine (Task 3) is not wired into any component by this plan — none of Plan 2's existing invokables (`navigate`, `createFolder`, `deleteEntry`) drive a component shape genuinely suited to it (arbitrary polygon morphing, e.g. a circle-to-extended-pill FAB). Forcing it into the button's simple press state under this plan's `cargo build`-only verification would trade real risk for a cosmetic effect nobody could confirm looks right. It's vendored now (cheap, matches the design spec) so a future plan adding a real FAB or expand/collapse panel can use it immediately.
- This plan does not add dialogs, snackbar, navigation rail, tabs, or search/sort UI — the design spec defers those, and Plan 2 didn't wire the invokables they'd need (`toggleSort`/`setFilterText`). Scope here is strictly: style what Plan 2 already built (navigate, list, create folder, delete).
- Every task's acceptance check is `cargo build -p fm-app` succeeding. This runs `qmlcachegen`, which ahead-of-time compiles the QML and catches most syntax/binding/import errors — the same acceptance bar Plan 2 used. There is no automated QML test harness (per the design spec's testing section), and — per Plan 2's finding — this sandboxed environment cannot interactively run the GUI (a Qt app hangs silently at platform-plugin init with zero output, confirmed independent of QML content). If interactive verification is possible in your environment, do it; if not, `cargo build` succeeding is the verification ceiling — say so rather than claiming an interactive pass.

## Correction: QML module registration (found during execution)

This plan was executed directly (not by a fresh implementer) and two assumptions below turned out wrong. **Every task body below still says `import com.filemanager.app.tokens 1.0` / `.components 1.0` and includes steps to hand-write `qmldir` files — ignore those specifics and follow this note instead; the actual committed code does.**

- **One flat module URI, not sub-namespaces.** `CxxQtBuilder::new_qml_module(QmlModule::new(uri)...)` registers exactly one URI for the whole crate; there is no automatic per-directory sub-module namespacing (`qml/tokens/*.qml` does **not** become `com.filemanager.app.tokens` just by living in a `tokens/` folder). Every file — tokens, shapes, components, `main.qml` — is registered under the single URI `com.filemanager.app`, and every QML file that needs them just does `import com.filemanager.app 1.0` once to get all singletons and components in scope.
- **`qmldir` is auto-generated — never hand-write one.** cxx-qt-build generates the module's `qmldir` itself from whatever's passed to `.qml_files()`/`.qml_file()`. Passing a hand-written `qmldir` text file into `.qml_files()` breaks the build: `qmlcachegen` treats every entry as a QML document to ahead-of-time-compile, and fails with `fatal error: .../qmldir.cpp: No such file or directory` since a plain-text manifest has no such compiled form.
- **Singletons need an explicit flag, not just `pragma Singleton`.** Having `pragma Singleton` inside the `.qml` file is not sufficient for cxx-qt-build's auto-generated `qmldir` to emit a `singleton` entry — it registers the file as a plain (non-singleton) type by default, which would make `Color.scheme.primary`-style bare-singleton access fail at runtime. The fix: construct the file with `cxx_qt_build::QmlFile::from("qml/tokens/Color.qml").singleton(true)` and pass it via `.qml_file(...)` (singular) instead of a bare path string in `.qml_files([...])`. Confirmed correct by inspecting the generated `target/debug/build/fm-app-*/out/**/qmldir`, which read `singleton Color 1.0 qml/tokens/Color.qml` only after this fix.

The real, working `build.rs` (after Task 6) looks like this:

```rust
use cxx_qt_build::{CxxQtBuilder, QmlFile, QmlModule};

fn main() {
    CxxQtBuilder::new_qml_module(
        QmlModule::new("com.filemanager.app")
            .qml_files([
                "qml/main.qml",
                "qml/shapes/material-shapes.js",
                "qml/shapes/MorphShape.qml",
                "qml/shapes/geometry/offset.js",
                "qml/shapes/graphics/matrix.js",
                "qml/shapes/shapes/corner-rounding.js",
                "qml/shapes/shapes/cubic.js",
                "qml/shapes/shapes/feature.js",
                "qml/shapes/shapes/feature-mapping.js",
                "qml/shapes/shapes/float-mapping.js",
                "qml/shapes/shapes/morph.js",
                "qml/shapes/shapes/point.js",
                "qml/shapes/shapes/polygon-measure.js",
                "qml/shapes/shapes/rounded-corner.js",
                "qml/shapes/shapes/rounded-polygon.js",
                "qml/shapes/shapes/utils.js",
                "qml/components/Ripple.qml",
                "qml/components/Icon.qml",
                "qml/components/Button.qml",
                "qml/components/FileListItem.qml",
                "qml/components/TopAppBar.qml",
            ])
            .qml_file(QmlFile::from("qml/tokens/Color.qml").singleton(true))
            .qml_file(QmlFile::from("qml/tokens/Type.qml").singleton(true))
            .qml_file(QmlFile::from("qml/tokens/Shape.qml").singleton(true))
            .qml_file(QmlFile::from("qml/tokens/Elevation.qml").singleton(true))
            .qml_file(QmlFile::from("qml/tokens/Motion.qml").singleton(true)),
    )
    .file("src/file_list_model.rs")
    .qt_module("Gui")
    .build();
}
```

No `qmldir` files exist anywhere under `crates/app/qml/` in the actual repo — delete any you find if re-deriving this plan from scratch and one gets created by mistake.

## Palette Values (generated before writing this plan)

Real output from `matugen color hex '#6750A4' --type scheme-tonal-spot -m light --json hex --dry-run --quiet` (and `-m dark`), confirmed to closely match Google's own published baseline-purple example (e.g. `secondary: #625b71` is an exact match). Task 1 regenerates these programmatically via a backend tool rather than hand-copying, but the values are reproduced here for reference:

**Light:** primary `#65558f` / on-primary `#ffffff` / primary-container `#e9ddff` / on-primary-container `#201047` / secondary `#625b71` / on-secondary `#ffffff` / secondary-container `#e8def8` / on-secondary-container `#1e192b` / tertiary `#7e5260` / on-tertiary `#ffffff` / tertiary-container `#ffd9e3` / on-tertiary-container `#31101d` / error `#ba1a1a` / on-error `#ffffff` / error-container `#ffdad6` / on-error-container `#410002` / surface `#fdf7ff` / on-surface `#1d1b20` / on-surface-variant `#49454e` / surface-container-lowest `#ffffff` / surface-container-low `#f8f2fa` / surface-container `#f2ecf4` / surface-container-high `#ece6ee` / surface-container-highest `#e6e0e9` / outline `#7a757f` / outline-variant `#cac4cf` / inverse-surface `#322f35` / inverse-on-surface `#f5eff7` / inverse-primary `#cfbdfe`.

**Dark:** primary `#cfbdfe` / on-primary `#36275d` / primary-container `#4d3d75` / on-primary-container `#e9ddff` / secondary `#cbc2db` / on-secondary `#332d41` / secondary-container `#4a4458` / on-secondary-container `#e8def8` / tertiary `#efb8c8` / on-tertiary `#4a2532` / tertiary-container `#633b48` / on-tertiary-container `#ffd9e3` / error `#ffb4ab` / on-error `#690005` / error-container `#93000a` / on-error-container `#ffdad6` / surface `#141218` / on-surface `#e6e0e9` / on-surface-variant `#cac4cf` / surface-container-lowest `#0f0d13` / surface-container-low `#1d1b20` / surface-container `#211f24` / surface-container-high `#2b292f` / surface-container-highest `#36343a` / outline `#948f99` / outline-variant `#49454e` / inverse-surface `#e6e0e9` / inverse-on-surface `#322f35` / inverse-primary `#65558f`.

---

### Task 1: Backend theme generator + Color token singleton

**Files:**
- Create: `crates/xtask/Cargo.toml`
- Create: `crates/xtask/src/main.rs`
- Modify: `Cargo.toml` (workspace root — add `crates/xtask`)
- Create: `crates/app/qml/tokens/Color.qml`

**Interfaces:**
- Consumes: the `matugen` CLI binary (must be on `PATH`; this is a one-time generation tool, not a runtime dependency of `fm-app`).
- Produces: `crates/app/qml/tokens/Color.qml`, a `pragma Singleton` exposing `Color.scheme.<role>` (e.g. `Color.scheme.primary`) that resolves to the light or dark palette based on `Color.darkMode`. Every later QML task in this plan references `Color.scheme.*`.

- [ ] **Step 1: Create the xtask crate**

`crates/xtask/Cargo.toml`:
```toml
[package]
name = "fm-xtask"
version = "0.1.0"
edition = "2021"

[dependencies]
serde = { version = "1", features = ["derive"] }
serde_json = "1"
```

`Cargo.toml` (workspace root):
```toml
[workspace]
resolver = "2"
members = ["crates/core", "crates/app", "crates/xtask"]
```

- [ ] **Step 2: Write the generator**

`crates/xtask/src/main.rs`:
```rust
use serde::Deserialize;
use std::collections::BTreeMap;
use std::process::Command;

const SEED: &str = "#6750A4";

#[derive(Deserialize)]
struct MatugenOutput {
    colors: Modes,
}

#[derive(Deserialize)]
struct Modes {
    light: BTreeMap<String, String>,
    dark: BTreeMap<String, String>,
}

const ROLES: &[&str] = &[
    "primary",
    "on_primary",
    "primary_container",
    "on_primary_container",
    "secondary",
    "on_secondary",
    "secondary_container",
    "on_secondary_container",
    "tertiary",
    "on_tertiary",
    "tertiary_container",
    "on_tertiary_container",
    "error",
    "on_error",
    "error_container",
    "on_error_container",
    "surface",
    "on_surface",
    "on_surface_variant",
    "surface_container_lowest",
    "surface_container_low",
    "surface_container",
    "surface_container_high",
    "surface_container_highest",
    "outline",
    "outline_variant",
    "inverse_surface",
    "inverse_on_surface",
    "inverse_primary",
];

fn to_camel(role: &str) -> String {
    let mut out = String::new();
    let mut upper_next = false;
    for ch in role.chars() {
        if ch == '_' {
            upper_next = true;
        } else if upper_next {
            out.push(ch.to_ascii_uppercase());
            upper_next = false;
        } else {
            out.push(ch);
        }
    }
    out
}

fn render_group(colors: &BTreeMap<String, String>) -> String {
    let mut out = String::new();
    for role in ROLES {
        let hex = colors
            .get(*role)
            .unwrap_or_else(|| panic!("matugen output missing role: {role}"));
        out.push_str(&format!("        readonly property color {}: \"{}\"\n", to_camel(role), hex));
    }
    out
}

fn main() {
    let output = Command::new("matugen")
        .args([
            "color",
            "hex",
            SEED,
            "--type",
            "scheme-tonal-spot",
            "--json",
            "hex",
            "--dry-run",
            "--quiet",
        ])
        .output()
        .expect("failed to run matugen — is it installed and on PATH?");

    if !output.status.success() {
        panic!(
            "matugen exited with {}: {}",
            output.status,
            String::from_utf8_lossy(&output.stderr)
        );
    }

    let parsed: MatugenOutput =
        serde_json::from_slice(&output.stdout).expect("failed to parse matugen JSON output");

    let qml = format!(
        "pragma Singleton\nimport QtQuick\n\nQtObject {{\n    id: root\n\n    // Generated by `cargo run -p fm-xtask` from seed {seed} via matugen\n    // (scheme-tonal-spot). Do not hand-edit — regenerate instead.\n\n    property bool darkMode: false\n\n    readonly property QtObject light: QtObject {{\n{light}    }}\n\n    readonly property QtObject dark: QtObject {{\n{dark}    }}\n\n    readonly property QtObject scheme: darkMode ? dark : light\n}}\n",
        seed = SEED,
        light = render_group(&parsed.colors.light),
        dark = render_group(&parsed.colors.dark),
    );

    let out_path = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../app/qml/tokens/Color.qml");
    std::fs::create_dir_all(out_path.parent().unwrap()).expect("failed to create tokens dir");
    std::fs::write(&out_path, qml).expect("failed to write Color.qml");
    println!("wrote {}", out_path.display());
}
```

- [ ] **Step 3: Run the generator**

Run: `cargo run -p fm-xtask`
Expected: prints `wrote .../crates/app/qml/tokens/Color.qml`, and that file now exists with 29 light + 29 dark color properties plus a `darkMode` toggle and `scheme` selector.

- [ ] **Step 4: Register the tokens directory as a QML module resource**

`crates/app/build.rs` — the `tokens/` directory needs a `qmldir`-style singleton registration. Add a `qmldir` file so `Color.qml` is recognized as a singleton import:

`crates/app/qml/tokens/qmldir`:
```
module com.filemanager.app.tokens
singleton Color 1.0 Color.qml
```

Modify `crates/app/build.rs` to add the tokens QML files to the module:
```rust
use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
    CxxQtBuilder::new_qml_module(
        QmlModule::new("com.filemanager.app")
            .qml_files([
                "qml/main.qml",
                "qml/tokens/Color.qml",
                "qml/tokens/qmldir",
            ]),
    )
    .file("src/file_list_model.rs")
    .qt_module("Gui")
    .build();
}
```

- [ ] **Step 5: Build**

Run: `cargo build -p fm-app`
Expected: builds successfully. The `Color` singleton is not imported anywhere yet (later tasks do that), so this step only proves the module registers and compiles.

- [ ] **Step 6: Commit**

```bash
git add Cargo.toml crates/xtask/Cargo.toml crates/xtask/src/main.rs crates/app/build.rs crates/app/qml/tokens/Color.qml crates/app/qml/tokens/qmldir
git commit -m "feat(app): generate M3 color tokens from seed via matugen"
```

---

### Task 2: Type, Shape, Elevation, and Motion token singletons

**Files:**
- Create: `crates/app/qml/tokens/Type.qml`
- Create: `crates/app/qml/tokens/Shape.qml`
- Create: `crates/app/qml/tokens/Elevation.qml`
- Create: `crates/app/qml/tokens/Motion.qml`
- Modify: `crates/app/qml/tokens/qmldir`
- Modify: `crates/app/build.rs`

**Interfaces:**
- Consumes: `Color.scheme` (Task 1), for `Elevation.surfaceAt()`'s tonal blending.
- Produces: `Type.titleLarge` etc. (font metrics objects), `Shape.medium` etc. (corner-radius numbers), `Elevation.surfaceAt(level)` (a blended `color`), `Motion.springStandard`/`Motion.springBouncy` (property groups for `SpringAnimation`), `Motion.standard`/`Motion.emphasized` etc. (duration + `Easing.BezierCurve` pairs for `Behavior`/`NumberAnimation`). All later component tasks reference these.

- [ ] **Step 1: Write the type scale singleton**

`crates/app/qml/tokens/Type.qml`:
```qml
pragma Singleton
import QtQuick

QtObject {
    // M3 baseline + emphasized type scale (Roboto). Sizes in px (1sp == 1px here).
    readonly property QtObject displayLarge: QtObject {
        readonly property string family: "Roboto"
        readonly property int weight: Font.Normal
        readonly property int size: 57
    }
    readonly property QtObject headlineSmall: QtObject {
        readonly property string family: "Roboto"
        readonly property int weight: Font.Normal
        readonly property int size: 24
    }
    readonly property QtObject titleLarge: QtObject {
        readonly property string family: "Roboto"
        readonly property int weight: Font.Normal
        readonly property int size: 22
    }
    readonly property QtObject titleLargeEmphasized: QtObject {
        readonly property string family: "Roboto"
        readonly property int weight: Font.Bold
        readonly property int size: 22
    }
    readonly property QtObject titleMedium: QtObject {
        readonly property string family: "Roboto"
        readonly property int weight: Font.Medium
        readonly property int size: 16
    }
    readonly property QtObject bodyLarge: QtObject {
        readonly property string family: "Roboto"
        readonly property int weight: Font.Normal
        readonly property int size: 16
    }
    readonly property QtObject bodyMedium: QtObject {
        readonly property string family: "Roboto"
        readonly property int weight: Font.Normal
        readonly property int size: 14
    }
    readonly property QtObject labelLarge: QtObject {
        readonly property string family: "Roboto"
        readonly property int weight: Font.Medium
        readonly property int size: 14
    }
}
```

- [ ] **Step 2: Write the shape scale singleton**

`crates/app/qml/tokens/Shape.qml`:
```qml
pragma Singleton
import QtQuick

QtObject {
    // M3 shape corner radii, including the Expressive-update expanded tokens.
    readonly property int none: 0
    readonly property int extraSmall: 4
    readonly property int small: 8
    readonly property int medium: 12
    readonly property int large: 16
    readonly property int largeIncreased: 20
    readonly property int extraLarge: 28
    readonly property int extraLargeIncreased: 32
    readonly property int extraExtraLarge: 48
    readonly property int full: 9999
}
```

- [ ] **Step 3: Write the elevation singleton**

`crates/app/qml/tokens/Elevation.qml`:
```qml
pragma Singleton
import QtQuick
import com.filemanager.app 1.0

QtObject {
    // M3 elevation is communicated via tonal surface tint, not shadows.
    // Percentages are the primary-color overlay strength at each level.
    readonly property var percentages: [0, 0.05, 0.08, 0.11, 0.12, 0.14]

    function surfaceAt(level) {
        var pct = percentages[level] !== undefined ? percentages[level] : 0
        var base = Color.scheme.surface
        var tint = Color.scheme.primary
        return Qt.rgba(
            base.r + (tint.r - base.r) * pct,
            base.g + (tint.g - base.g) * pct,
            base.b + (tint.b - base.b) * pct,
            1.0
        )
    }
}
```

- [ ] **Step 4: Write the motion singleton**

`crates/app/qml/tokens/Motion.qml`:
```qml
pragma Singleton
import QtQuick

QtObject {
    // Component-level motion: spring physics (QML SpringAnimation), tuned for
    // an M3 Expressive feel. Not a numeric port of Compose's MotionScheme —
    // QML's spring/damping units aren't equivalent to Compose's stiffness/
    // dampingRatio, so these are hand-tuned for the same *character*
    // (snappy, standard = minimal overshoot, bouncy = visible overshoot).
    readonly property QtObject springStandard: QtObject {
        readonly property real spring: 4.0
        readonly property real damping: 0.5
    }
    readonly property QtObject springBouncy: QtObject {
        readonly property real spring: 3.0
        readonly property real damping: 0.25
    }

    // Screen-level transitions: M3 easing/duration pairs (CSS cubic-bezier
    // control points, expressed as QML's single-cubic-segment bezierCurve:
    // [x1, y1, x2, y2, 1, 1]).
    readonly property QtObject standard: QtObject {
        readonly property int duration: 300
        readonly property var bezier: [0.2, 0, 0, 1, 1, 1]
    }
    readonly property QtObject standardDecelerate: QtObject {
        readonly property int duration: 250
        readonly property var bezier: [0, 0, 0, 1, 1, 1]
    }
    readonly property QtObject standardAccelerate: QtObject {
        readonly property int duration: 200
        readonly property var bezier: [0.3, 0, 1, 1, 1, 1]
    }
    readonly property QtObject emphasized: QtObject {
        readonly property int duration: 500
        readonly property var bezier: [0.2, 0, 0, 1, 1, 1]
    }
    readonly property QtObject emphasizedDecelerate: QtObject {
        readonly property int duration: 400
        readonly property var bezier: [0.05, 0.7, 0.1, 1, 1, 1]
    }
    readonly property QtObject emphasizedAccelerate: QtObject {
        readonly property int duration: 200
        readonly property var bezier: [0.3, 0, 0.8, 0.15, 1, 1]
    }
}
```

- [ ] **Step 5: Register the new singletons**

`crates/app/qml/tokens/qmldir`:
```
module com.filemanager.app.tokens
singleton Color 1.0 Color.qml
singleton Type 1.0 Type.qml
singleton Shape 1.0 Shape.qml
singleton Elevation 1.0 Elevation.qml
singleton Motion 1.0 Motion.qml
```

`crates/app/build.rs`:
```rust
use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
    CxxQtBuilder::new_qml_module(
        QmlModule::new("com.filemanager.app")
            .qml_files([
                "qml/main.qml",
                "qml/tokens/Color.qml",
                "qml/tokens/Type.qml",
                "qml/tokens/Shape.qml",
                "qml/tokens/Elevation.qml",
                "qml/tokens/Motion.qml",
                "qml/tokens/qmldir",
            ]),
    )
    .file("src/file_list_model.rs")
    .qt_module("Gui")
    .build();
}
```

- [ ] **Step 6: Build**

Run: `cargo build -p fm-app`
Expected: builds successfully.

- [ ] **Step 7: Commit**

```bash
git add crates/app/qml/tokens/Type.qml crates/app/qml/tokens/Shape.qml crates/app/qml/tokens/Elevation.qml crates/app/qml/tokens/Motion.qml crates/app/qml/tokens/qmldir crates/app/build.rs
git commit -m "feat(app): add Type, Shape, Elevation, and Motion token singletons"
```

---

### Task 3: Vendor the MatrialShapes shape-morphing library

**Files:**
- Create: `crates/app/qml/shapes/material-shapes.js`
- Create: `crates/app/qml/shapes/MorphShape.qml`
- Create: `crates/app/qml/shapes/geometry/offset.js`
- Create: `crates/app/qml/shapes/graphics/matrix.js`
- Create: `crates/app/qml/shapes/shapes/corner-rounding.js`
- Create: `crates/app/qml/shapes/shapes/cubic.js`
- Create: `crates/app/qml/shapes/shapes/feature.js`
- Create: `crates/app/qml/shapes/shapes/feature-mapping.js`
- Create: `crates/app/qml/shapes/shapes/float-mapping.js`
- Create: `crates/app/qml/shapes/shapes/morph.js`
- Create: `crates/app/qml/shapes/shapes/point.js`
- Create: `crates/app/qml/shapes/shapes/polygon-measure.js`
- Create: `crates/app/qml/shapes/shapes/rounded-corner.js`
- Create: `crates/app/qml/shapes/shapes/rounded-polygon.js`
- Create: `crates/app/qml/shapes/shapes/utils.js`
- Modify: `crates/app/build.rs`

**Interfaces:**
- Consumes: nothing from earlier tasks (pure QtQuick/JS, no dependency on tokens or Quickshell).
- Produces: `MorphShape` (a `Canvas`-based QML type taking `expanded: bool`, `color`, and geometry properties, animating between two polygon states — see the source for its full property list). Not consumed by any other task in this plan — vendored for a future component (see the Global Constraints note above).

- [ ] **Step 1: Copy the files verbatim**

Copy every file listed above from `~/.config/quickshell/modules/MatrialShapes/` to the matching path under `crates/app/qml/shapes/` (e.g. `~/.config/quickshell/modules/MatrialShapes/material-shapes.js` → `crates/app/qml/shapes/material-shapes.js`, `~/.config/quickshell/modules/MatrialShapes/shapes/morph.js` → `crates/app/qml/shapes/shapes/morph.js`). Do not modify their contents — they only `import QtQuick` and reference each other via relative paths, with no Quickshell-specific imports, so no adaptation is needed. Skip `ExampleSquincle.qml`, `example.qml`, and `ShapeCanvas.qml` from the source directory — those are the quickshell project's own demo/preview files, not part of the reusable library.

Run: `diff -r ~/.config/quickshell/modules/MatrialShapes/shapes crates/app/qml/shapes/shapes` and `diff ~/.config/quickshell/modules/MatrialShapes/material-shapes.js crates/app/qml/shapes/material-shapes.js` (and similarly for `MorphShape.qml`, `geometry/offset.js`, `graphics/matrix.js`) to confirm byte-for-byte copies.
Expected: no diff output.

- [ ] **Step 2: Register the shape files in the build**

`crates/app/build.rs` — add every copied file to `qml_files`:
```rust
use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
    CxxQtBuilder::new_qml_module(
        QmlModule::new("com.filemanager.app")
            .qml_files([
                "qml/main.qml",
                "qml/tokens/Color.qml",
                "qml/tokens/Type.qml",
                "qml/tokens/Shape.qml",
                "qml/tokens/Elevation.qml",
                "qml/tokens/Motion.qml",
                "qml/tokens/qmldir",
                "qml/shapes/material-shapes.js",
                "qml/shapes/MorphShape.qml",
                "qml/shapes/geometry/offset.js",
                "qml/shapes/graphics/matrix.js",
                "qml/shapes/shapes/corner-rounding.js",
                "qml/shapes/shapes/cubic.js",
                "qml/shapes/shapes/feature.js",
                "qml/shapes/shapes/feature-mapping.js",
                "qml/shapes/shapes/float-mapping.js",
                "qml/shapes/shapes/morph.js",
                "qml/shapes/shapes/point.js",
                "qml/shapes/shapes/polygon-measure.js",
                "qml/shapes/shapes/rounded-corner.js",
                "qml/shapes/shapes/rounded-polygon.js",
                "qml/shapes/shapes/utils.js",
            ]),
    )
    .file("src/file_list_model.rs")
    .qt_module("Gui")
    .build();
}
```

- [ ] **Step 3: Build**

Run: `cargo build -p fm-app`
Expected: builds successfully.

- [ ] **Step 4: Commit**

```bash
git add crates/app/qml/shapes crates/app/build.rs
git commit -m "feat(app): vendor MatrialShapes shape-morphing library"
```

---

### Task 4: Vendor and adapt Ripple and Icon components

**Files:**
- Create: `crates/app/qml/components/Ripple.qml`
- Create: `crates/app/qml/components/Icon.qml`
- Create: `crates/app/qml/components/qmldir`
- Modify: `crates/app/build.rs`

**Interfaces:**
- Consumes: `Color.scheme.primary`, `Motion.standard` (Task 1, 2).
- Produces: `Ripple { anchors.fill: parent; radius: ...; onClicked: ... }` (hover tint + press ripple, with `containsMouse`/`pressed` aliases), `Icon { content: "folder"; iconSize: 20 }` (renders a Material Symbols Rounded glyph). Task 5 (Button) and Task 6 (list item, top app bar) both use these.

- [ ] **Step 1: Adapt Ripple.qml**

Port `~/.config/quickshell/modules/customComponents/RippleEffect.qml`, repointing its `qs.modules.utils`/`qs.modules.settings` singleton references (`Colors`, `Appearance`) to this project's own tokens (`Color`, `Motion`) and dropping the `qs.modules.*` imports:

`crates/app/qml/components/Ripple.qml`:
```qml
import QtQuick
import Qt5Compat.GraphicalEffects
import com.filemanager.app 1.0

// Drop-in interactive overlay: hover tint + M3-style press ripple.
//
//   Rectangle {
//       radius: 12
//       Ripple {
//           anchors.fill: parent
//           radius: parent.radius
//           onClicked: doSomething()
//       }
//   }
Item {
    id: root

    property real radius:            0
    property real topLeftRadius:     radius
    property real topRightRadius:    radius
    property real bottomLeftRadius:  radius
    property real bottomRightRadius: radius

    property color hoverColor:  Qt.alpha(Color.scheme.primary, 0.08)
    property color pressColor:  Qt.alpha(Color.scheme.primary, 0.14)
    property color rippleColor: Qt.alpha(Color.scheme.primary, 0.25)
    property bool  hoverEnabled: true

    readonly property alias containsMouse: _mouse.containsMouse
    readonly property alias pressed:       _mouse.pressed

    signal clicked
    signal rightClicked

    Rectangle {
        anchors.fill: parent
        topLeftRadius:     root.topLeftRadius
        topRightRadius:    root.topRightRadius
        bottomLeftRadius:  root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        color: _mouse.containsMouse ? root.hoverColor : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Item {
        id: _rippleClip
        anchors.fill: parent

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width:              _rippleClip.width
                height:             _rippleClip.height
                topLeftRadius:     root.topLeftRadius
                topRightRadius:    root.topRightRadius
                bottomLeftRadius:  root.bottomLeftRadius
                bottomRightRadius: root.bottomRightRadius
            }
        }

        Rectangle {
            id: _ripple
            width: 0; height: 0
            radius: width / 2
            opacity: 0
            color: root.rippleColor
            transform: Translate { x: -_ripple.width / 2; y: -_ripple.height / 2 }
        }
    }

    SequentialAnimation {
        id: _anim
        property real px: 0; property real py: 0; property real r: 0

        PropertyAction { target: _ripple; property: "x";       value: _anim.px }
        PropertyAction { target: _ripple; property: "y";       value: _anim.py }
        PropertyAction { target: _ripple; property: "width";   value: 0 }
        PropertyAction { target: _ripple; property: "height";  value: 0 }
        PropertyAction { target: _ripple; property: "opacity"; value: 1 }
        NumberAnimation {
            target: _ripple; properties: "width,height"
            to: _anim.r * 2
            duration: Motion.standard.duration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: _ripple; property: "opacity"; to: 0
            duration: Motion.standardAccelerate.duration
            easing.type: Easing.InOutCubic
        }
    }

    MouseArea {
        id: _mouse
        anchors.fill: parent
        hoverEnabled: root.hoverEnabled
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onPressed: event => {
            const d = (ox, oy) => ox*ox + oy*oy
            _anim.px = event.x; _anim.py = event.y
            _anim.r = Math.sqrt(Math.max(
                d(event.x, event.y), d(event.x, height - event.y),
                d(width - event.x, event.y), d(width - event.x, height - event.y)
            ))
            _anim.restart()
        }

        onClicked: mouse => mouse.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }
}
```

- [ ] **Step 2: Adapt Icon.qml**

Port `~/.config/quickshell/modules/customComponents/MaterialIconSymbol.qml`. The original extends a project-local `CustomText` component; since this project has no equivalent yet, extend `Text` directly instead — the only real content (the variable-font configuration) is unchanged:

`crates/app/qml/components/Icon.qml`:
```qml
import QtQuick

Text {
    id: root
    property real iconSize: 16
    property real fill: 0
    property real truncatedFill: Math.round(fill * 100) / 100

    property string content: ""
    text: content

    font {
        hintingPreference: Font.PreferFullHinting
        family: "Material Symbols Rounded"
        pixelSize: iconSize
        weight: Font.Normal + (Font.DemiBold - Font.Normal) * fill
        variableAxes: {
            "FILL": truncatedFill,
            "opsz": iconSize,
        }
    }
}
```

- [ ] **Step 3: Register the components module**

`crates/app/qml/components/qmldir`:
```
module com.filemanager.app.components
Ripple 1.0 Ripple.qml
Icon 1.0 Icon.qml
```

`crates/app/build.rs` — add the new files:
```rust
    .qml_files([
        "qml/main.qml",
        "qml/tokens/Color.qml",
        "qml/tokens/Type.qml",
        "qml/tokens/Shape.qml",
        "qml/tokens/Elevation.qml",
        "qml/tokens/Motion.qml",
        "qml/tokens/qmldir",
        "qml/shapes/material-shapes.js",
        "qml/shapes/MorphShape.qml",
        "qml/shapes/geometry/offset.js",
        "qml/shapes/graphics/matrix.js",
        "qml/shapes/shapes/corner-rounding.js",
        "qml/shapes/shapes/cubic.js",
        "qml/shapes/shapes/feature.js",
        "qml/shapes/shapes/feature-mapping.js",
        "qml/shapes/shapes/float-mapping.js",
        "qml/shapes/shapes/morph.js",
        "qml/shapes/shapes/point.js",
        "qml/shapes/shapes/polygon-measure.js",
        "qml/shapes/shapes/rounded-corner.js",
        "qml/shapes/shapes/rounded-polygon.js",
        "qml/shapes/shapes/utils.js",
        "qml/components/Ripple.qml",
        "qml/components/Icon.qml",
        "qml/components/qmldir",
    ]),
```

- [ ] **Step 4: Build**

Run: `cargo build -p fm-app`
Expected: builds successfully. If it fails on `Qt5Compat.GraphicalEffects` not being found, add `.qt_module("Qt5Compat")` to the `CxxQtBuilder` chain in `build.rs` and rebuild.

- [ ] **Step 5: Commit**

```bash
git add crates/app/qml/components crates/app/build.rs
git commit -m "feat(app): add Ripple and Icon components adapted from quickshell"
```

---

### Task 5: M3 Button component with spring-animated press state

**Files:**
- Create: `crates/app/qml/components/Button.qml`
- Modify: `crates/app/qml/components/qmldir`
- Modify: `crates/app/build.rs`

**Interfaces:**
- Consumes: `Color.scheme.*`, `Type.labelLarge`, `Shape.full`/`Shape.large`, `Motion.springStandard`, `Ripple`, `Icon` (Tasks 1, 2, 4).
- Produces: `Button { variant: "filled" | "outlined" | "text" | "tonal" | "elevated"; text: "..."; icon: "add"; onClicked: ... }`. Task 6 (the "New folder" action) uses this. Its "shape change on press" is a corner-radius `SpringAnimation` (full pill → medium-rounded rect), not the `MatrialShapes` polygon morph from Task 3 — see the Global Constraints note on why those are kept separate in this plan.

- [ ] **Step 1: Write the component**

`crates/app/qml/components/Button.qml`:
```qml
import QtQuick
import com.filemanager.app 1.0

Item {
    id: root

    property string variant: "filled" // filled | outlined | text | tonal | elevated
    property string text: ""
    property string icon: ""
    signal clicked

    implicitWidth: _row.implicitWidth + 48
    implicitHeight: 40

    readonly property color _containerColor: {
        if (variant === "filled") return Color.scheme.primary
        if (variant === "tonal") return Color.scheme.secondaryContainer
        if (variant === "elevated") return Elevation.surfaceAt(1)
        return "transparent"
    }
    readonly property color _labelColor: {
        if (variant === "filled") return Color.scheme.onPrimary
        if (variant === "tonal") return Color.scheme.onSecondaryContainer
        return Color.scheme.primary
    }

    Rectangle {
        id: _background
        anchors.fill: parent
        radius: pressArea.pressed ? Shape.medium : Shape.full
        color: root._containerColor
        border.width: root.variant === "outlined" ? 1 : 0
        border.color: Color.scheme.outline

        Behavior on radius {
            SpringAnimation {
                spring: Motion.springStandard.spring
                damping: Motion.springStandard.damping
            }
        }

        Ripple {
            id: pressArea
            anchors.fill: parent
            radius: parent.radius
            hoverColor: Qt.alpha(root._labelColor, 0.08)
            rippleColor: Qt.alpha(root._labelColor, 0.2)
            onClicked: root.clicked()
        }
    }

    Row {
        id: _row
        anchors.centerIn: parent
        spacing: 8

        Icon {
            visible: root.icon.length > 0
            content: root.icon
            iconSize: 18
            color: root._labelColor
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.text
            color: root._labelColor
            font.family: Type.labelLarge.family
            font.weight: Type.labelLarge.weight
            font.pixelSize: Type.labelLarge.size
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
```

- [ ] **Step 2: Register it**

`crates/app/qml/components/qmldir`:
```
module com.filemanager.app.components
Ripple 1.0 Ripple.qml
Icon 1.0 Icon.qml
Button 1.0 Button.qml
```

`crates/app/build.rs` — add `"qml/components/Button.qml"` to the `qml_files` list.

- [ ] **Step 3: Build**

Run: `cargo build -p fm-app`
Expected: builds successfully.

- [ ] **Step 4: Commit**

```bash
git add crates/app/qml/components/Button.qml crates/app/qml/components/qmldir crates/app/build.rs
git commit -m "feat(app): add M3 Button component with spring-animated press state"
```

---

### Task 6: M3 list item delegate and top app bar, applied to main.qml

**Files:**
- Create: `crates/app/qml/components/FileListItem.qml`
- Create: `crates/app/qml/components/TopAppBar.qml`
- Modify: `crates/app/qml/components/qmldir`
- Modify: `crates/app/qml/main.qml`
- Modify: `crates/app/build.rs`

**Interfaces:**
- Consumes: `Color.scheme.*`, `Type.*`, `Shape.*`, `Ripple`, `Icon` (Tasks 1, 2, 4); `FileListModel`'s roles `name`/`isDir`/`size`/`iconKey` and its `deleteEntry(name)` invokable (Plan 2, unchanged).
- Produces: `FileListItem` (a `ListView` delegate showing icon/name/size with a delete action), `TopAppBar { title: "..." }`. `main.qml` wires both in; no new interface for later tasks (this is the last task in the plan).

- [ ] **Step 1: Write the list item delegate**

`crates/app/qml/components/FileListItem.qml`:
```qml
import QtQuick
import com.filemanager.app 1.0

Item {
    id: root

    // Set by the ListView's model role bindings (name, isDir, size, iconKey)
    // plus the containing view's own `model` (the FileListModel instance),
    // used here only to call deleteEntry.
    required property string name
    required property bool isDir
    required property int size
    required property string iconKey
    property var fileModel

    width: ListView.view ? ListView.view.width : 0
    height: 56

    Rectangle {
        anchors.fill: parent
        color: _itemArea.containsMouse ? Elevation.surfaceAt(1) : "transparent"
        radius: Shape.small

        Behavior on color { ColorAnimation { duration: Motion.standard.duration } }

        Ripple {
            id: _itemArea
            anchors.fill: parent
            radius: parent.radius
        }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 16

        Icon {
            content: root.isDir ? "folder" : "description"
            iconSize: 24
            color: Color.scheme.onSurfaceVariant
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            width: parent.width - 24 - 24 - 32
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: root.name
                color: Color.scheme.onSurface
                font.family: Type.bodyLarge.family
                font.weight: Type.bodyLarge.weight
                font.pixelSize: Type.bodyLarge.size
                elide: Text.ElideMiddle
                width: parent.width
            }

            Text {
                text: root.isDir ? "" : (root.size + " bytes")
                visible: text.length > 0
                color: Color.scheme.onSurfaceVariant
                font.family: Type.bodyMedium.family
                font.weight: Type.bodyMedium.weight
                font.pixelSize: Type.bodyMedium.size
            }
        }

        Icon {
            content: "delete"
            iconSize: 20
            color: Color.scheme.onSurfaceVariant
            anchors.verticalCenter: parent.verticalCenter

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: root.fileModel.deleteEntry(root.name)
            }
        }
    }
}
```

- [ ] **Step 2: Write the top app bar**

`crates/app/qml/components/TopAppBar.qml`:
```qml
import QtQuick
import com.filemanager.app 1.0

Rectangle {
    id: root

    property string title: ""

    height: 64
    color: Elevation.surfaceAt(2)

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        color: Color.scheme.onSurface
        font.family: Type.titleLargeEmphasized.family
        font.weight: Type.titleLargeEmphasized.weight
        font.pixelSize: Type.titleLargeEmphasized.size
        elide: Text.ElideMiddle
        width: parent.width - 32
    }
}
```

- [ ] **Step 3: Register both**

`crates/app/qml/components/qmldir`:
```
module com.filemanager.app.components
Ripple 1.0 Ripple.qml
Icon 1.0 Icon.qml
Button 1.0 Button.qml
FileListItem 1.0 FileListItem.qml
TopAppBar 1.0 TopAppBar.qml
```

`crates/app/build.rs` — add `"qml/components/FileListItem.qml"` and `"qml/components/TopAppBar.qml"` to `qml_files`.

- [ ] **Step 4: Rebuild main.qml on the M3 components**

`crates/app/qml/main.qml`:
```qml
import QtQuick
import QtQuick.Window
import com.filemanager.app 1.0
import com.filemanager.app 1.0
import com.filemanager.app 1.0

Window {
    id: window
    width: 800
    height: 600
    visible: true
    title: "File Manager"
    color: Color.scheme.surface

    FileListModel {
        id: fileModel

        Component.onCompleted: navigate(Qt.application.arguments.length > 1
            ? Qt.application.arguments[1]
            : "/home")
    }

    Column {
        anchors.fill: parent

        TopAppBar {
            width: parent.width
            title: fileModel.currentPath
        }

        Row {
            width: parent.width
            height: 56
            spacing: 8
            leftPadding: 16
            topPadding: 8
            bottomPadding: 8

            TextInput {
                id: newFolderName
                width: 200
                anchors.verticalCenter: parent.verticalCenter
                color: Color.scheme.onSurface
                font.family: Type.bodyLarge.family
                font.pixelSize: Type.bodyLarge.size
            }

            Button {
                variant: "tonal"
                text: "New folder"
                icon: "create_new_folder"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: fileModel.createFolder(newFolderName.text)
            }
        }

        ListView {
            width: parent.width
            height: parent.height - 64 - 56
            model: fileModel
            delegate: FileListItem {
                fileModel: fileModel
            }
        }
    }
}
```

- [ ] **Step 5: Build**

Run: `cargo build -p fm-app`
Expected: builds successfully.

- [ ] **Step 6: Manual verification**

Run: `QT_QPA_PLATFORM=offscreen timeout 5 cargo run -p fm-app -- /tmp`
Expected: no crash, no QML error on stderr. Per this plan's Global Constraints and Plan 2's documented finding, this sandboxed environment may hang with zero output regardless of correctness — if so, `cargo build -p fm-app` succeeding is the verification ceiling here; report it as such rather than claiming an interactive pass. If a real, reachable desktop session is available, run `cargo run -p fm-app -- $HOME` and confirm interactively: top app bar shows the path, the file list renders with M3-styled rows (icon, name, size, hover tint, ripple on click), "New folder" creates a folder via the tonal button, and the delete icon on a row removes that entry.

- [ ] **Step 7: Commit**

```bash
git add crates/app/qml/components/FileListItem.qml crates/app/qml/components/TopAppBar.qml crates/app/qml/components/qmldir crates/app/qml/main.qml crates/app/build.rs
git commit -m "feat(app): rebuild main.qml on M3 list item and top app bar components"
```

---

## Plan Complete

`fm-app` now presents a genuine Material 3 Expressive surface: real tonal-palette colors generated from the seed via matugen, M3 type/shape/elevation/motion tokens, ripple and spring-animated press interactions on buttons, and M3-styled list rows and a top app bar — all built on the exact same `FileListModel`, `navigate`, `createFolder`, and `deleteEntry` wiring Plan 2 already proved works end to end. Deferred beyond this plan: wiring the vendored `MatrialShapes` polygon-morph engine into a real component (e.g. an extend-on-hover FAB), dialogs (e.g. a delete confirmation), a snackbar for operation feedback, a navigation rail, sort/filter UI, dynamic/wallpaper-based color, and incremental/live-watcher model updates — each is a reasonable next slice once this base is confirmed working on a real desktop session.
