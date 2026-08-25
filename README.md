# Bayesian Spatial Carbon Modeling Application

This application estimates carbon across a landscape from field plot measurements, producing a map of the prediction along with a map of how uncertain that prediction is. You interact with it entirely through a graphical interface (GUI) — no R code required to use it.

This guide is written for someone *using* the app, not developing it. Read it top to bottom the first time: it starts with what the app does and how to get it running, walks through every part of the screen, then walks through running a real analysis and reading the results. More technical detail (how the underlying model works, advanced settings) is pushed to the end, under clearly marked sections — you shouldn't need it for a first run.

------

## 1. What This App Does

You give it two things: a set of field measurements of carbon at specific locations (plots), and a raster (grid) covering the wider landscape that's correlated with carbon (for example, a canopy height or biomass layer from remote sensing). The app then:

1. Learns the relationship between your field measurements and the raster.
2. Accounts for the fact that carbon at nearby locations tends to be similar (spatial correlation).
3. Predicts carbon at every pixel across the landscape, not just where you measured it.
4. Reports how confident that prediction is, both pixel-by-pixel and for areas/totals you might want to report.

The result is a map you can use for reporting, planning, and area-based carbon estimates — with uncertainty attached.

------

## 2. Getting Started

### What you need

- R (version 4.0 or newer)
- A working Tcl/Tk installation (needed for the GUI window to display)
- The R packages: `tcltk`, `yaml`, `terra`, `geoR`, `spBayes`

Check that R is installed:

```
R --version
```

### Installing the R packages

If you launch the app and see an error like `there is no package called 'yaml'`, install the missing packages:

```
Rscript -e "install.packages(c('yaml','terra','geoR','spBayes'), repos='https://cloud.r-project.org')"
```

(`tcltk` ships with R itself, so it doesn't need installing.)

If that fails because you don't have permission to install system-wide, install into your own personal library instead:

```
Rscript -e "install.packages(c('yaml','terra','geoR','spBayes'), repos='https://cloud.r-project.org', lib='~/R/library')"
export R_LIBS_USER=~/R/library
```

Add the `export` line to your `~/.bashrc` or `~/.zshrc` so it's set automatically in future terminal sessions.

### Launching the app

From the repository root:

```
Rscript src/gui.R
```

On Windows, you can instead open an R console and run:

```r
source("src/gui.R")
```

A window titled "Bayesian Spatial Carbon Modeling" should open. If it doesn't, re-check the package installation step above — the terminal output will usually name the missing piece.

------

## 3. Understanding the Interface

Before running anything, it helps to know what you're looking at. The window is split into a left column (console and plots) and a right column (configuration and controls). This section covers every panel, in the order it appears on screen — if you see something in the app and want to know what it's for, find its name here.

### Console Output panel (top left)

Displays live output and status messages while a step is running, and the full log once it finishes. **Look here first whenever something goes wrong** — if a step fails, the reason is printed to this panel.

### Plot Preview panel (bottom left)

Displays the diagnostic image from whichever step you most recently ran, updating automatically the moment that step finishes. This is how you check the model's behavior at each stage — see [Section 5](#5-running-your-first-analysis) for what to look for after each step. What's shown here changes depending on which step you last ran; see [Understanding the Outputs](#6-understanding-the-outputs) for the full breakdown of each image.

### Quick Config Shortcuts panel (top right)

The fastest way to edit the settings you'll change most often, without scrolling through the full YAML file below.

| Control | What it's for |
|---|---|
| Site | The site subfolder to analyze — must match a folder name under Data Dir. |
| Data Dir | The parent folder containing one subfolder per site. |
| Output Dir | Where results (plots, predictions, models) get written. |
| Browse | Opens a folder picker for Data Dir or Output Dir. |
| Apply To YAML | Writes Site / Data Dir / Output Dir into the YAML Editor panel below. |
| Pull From YAML | Reloads these three fields from whatever is currently in the YAML Editor (use this if you edited the YAML directly instead of using these fields). |

### YAML Editor panel (middle right)

The full configuration file as editable text — every setting the workflow uses, not just the three shortcut fields above. Most users won't need to touch most of it; see [Advanced Configuration](#8-advanced-configuration) for what the less common settings do.

| Control | What it's for |
|---|---|
| Load YAML | Opens a different config file from disk into the editor. |
| Load Template | Resets the editor to a blank starting template. |
| Save | Writes the editor's contents back to the currently loaded file. |
| Save As | Writes the editor's contents to a new file. Use this before experimenting so your working config stays untouched. |

### Run Workflow panel (lower right)

Where you actually run the analysis. Each row is one step, showing its current status (Pending / Running / Complete / Failed) and a button to run it.

| Step | What it does |
|---|---|
| Step 0: Check Inputs | Validates your setup before anything else runs. |
| Step 1: Fit Variogram | A quick first look at the spatial structure in your data. |
| Step 2: Fit Spatial Model | The full model fit — usually the slowest step. |
| Step 3: Predict Outputs | Produces the final prediction maps. |

(Full detail on what to expect from each step is in [Section 5](#5-running-your-first-analysis).)

| Control | What it's for |
|---|---|
| Allow out-of-order runs | Lets you run a step before its prerequisite has completed. Leave this unchecked unless you already have valid outputs from an earlier run and want to skip ahead. |
| (status line, below the checkbox) | Shows the current status of whichever step is running, or the last one that ran. |

### Help panel (bottom right, collapsed by default)

An in-app version of this interface walkthrough — click to expand it any time you need a reminder of what a panel or button does without leaving the app.

------

## 4. Preparing Your Data

Your input data needs to be organized in a specific folder structure before you can run anything — one folder per site, containing three files.

Given a site called `black-mountains`, the app expects:

```
<data_dir>/black-mountains/bnd/bnd.shp        (boundary polygon)
<data_dir>/black-mountains/plots/plots.shp    (field plot points)
<data_dir>/black-mountains/carbon-map.tif     (raster covariate)
```

- **`bnd/bnd.shp`** — a polygon shapefile defining the outer edge of your analysis area.
- **`plots/plots.shp`** — a point shapefile of your field plots. It must contain a field named `Total.Carb` with the measured carbon value at each point.
- **`carbon-map.tif`** — a single-band raster covering the boundary, used as the predictor.

Two things that will cause problems if missed:

- **All three files must share the same coordinate reference system (CRS).** Reproject in advance if they don't.
- **The raster should fully cover the boundary polygon.** Small mismatches (a few map units, from pixel alignment or rounding) are tolerated automatically — see [Advanced Configuration](#8-advanced-configuration).

Point the app at your data using the **Quick Config Shortcuts panel**: set `Data Dir` to the parent folder (e.g. `/path/to/data`) and `Site` to the site's folder name (e.g. `black-mountains`).

------

## 5. Running Your First Analysis

Run the four steps in order, using the buttons in the **Run Workflow panel**. You can't normally skip ahead — see that panel's description above. For each step below, run it, then check the **Console Output** and **Plot Preview** panels before moving on.

### Step 0: Check Inputs

Validates your config and file paths, checks that all spatial data shares a CRS, and checks the raster covers the boundary.

- **What to check:** the Console Output panel prints a pass/fail line for each item it validates. Look for `Input validation complete.`
- **If something's wrong:** the console names the specific problem (missing file, CRS mismatch, raster coverage) — see [Common Questions and Troubleshooting](#7-common-questions-and-troubleshooting).

### Step 1: Fit Variogram

Fits a simple (non-spatial) regression and looks at leftover spatial structure in the residuals.

- **What to check:** the Console Output panel prints the estimated nugget and sill values. The Plot Preview panel shows the semivariogram — you want to see correlation *decreasing* with distance (a downward or leveling-off curve), not a flat line or pure scatter. A flat line suggests little spatial structure for the spatial model in Step 2 to capture.

### Step 2: Fit Spatial Model

Fits the full spatial model using MCMC sampling. **This is usually the slowest step** — anywhere from minutes to many hours depending on your raster size and sample settings.

- **What to check:** once it finishes, the Plot Preview panel shows six panels (trace and density for each of three parameters). In the trace panels (left column), you want to see a chain that looks like a stable, noisy band — not one that drifts steadily in one direction or gets stuck flat for long stretches.
- **If the chains look bad:** see [Advanced Configuration](#8-advanced-configuration) for what to adjust.

### Step 3: Predict Outputs

Uses the fitted model to predict carbon across the whole raster. One click produces both output files described in [Understanding the Outputs](#6-understanding-the-outputs).

- **What to check:** the Plot Preview panel shows the mean prediction map (left) and the uncertainty map (right). The mean map should resemble the shape and spatial pattern of your input raster; the uncertainty map is typically lowest near your field plots and higher farther away.
- **When it's done**, you're finished — head to [Understanding the Outputs](#6-understanding-the-outputs) to see what to do with the results.

------

## 6. Understanding the Outputs

Results are written to a site-specific subfolder under your configured Output Dir. A full run produces:

| File | From | What it is |
|---|---|---|
| `semivariogram.png` | Step 1 | The residual semivariogram plot |
| `chainImg.png` | Step 2 | The MCMC chain diagnostic plot |
| `m.1.RData` | Step 2 | The fitted spatial model |
| `pred.tif` | Step 3 | Per-pixel mean and standard deviation prediction layers |
| `m.1.pred.RData` | Step 3 | Serialized per-pixel predictive samples |
| `pred-joint.tif` | Step 3 | Joint predictive samples, for aggregation-aware uncertainty |
| `m.1.pred.joint.RData` | Step 3 | Serialized joint predictive samples |

### Which prediction file should I use?

Step 3 always produces both `pred.tif` and `pred-joint.tif` — you don't choose between them up front, but you do choose which one to use afterward:

- **`pred.tif`** — use this for mapping and per-pixel visualization. Fine for a map, but understates uncertainty if you sum or average pixels together, because it treats each pixel's uncertainty as independent of its neighbors.
- **`pred-joint.tif`** — use this whenever you need uncertainty for an *area*: a polygon mean, a management-unit total, or any other aggregation. It preserves the spatial covariance between pixels, which per-pixel uncertainty alone can't capture.

If you're reporting a single number with a confidence interval (e.g. "total carbon in this unit ± uncertainty"), use `pred-joint.tif`. If you're making a map for visual inspection, `pred.tif` is enough.

### Reading the diagnostic plots in detail

Full panel-by-panel detail for each diagnostic image (what each row/column of the Step 1, 2, and 3 plots shows) is in the **Plot Preview panel** description in [Section 3](#3-understanding-the-interface).

------

## 7. Common Questions and Troubleshooting

**"There is no package called 'X'"** — you're missing an R package. See [Installing the R packages](#installing-the-r-packages) in Getting Started.

**A step button is greyed out** — steps run in a fixed order (Step 0 → 1 → 2 → 3). A greyed-out step is waiting on an earlier one to complete. If you already have valid outputs from a previous run and want to skip ahead, check **Allow out-of-order runs** in the Run Workflow panel.

**I got a raster coverage warning** — your raster doesn't fully cover the boundary polygon. If the mismatch is small (pixel alignment, rounding), increase `raster.coverage.tolerance` in the YAML config (see [Advanced Configuration](#8-advanced-configuration)). If it's a real gap in coverage, you'll need a raster that actually covers your analysis area.

**The console says "No output yet. If this persists, check package installation and config paths."** — the step process hasn't printed anything back yet. This usually means either a package failed to load or a path in your config doesn't exist; check the Console Output panel for the actual error once it appears.

**Step 2 is taking a very long time** — this is expected for large `n.samples` or big rasters; it can take minutes to many hours. If it seems stuck rather than slow, check the Console Output panel for warnings.

**The Step 2 chain diagnostic plots look noisy or don't seem to settle** — this usually means the model needs different prior bounds, tuning values, or more samples. See [Advanced Configuration](#8-advanced-configuration).

**Which output file do I need?** — see [Which prediction file should I use?](#which-prediction-file-should-i-use) in Understanding the Outputs.

------

## 8. Advanced Configuration

Most first runs only need `site`, `data_dir`, `output_dir`, `n.samples`, and `n.threads` changed from their defaults — set from the **Quick Config Shortcuts panel** or directly in the **YAML Editor panel**. Everything in this section is safe to leave alone until you have a specific reason to change it.

**Raster coverage tolerance** — controls how strictly the app checks that the raster covers the boundary polygon:

```yaml
strict.raster.coverage: false
raster.coverage.tolerance: 10
```

- `strict.raster.coverage: true` makes every step stop if the raster doesn't fully cover the boundary.
- `raster.coverage.tolerance` (in the raster's CRS units) allows small edge mismatches. This check runs every time spatial data is loaded (Steps 0 through 3), not just once.

**MCMC and model settings** — the number of posterior samples, thinning, and the prior bounds/tuning values used by Step 2's spatial model. If Step 2 produces poor chain mixing (see [Section 5](#5-running-your-first-analysis)), these are the values to revisit:

1. Run Step 1 first and read the fitted nugget/sill values off the semivariogram plot.
2. Use those as a starting point for the corresponding variance settings.
3. Run Step 2, check the chain diagnostics, and adjust only if the chains look poorly mixed.

------

## 9. Intended Use and Limitations

This application is intended for regional and landscape-scale carbon analysis and decision support. It is not a substitute for local field inventories, and results should be interpreted with attention to data quality, model assumptions, spatial scale, and uncertainty.

------

## 10. Repository Contents

For reference, this is what's in the repository (most users only ever interact with `src/gui.R`):

- `src/gui.R` — the current graphical user interface (what this guide describes)
- `src/main_gui.R` — an older GUI implementation, retained for reference
- `src/step0.R` through `src/step3.R` — the R scripts implementing each workflow step
- `src/mod.R` — shared utility and modeling functions
- `src/config.yaml` — the default configuration file
- `README.md` — this file

The step scripts are run by the GUI and aren't meant to be invoked directly, though advanced users may do so.

------

## Support and Contact

Questions, issues, and suggestions should be submitted through the project's issue tracker or directed to the repository maintainer.
