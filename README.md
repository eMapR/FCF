Spatial Carbon Modeling Application\
README

***

Overview

This repository contains an R-based application for fitting a Bayesian spatial model to plot-level carbon data and producing spatial predictions and uncertainty maps across a landscape.

The application is designed to be run through a graphical user interface (GUI). Users interact with the GUI to configure inputs, run the model, and view diagnostic output. Internally, the GUI executes a series of R scripts that implement the modeling workflow.

The primary intended users are land managers, analysts, and researchers who need spatially explicit carbon estimates with associated uncertainty, but who do not want to modify or write R code.

***

What the application does

The application uses two primary data sources:

- Field plot measurements of carbon.

- A gridded raster covariate covering the full analysis area.

Using these inputs, the application:

- Fits a regression model relating plot carbon measurements to the raster covariate.

- Evaluates spatial structure remaining in the residuals.

- Fits a Bayesian spatial regression model that accounts for this spatial structure.

- Predicts carbon continuously across the landscape.

- Produces uncertainty estimates associated with those predictions.

Outputs are intended to support mapping, reporting, and area-based summaries such as mean or total carbon within management units.

***

How the application is run

The application is run through a graphical user interface.

- The GUI is the primary entry point for users.

- Users launch the GUI and interact with buttons and controls to run the model.

- The GUI manages configuration, execution, and display of diagnostics.

Behind the scenes, the GUI runs a sequence of R scripts that implement the workflow. These scripts are not meant to be run directly by most users, although advanced users may do so if desired.

***

Internal workflow (high-level)

The modeling workflow consists of four sequential steps:

Step 0

- Validates input files and directory structure.

- Loads spatial data (boundary, plots, raster).

- Extracts raster values at plot locations.

Step 1

- Fits a non-spatial linear regression model.

- Computes a semivariogram of residuals.

- Produces a diagnostic plot showing residual spatial structure.

Step 2

- Fits a Bayesian spatial regression model using MCMC.

- Estimates regression coefficients, spatial variance, nugget variance, and spatial range.

- Produces diagnostic plots of MCMC behavior.

Step 3

- Uses the fitted model to predict carbon across the raster grid.

- Produces spatial prediction and uncertainty outputs.

- Generates both joint and non-joint predictive products.

Each step depends on outputs from the previous step and is coordinated by the GUI.

***

Repository contents

The repository contains the following components:

- An R directory with all application code.

  - gui.R: launches the graphical user interface.

  - main\_gui.R: supporting GUI logic and handlers.

  - step0.R through step3.R: scripts implementing the modeling workflow.

  - mod.R: shared utility and modeling functions.

- A configuration file named config.yaml that controls model settings and paths.

- This README file.

***

Input data requirements

Input data must be organized in a site-specific directory structure.

Each site directory must include:

- A boundary polygon shapefile defining the analysis extent.

- A plots shapefile containing point locations and a field named “Total.Carb” representing measured carbon.

- A single-band raster file used as the predictor covariate.

All spatial data must use a common coordinate reference system. The raster must fully cover the boundary polygon.

***

Configuration

Model settings are controlled through a YAML configuration file.

The configuration file specifies:

- Site name.

- Paths to input data and output directories.

- MCMC settings such as number of samples and thinning.

- Prior bounds and tuning parameters for the spatial model.

The GUI allows users to load, edit, and save the configuration file.

***

Outputs

Model outputs are written to a site-specific directory under the configured output location.

Typical outputs include:

- A raster of predicted carbon values.

- A raster representing predictive uncertainty.

- Diagnostic plots from the variogram and MCMC fitting steps.

- Serialized R objects containing fitted models and predictions.

These outputs are intended for mapping, analysis, and reporting.

***

Joint versus non-joint prediction

The application produces two types of predictions:

- Non-joint predictions, which are suitable for per-pixel mapping and visualization.

- Joint predictions, which preserve spatial covariance and are required for computing uncertainty on area-based summaries such as means or totals over polygons.

Users should use joint predictions when reporting uncertainty for aggregated quantities.

***

Intended use and limitations

This application is intended for regional and landscape-scale carbon analysis and decision support.

It is not a substitute for local field inventories and should be used with appropriate domain knowledge, validation, and interpretation. Results should be evaluated in the context of data quality, model assumptions, and uncertainty.

***

Support and contact

Questions, issues, and suggestions should be submitted through the project’s issue tracker or directed to the repository maintainer.
