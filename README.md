# Bayesian Spatial Carbon Modeling Application

An application for estimating carbon across a landscape from field plot measurements, with a map of the prediction and its uncertainty. You interact with it entirely through a graphical interface — no R code required.

This guide is written for someone using the app, not developing it. It walks through getting set up, running a full analysis, understanding what you see on screen, and what to do when something looks wrong.

------

## 1. Getting Started

### What you need

- R (version 4.0 or newer)
- A working Tcl/Tk installation (needed for the GUI to display)
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

If that command fails because you don't have permission to install system-wide, install into your own personal library instead:

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

A window titled "Bayesian Spatial Carbon Modeling" should open. If it doesn't, re-check the package installation step above — the console output where you ran the command will usually name the missing piece.

------

## 2. Preparing Your Data

Before running anything, your input data needs to be organized in a specific folder structure — one folder per site, containing three files.

Given a site called `black-mountains`, the app expects:

```
<data_dir>/black-mountains/bnd/bnd.shp        (boundary polygon)
<data_dir>/black-mountains/plots/plots.shp    (field plot points)
<data_dir>/black-mountains/carbon-map.tif     (raster covariate)
```

- **`bnd/bnd.shp`** — a polygon shapefile defining the outer edge of your analysis area.
- **`plots/plots.shp`** — a point shapefile of your field plots. It must contain a field named `Total.Carb` with the measured carbon value at each point.
- **`carbon-map.tif`** — a single-band raster covering the boundary, used as the predictor. This is often a remote-sensing-derived layer (e.g. canopy height or biomass proxy).

A few things that will cause problems if missed:

- **All three files must share the same coordinate reference system (CRS).** Reproject in advance if they don't.
- **The raster should fully cover the boundary polygon.** Small mismatches (a few map units, from pixel alignment or rounding) are tolerated automatically — see `raster.coverage.tolerance` in [Advanced Configuration](#5-advanced-configuration).

You'll point the app at your data by setting **`data_dir`** to the parent folder (e.g. `/path/to/data`) and **`site`** to the site's folder name (e.g. `black-mountains`) — both are set from the Quick Config Shortcuts panel described below.

------

## 3. The Basic Workflow

Once your data is in place, the analysis runs as four steps, always in this order:

| Step | What it does |
|---|---|
| **Step 0: Check Inputs** | Validates your config and file paths, checks that all spatial data shares a CRS, and checks the raster covers the boundary. Catches setup problems before any modeling starts. |
| **Step 1: Fit Variogram** | Fits a simple (non-spatial) regression and looks at leftover spatial structure in the residuals. Produces the semivariogram plot. |
| **Step 2: Fit Spatial Model** | Fits the full Bayesian spatial model via MCMC sampling. This is usually the slowest step — minutes to many hours depending on your data size and sample settings. |
| **Step 3: Predict Outputs** | Uses the fitted model to predict carbon across the whole raster, producing both prediction files described in [Understanding the Outputs](#6-understanding-the-outputs). |

A typical first run looks like:

1. Launch the app and set `site`, `data_dir`, and `output_dir` (Quick Config Shortcuts panel).
2. Click **Step 0: Check Inputs**. Fix anything it flags before moving on.
3. Click **Step 1: Fit Variogram**. Check the semivariogram in the Plot Preview panel — it should show correlation decaying with distance, not a flat line or pure noise.
4. Click **Step 2: Fit Spatial Model**, and wait — this can take a while.
5. Click **Step 3: Predict Outputs**. Both output files are generated from this one click.

By default, the app enforces this order and won't let you skip ahead — see the **Run Workflow panel** below for how to override that if you already have outputs from a previous run.

------

## 4. The Interface: What Each Panel Does

The window is split into a left column (console and plots) and a right column (configuration and controls). This section covers each panel in the order it appears on screen.

### Console Output panel (top left)

Shows live output and status messages while a step is running, plus the full log once it finishes. **If a step fails, check here first** — the error message explaining why will be printed to this panel.

### Plot Preview panel (bottom left)

Shows the diagnostic image from whichever step you most recently ran, updating automatically when that step finishes. What you see changes depending on which step you last ran:

- **After Step 1** (the semivariogram) — one panel showing the empirical semivariogram of residuals with a fitted nugget/sill/range curve. It shows how spatial correlation decays with distance, and is the basis for the spatial model fit in Step 2.

- **After Step 2** (MCMC chain diagnostics) — six panels, one row per model parameter:

  | Row | Parameter | Trace (left) | Density (right) |
  |---|---|---|---|
  | 1 | `phi` — spatial decay rate | ✓ | ✓ |
  | 2 | `sigma.sq` — spatial variance | ✓ | ✓ |
  | 3 | `tau.sq` — nugget/error variance | ✓ | ✓ |

  The **trace** (left) panel for each row shows the sampled value at every MCMC iteration — use it to check the chain is mixing well, not drifting or stuck. The **density** (right) panel shows the posterior distribution of that parameter.

- **After Step 3** (the prediction plot) — two panels: the mean carbon prediction map on the left, and the standard deviation (uncertainty) map on the right.

### Quick Config Shortcuts panel (top right)

The fastest way to edit the settings you'll change most often, without scrolling through the full YAML file below.

| Control | What it does |
|---|---|
| Site | The site subfolder to use — must match a folder name under Data Dir. |
| Data Dir | The parent folder containing one subfolder per site. |
| Output Dir | Where results (plots, predictions, models) get written. |
| Browse | Opens a folder picker for Data Dir or Output Dir. |
| Apply To YAML | Writes Site / Data Dir / Output Dir into the YAML Editor. |
| Pull From YAML | Reloads these three fields from whatever is currently in the YAML Editor (use this if you edited the YAML directly). |

### YAML Editor panel (middle right)

The full configuration file as editable text — every setting the workflow uses, not just the three shortcut fields above. See [Advanced Configuration](#5-advanced-configuration) for what the less common settings do.

| Control | What it does |
|---|---|
| Load YAML | Opens a different config file from disk into the editor. |
| Load Template | Resets the editor to a blank starting template. |
| Save | Writes the editor's contents back to the currently loaded file. |
| Save As | Writes the editor's contents to a new file. Use this before experimenting so your working config stays untouched. |

### Run Workflow panel (lower right)

Runs the four steps described in [The Basic Workflow](#3-the-basic-workflow). Each row shows a step's current status and a button to run it.

| Control | What it does |
|---|---|
| Allow out-of-order runs | Lets you run a step before its prerequisite has completed. Leave this unchecked unless you already have the required outputs from an earlier run. |
| (status line) | The text below the checkbox shows the current status of the step that's running, or the last one that ran. |

### Help panel (bottom right, collapsed by default)

An in-app version of this walkthrough — click to expand it any time you need a reminder of what a panel or button does without leaving the app.

------

## 5. Advanced Configuration

Most first runs only need `site`, `data_dir`, `output_dir`, `n.samples`, and `n.threads` changed from their defaults. Everything else here is safe to leave alone until you have a specific reason to change it.

**Raster coverage tolerance** — controls how strictly the app checks that the raster covers the boundary polygon:

```yaml
strict.raster.coverage: false
raster.coverage.tolerance: 10
```

- `strict.raster.coverage: true` makes every step stop if the raster doesn't fully cover the boundary.
- `raster.coverage.tolerance` (in the raster's CRS units) allows small edge mismatches — useful when the raster and boundary differ by only a few map units due to pixel alignment or rounding. This check runs every time spatial data is loaded (Steps 0 through 3), not just once.

**MCMC and model settings** — the number of posterior samples, thinning, and the prior bounds/tuning values used by Step 2's spatial model. If Step 2 fails to converge or produces poor chain mixing (see the Step 2 diagnostic plots), these are the values to revisit. A reasonable approach:

1. Run Step 1 first and read the fitted nugget/sill values off the semivariogram plot.
2. Use those as a starting point for the corresponding variance settings.
3. Run Step 2, check the chain diagnostics, and adjust only if the chains look poorly mixed.

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

Step 3 always produces both `pred.tif` and `pred-joint.tif` from a single click — you don't choose between them up front, but you do choose which one to use afterward:

- **`pred.tif`** — use this for mapping and per-pixel visualization. Each pixel's uncertainty is independent of its neighbors, which is fine for displaying a map but understates uncertainty if you sum or average pixels together.
- **`pred-joint.tif`** — use this whenever you need uncertainty for an *area*: a polygon mean, a management-unit total, or any other aggregation. It preserves the spatial covariance between pixels, which per-pixel uncertainty alone can't capture.

If you're reporting a single number with a confidence interval (e.g. "total carbon in this unit ± uncertainty"), use `pred-joint.tif`. If you're making a map for visual inspection, `pred.tif` is enough.

------

## 7. Common Questions and Troubleshooting

**"There is no package called 'X'"** — you're missing an R package. See [Installing the R packages](#installing-the-r-packages) above.

**A step button is greyed out** — steps run in a fixed order (Step 0 → 1 → 2 → 3). A greyed-out step is waiting on an earlier one to complete. If you already have valid outputs from a previous run and want to skip ahead, check **Allow out-of-order runs** in the Run Workflow panel.

**I got a raster coverage warning** — your raster doesn't fully cover the boundary polygon. If the mismatch is small (pixel alignment, rounding), increase `raster.coverage.tolerance` in the YAML config. If it's a real gap in coverage, you'll need a raster that actually covers your analysis area.

**The console says "No output yet. If this persists, check package installation and config paths."** — the step process hasn't printed anything back yet. This usually means either a package failed to load or a path in your config doesn't exist; check the Console Output panel for the actual error once it appears.

**Step 2 is taking a very long time** — this is expected for large `n.samples` or big rasters; it can take minutes to many hours. If it seems stuck rather than slow, check the Console Output panel for warnings.

**The Step 2 chain diagnostic plots look noisy or don't seem to settle** — this usually means the model needs different prior bounds, tuning values, or more samples. See [Advanced Configuration](#5-advanced-configuration).

**Which output file do I need?** — see [Which prediction file should I use?](#which-prediction-file-should-i-use) above.

------

## Intended Use and Limitations

This application is intended for regional and landscape-scale carbon analysis and decision support. It is not a substitute for local field inventories, and results should be interpreted with attention to data quality, model assumptions, spatial scale, and uncertainty.

------

## Repository Contents

- `src/gui.R` — the current graphical user interface (what this guide describes)
- `src/main_gui.R` — an older GUI implementation, retained for reference
- `src/step0.R` through `src/step3.R` — the R scripts implementing each workflow step
- `src/mod.R` — shared utility and modeling functions
- `src/config.yaml` — the default configuration file
- `README.md` — this file

Most users only ever need `src/gui.R` — the step scripts are run by the GUI and aren't meant to be invoked directly, though advanced users may do so.

------

## Support and Contact

Questions, issues, and suggestions should be submitted through the project's issue tracker or directed to the repository maintainer.
