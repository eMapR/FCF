# Bayesian Spatial Carbon Modeling Application

## Overview

This repository contains an R-based application for fitting a Bayesian spatial model to plot-level carbon data and producing spatial predictions and uncertainty maps across a landscape.

The application is designed to be run through a graphical user interface (GUI). Users interact with the GUI to configure inputs, run the model, and view diagnostic output. Internally, the GUI executes a series of R scripts that implement the modeling workflow.

The primary intended users are land managers, analysts, and researchers who need spatially explicit carbon estimates with associated uncertainty, but who do not want to modify or write R code.

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
- A Unix-like shell environment (Linux or macOS recommended)

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

you must install required R packages.

#### Recommended Method (User Library, No sudo Required)

Create a personal R library directory:

```
mkdir -p ~/R/x86_64-pc-linux-gnu-library
```

Install required packages:

```
Rscript -e "install.packages(c('yaml'), repos='https://cloud.r-project.org', lib='~/R/x86_64-pc-linux-gnu-library')"
```

Set the user library for your session:

```
export R_LIBS_USER=~/R/x86_64-pc-linux-gnu-library
```

Then launch the GUI:

```
Rscript gui.R
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

After this, simply run:

```
Rscript gui.R
```

------

#### Alternative: System-Wide Installation (Requires sudo)

```
sudo Rscript -e "install.packages('yaml', repos='https://cloud.r-project.org')"
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
Rscript gui.R
```

------

## Internal Workflow (High-Level)

The modeling workflow consists of four sequential steps.

### Step 0

- Validates input files and directory structure
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
- Produces spatial prediction and uncertainty outputs
- Generates both joint and non-joint predictive products

Each step depends on outputs from the previous step and is coordinated by the GUI.

------

## Repository Contents

The repository contains:

- `gui.R` – launches the graphical user interface
- `main_gui.R` – supporting GUI logic and handlers
- `step0.R` through `step3.R` – scripts implementing the modeling workflow
- `mod.R` – shared utility and modeling functions
- `config.yaml` – configuration file controlling model settings and paths
- `README.md` – this file

All application code resides in the R directory.

------

## Input Data Requirements

Input data must be organized in a site-specific directory structure.

Each site directory must include:

- A boundary polygon shapefile defining the analysis extent
- A plots shapefile containing point locations and a field named `Total.Carb` representing measured carbon
- A single-band raster file used as the predictor covariate

Requirements:

- All spatial data must use a common coordinate reference system (CRS).
- The raster must fully cover the boundary polygon.

------

## Configuration

Model settings are controlled through a YAML configuration file.

The configuration file specifies:

- Site name
- Paths to input data and output directories
- MCMC settings (number of samples, thinning)
- Prior bounds and tuning parameters for the spatial model

The GUI allows users to load, edit, and save the configuration file.

------

## Outputs

Model outputs are written to a site-specific directory under the configured output location.

Typical outputs include:

- Raster of predicted carbon values
- Raster representing predictive uncertainty
- Diagnostic plots from variogram and MCMC fitting steps
- Serialized R objects containing fitted models and predictions

These outputs are intended for mapping, analysis, and reporting.

------

## Joint Versus Non-Joint Prediction

The application produces two types of predictions:

**Non-joint predictions**

- Suitable for per-pixel mapping and visualization

**Joint predictions**

- Preserve spatial covariance
- Required for computing uncertainty on area-based summaries (means or totals over polygons)

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
