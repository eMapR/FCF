# Spatial Carbon Model (R)

This repository contains an **R-based Bayesian spatial modeling workflow** for producing wall-to-wall carbon predictions and associated uncertainty from plot data and a gridded covariate.

The workflow is intended for **land managers, analysts, and researchers** who need spatially explicit carbon estimates along with defensible uncertainty for mapping and area-based summaries.

---

## What this does (plain language)

You provide:
- field plot measurements of carbon, and
- a raster covariate covering the full landscape.

The model:
1. learns the relationship between plot measurements and the raster,
2. accounts for remaining spatial structure in the data, and
3. predicts carbon everywhere ? **with uncertainty**.

Outputs include:
- a prediction map,
- an uncertainty map, and
- joint predictive draws for computing uncertainty on area-based estimates.

---

## Repository structure

.
??? R/
? ??? step0.R # input checks & data loading
? ??? step1.R # linear model + variogram
? ??? step2.R # Bayesian spatial model (MCMC)
? ??? step3.R # prediction & uncertainty maps
? ??? mod.R # shared model utilities
? ??? gui.R # optional GUI
? ??? main_gui.R # GUI entry point
??? config.yaml # run configuration (paths, priors, tuning)
??? README.md


---

## Requirements

- R (>= 4.0 recommended)
- R packages:
  - `terra`
  - `geoR`
  - `spBayes`
  - `yaml`
  - `tcltk` (optional; only needed for the GUI)

Install required packages with:

```r
install.packages(c("terra", "geoR", "spBayes", "yaml"))
Input data layout
Your data directory must follow this structure:

<data_dir>/<site>/
  ??? bnd/
  ?   ??? bnd.shp              # boundary polygon
  ??? plots/
  ?   ??? plots.shp            # plot points with field: Total.Carb
  ??? carbon-map.tif           # single-band raster covariate
Important notes

plots.shp must contain a field named Total.Carb

All spatial layers should share a common coordinate reference system

The raster must fully cover the boundary polygon

Configuration
All model settings are controlled through config.yaml in the repository root.

At minimum, update:

site: example_site
data_dir: /path/to/data
output_dir: /path/to/output
Additional parameters control:

MCMC sample size

spatial priors

tuning parameters

burn-in and thinning

Running the workflow
From the repository root, run the four steps in order:

Rscript R/step0.R
Rscript R/step1.R
Rscript R/step2.R
Rscript R/step3.R
Each step prints progress and diagnostics to the console.

What each step does
Step	Purpose
0	Validate inputs and load data
1	Fit a linear model and compute a semivariogram
2	Fit a Bayesian spatial regression model
3	Predict carbon and uncertainty across the landscape
Outputs
Results are written to:

<output_dir>/<site>/
Typical outputs include:

pred.tif ? spatial prediction (mean)

pred-joint.tif ? joint predictive draws

semivariogram.png ? residual spatial structure

chainImg.png ? MCMC diagnostic plot

m.1.RData ? fitted model object

Joint vs non-joint prediction (important)
Non-joint prediction
Best for per-pixel uncertainty and map visualization.

Joint prediction
Required for computing uncertainty on area-based summaries
(e.g., mean or total carbon within management units).

This workflow produces both.

Optional GUI
A lightweight GUI is included for interactive use:

Rscript R/gui.R
The GUI allows you to:

edit the YAML configuration,

run modeling steps,

view diagnostic plots.

Intended use & caveats
This tool is intended for:

regional carbon mapping,

landscape-scale analysis,

decision support and reporting.

It is not a substitute for local field inventories and should be used with appropriate domain knowledge and validation.

Citation
If you use this workflow in a report or publication, please cite:

[Author(s)]. Spatial Bayesian modeling workflow for carbon prediction. GitHub repository.

(Replace with project-specific citation details.)

Contact
For questions, issues, or contributions, please open a GitHub Issue or contact the repository maintainer.


---

If you want, next we can:
- **shorten this further** (ultra-minimal README),
- add a **?For land managers? summary box at the top**, or
- tailor wording to a specific agency (USFS / state DNR / NGO).

But as-is, this is already a solid, professional public README.
