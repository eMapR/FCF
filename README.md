# Bayesian Spatial Carbon Modeling Application

## Overview

This repository contains an R-based application for fitting a Bayesian spatial model to plot-level carbon data and producing spatial predictions and uncertainty maps across a landscape.

The application is designed to be run through a graphical user interface (GUI). Users interact with the GUI to configure inputs, run model steps in order, and view diagnostic output. Internally, the GUI executes a series of R scripts that implement the modeling workflow.

The primary intended users are land managers, analysts, and researchers who need spatially explicit carbon estimates with associated uncertainty, but who do not want to modify or write R code.

## Quick Start

1. Install R and the required packages: `yaml`, `terra`, `geoR`, `spBayes`.
2. Launch the GUI from the repository root with `Rscript src/gui.R`.
3. Load `src/config.yaml` or `src/config_example.yaml`.
4. Set `site`, `data_dir`, and `output_dir`.
5. Run Step 0, then Step 1, then Step 2, then Step 3.

For most users, the GUI is the only interface that needs to be used.

------

## What the Application Does

The application uses two primary data sources:

- Field plot measurements of carbon
- A gridded raster covariate covering the full analysis area

Using these inputs, the application:

1. Fits a regression model relating plot carbon measurements to the raster covariate.
2. Evaluates spatial structure remaining in the residuals.
3. Fits a Bayesian spatial regression model that accounts for this spatial structure.
4. Predicts carbon continuously across the landscape.
5. Produces uncertainty estimates associated with those predictions.

Outputs are intended to support mapping, reporting, and area-based summaries such as mean or total carbon within management units.

------

## Installation

### System Requirements

- R (version 4.0 or newer recommended)
- Internet access (for first-time package installation)
- A working Tcl/Tk installation for the GUI

Verify R is installed:

```
R --version
```

------

### Installing Required R Packages

If you see an error such as:

```
Error in library(yaml) : there is no package called ‘yaml’
```

you must install the workflow packages:

```
tcltk, yaml, terra, geoR, spBayes
```

`tcltk` usually ships with R; the others typically need installation.

Install all non-base packages with:

```
Rscript -e "install.packages(c('yaml','terra','geoR','spBayes'), repos='https://cloud.r-project.org')"
```

#### Recommended Method (User Library, No sudo Required)

Create a personal R library directory:

```
mkdir -p ~/R/x86_64-pc-linux-gnu-library
```

Install required packages:

```
Rscript -e "install.packages(c('yaml','terra','geoR','spBayes'), repos='https://cloud.r-project.org', lib='~/R/x86_64-pc-linux-gnu-library')"
```

Set the user library for your session:

```
export R_LIBS_USER=~/R/x86_64-pc-linux-gnu-library
```

Then launch the GUI from the repository root:

```
Rscript src/gui.R
```

------

#### Make the Library Path Permanent (Recommended)

For bash:

```
echo 'export R_LIBS_USER=~/R/x86_64-pc-linux-gnu-library' >> ~/.bashrc
source ~/.bashrc
```

For zsh:

```
echo 'export R_LIBS_USER=~/R/x86_64-pc-linux-gnu-library' >> ~/.zshrc
source ~/.zshrc
```

After this, simply run from the repository root:

```
Rscript src/gui.R
```

------

#### Alternative: System-Wide Installation (Requires sudo)

```
sudo Rscript -e "install.packages(c('yaml','terra','geoR','spBayes'), repos='https://cloud.r-project.org')"
```

------

### Verifying Installation

Check R library paths:

```
Rscript -e "print(.libPaths())"
```

Your user library should appear first.

------

## How the Application Is Run

The application is run through a graphical user interface.

The GUI is the primary entry point for users.

Users launch the GUI and interact with buttons and controls to:

- Configure model inputs
- Run model steps
- View diagnostics

The GUI manages configuration, execution, and display of results.

Behind the scenes, the GUI runs a sequence of R scripts that implement the workflow. These scripts are not meant to be run directly by most users, although advanced users may do so if desired.

Launch the GUI from the repository root:

```
Rscript src/gui.R
```

On Windows, you can also start the GUI from an R console with:

```r
source("src/gui.R")
```

------

## Internal Workflow (High-Level)

The modeling workflow consists of four sequential steps.

### Step 0

- Validates input files and directory structure
- Verifies that the boundary, plots, and raster share the same CRS
- Verifies that the raster covers the boundary extent, with optional tolerance-based warning behavior
- Loads spatial data (boundary, plots, raster)
- Extracts raster values at plot locations

### Step 1

- Fits a non-spatial linear regression model
- Computes a semivariogram of residuals
- Produces a diagnostic plot showing residual spatial structure

### Step 2

- Fits a Bayesian spatial regression model using MCMC
- Estimates regression coefficients, spatial variance, nugget variance, and spatial range
- Produces diagnostic plots of MCMC behavior

### Step 3

- Uses the fitted model to predict carbon across the raster grid
- Produces `pred.tif`, a per-pixel output containing mean and uncertainty layers
- Produces `pred-joint.tif`, a joint predictive output that is better suited to uncertainty-aware aggregation
- Generates both products from the same button click in the GUI

Each step depends on outputs from the previous step and is coordinated by the GUI.

------

## Repository Contents

The repository contains:

- `src/gui.R` – launches the current graphical user interface
- `src/main_gui.R` – older GUI implementation retained for reference
- `src/step0.R` through `src/step3.R` – scripts implementing the modeling workflow
- `src/mod.R` – shared utility and modeling functions
- `src/config.yaml` – default configuration file controlling model settings and paths
- `README.md` – this file

Most application code resides under `src/`.

------

## Input Data Requirements

Input data must be organized in a site-specific directory structure.

Each site directory must include:

- A boundary polygon shapefile defining the analysis extent
- A plots shapefile containing point locations and a field named `Total.Carb` representing measured carbon
- A single-band raster file used as the predictor covariate

The GUI expects `data_dir` to be the parent directory that contains site folders, and `site` to name the specific folder to use.

For example, if:

- `data_dir: /path/to/data`
- `site: black-mountains`

then the program will look for:

```
/path/to/data/black-mountains/bnd/bnd.shp
/path/to/data/black-mountains/plots/plots.shp
/path/to/data/black-mountains/carbon-map.tif
```

Requirements:

- All spatial data must use a common coordinate reference system (CRS).
- The raster should cover the boundary polygon.
- By default, Step 0 can be configured either to stop on raster coverage mismatch or to log a warning and continue when the mismatch is small and expected.
- The GUI checks both CRS consistency and raster coverage during Step 0 and reports readable messages if they fail.

Practical notes:

- The plots shapefile must contain a field named `Total.Carb`.
- The raster is expected to be single-band.
- Small extent mismatches can occur because of pixel alignment or rounding; these can be handled with `raster.coverage.tolerance`.

------

## Configuration

Model settings are controlled through a YAML configuration file.

The GUI includes:

- A YAML editor
- Quick fields for `site`, `data_dir`, and `output_dir`
- `Load Template`, `Save`, and `Save As` actions
- Step buttons that run the workflow in order and stream log output into the GUI

For most first runs, only these values usually need to change:

- `site`
- `data_dir`
- `output_dir`
- `n.samples`
- `n.threads`

Recommended first-pass workflow:

1. Start with `src/config_example.yaml` if you want a portable template, or `src/config.yaml` if you want to edit the default runtime config.
2. Change `site`, `data_dir`, and `output_dir`.
3. Run Step 0 to validate paths and spatial inputs.
4. Run Step 1 to inspect the semivariogram and logged nugget/sill values.
5. Adjust advanced Step 2 settings only if needed.
6. Run Step 2 and then Step 3.

Raster coverage behavior can also be controlled from YAML:

- `strict.raster.coverage` - when `true`, Step 0 stops if the raster extent does not cover the boundary extent
- `raster.coverage.tolerance` - non-negative tolerance in the raster CRS units that allows small edge mismatches

Example:

```yaml
strict.raster.coverage: false
raster.coverage.tolerance: 10
```

This setting is useful when the raster and boundary differ by only a few map units because of extent alignment or rounding, but you still want the workflow to continue.

The variogram-related variance settings are more advanced. A common workflow is:

1. Run Step 0 to validate inputs.
2. Run Step 1 to inspect the variogram and estimated nugget/sill.
3. Adjust advanced settings if needed.
4. Run Step 2 and Step 3.

The configuration file specifies:

- Site name
- Paths to input data and output directories
- MCMC settings (number of samples, thinning)
- Prior bounds and tuning parameters for the spatial model
- Raster coverage validation behavior for Step 0

The GUI allows users to load, edit, and save the configuration file.

------

## Outputs

Model outputs are written to a site-specific directory under the configured output location.

Typical outputs include:

- `semivariogram.png` from Step 1
- `chainImg.png` from Step 2
- `m.1.RData`, the fitted spatial model from Step 2
- `pred.tif`, the per-pixel prediction output from Step 3
- `m.1.pred.RData`, serialized per-pixel predictive samples
- `pred-joint.tif`, the joint prediction output from Step 3
- `m.1.pred.joint.RData`, serialized joint predictive samples

`pred.tif` is intended for mapping and per-pixel summaries. `pred-joint.tif` is intended for aggregation workflows where uncertainty over areas, polygons, or totals matters.

------

## Joint Versus Non-Joint Prediction

The application produces two types of predictions:

**Non-joint predictions**

- Suitable for per-pixel mapping and visualization
- Easier to use for standard raster display workflows

**Joint predictions**

- Preserve spatial covariance
- Better suited for uncertainty-aware aggregation
- Required when computing uncertainty for area-based summaries such as polygon means or totals

Joint predictions should be used when reporting uncertainty for aggregated quantities.

------

## Intended Use and Limitations

This application is intended for regional and landscape-scale carbon analysis and decision support.

It is not a substitute for local field inventories and should be used with appropriate domain knowledge, validation, and interpretation.

Results should be evaluated in the context of:

- Data quality
- Model assumptions
- Spatial scale
- Uncertainty

------

## Support and Contact

Questions, issues, and suggestions should be submitted through the project’s issue tracker or directed to the repository maintainer.
