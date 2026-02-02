Spatial Carbon Model (R)

This repository contains an R-based Bayesian spatial modeling application for producing wall-to-wall carbon predictions and associated uncertainty from plot data and a gridded covariate.

The application is intended to be run through a graphical user interface (GUI). Internally, the GUI orchestrates a sequence of processing steps that validate inputs, fit a spatial model, and generate prediction and uncertainty maps.

The primary audience for this tool is land managers, analysts, and researchers who need defensible spatial carbon estimates without writing or modifying R code.

What the application does (plain language)

The user provides two main inputs: field plot measurements of carbon and a raster covariate that covers the full landscape of interest.

Using these inputs, the application fits a Bayesian spatial regression model that learns the relationship between the plot measurements and the raster covariate, accounts for spatial structure that is not explained by the covariate alone, and predicts carbon continuously across the landscape.

The outputs include a spatial prediction map, a spatial uncertainty map, and joint predictive draws that can be used to compute uncertainty for area-based summaries such as mean or total carbon within management units.

How the application runs

Users interact with the model through the GUI. The GUI is the primary entry point and is the recommended way to run the application.

Behind the scenes, the GUI executes a sequence of R scripts in a fixed order. Each script performs a specific task and writes outputs that are used by the next step in the workflow.

The internal workflow is:

GUI launches the process, then runs step0.R, followed by step1.R, then step2.R, and finally step3.R.

Advanced users may run these scripts manually for debugging or batch processing, but this is not required for normal use.

Repository structure

The repository is organized as follows.

The R directory contains all application code. The file gui.R is the primary user interface and should be launched to run the model. The file main_gui.R contains supporting GUI logic and handlers. The files step0.R through step3.R implement the internal modeling workflow. The file mod.R contains shared utility and model functions used by multiple steps.

The file config.yaml is located at the repository root and controls all model settings, paths, and tuning parameters.

Software requirements

The application requires R version 4.0 or newer.

The following R packages must be installed: terra, geoR, spBayes, yaml. The tcltk package is also required in order to use the GUI.

Input data requirements

Input data must be organized in a directory structure that includes a site-specific folder under a common data directory.

Within each site folder, the following inputs are required.

A boundary polygon shapefile located in a subdirectory named bnd. This polygon defines the spatial extent of the analysis.

A plots shapefile located in a subdirectory named plots. This shapefile must contain point locations and an attribute field named Total.Carb representing measured carbon at each plot.

A single-band raster file named carbon-map.tif. This raster provides the covariate used to predict carbon across the landscape.

All spatial inputs must share a common coordinate reference system, and the raster must fully cover the boundary polygon.

Configuration

All model settings are controlled through a YAML configuration file named config.yaml located at the repository root.

At a minimum, the user must specify the site name, the path to the data directory, and the path to the output directory.

Additional configuration parameters control the number of MCMC samples, spatial priors, tuning parameters, and burn-in and thinning behavior.

The GUI provides functionality to load, edit, and save the configuration file.

Running the model

To run the application, navigate to the repository root and launch the GUI by running gui.R using R.

Once the GUI is open, the user can load or edit the configuration file, start the modeling workflow, and monitor progress and diagnostic output. Diagnostic plots such as the variogram and MCMC chain behavior are displayed as the workflow runs.

For most users, running the model through the GUI is the only required interaction.

Internal workflow steps (reference)

Step 0 validates inputs and loads spatial data.

Step 1 fits a non-spatial linear model and computes a semivariogram of residuals.

Step 2 fits a Bayesian spatial regression model using MCMC.

Step 3 generates spatial prediction and uncertainty maps across the full raster extent.

Outputs

All outputs are written to a site-specific directory under the configured output directory.

Typical outputs include a raster representing the mean predicted carbon, raster outputs representing predictive uncertainty, diagnostic plots from the variogram and MCMC chains, and serialized R data objects containing the fitted model and predictions.

Joint versus non-joint prediction

The application produces both non-joint and joint predictions.

Non-joint predictions are appropriate for per-pixel uncertainty visualization and mapping.

Joint predictions are required when computing uncertainty for area-based summaries, such as mean or total carbon within management units, because they preserve spatial covariance between pixels.

Intended use and limitations

This application is intended for regional and landscape-scale carbon analysis, decision support, and reporting.

It is not a substitute for local field inventories and should be used with appropriate domain knowledge, validation, and interpretation.

Citation

If this application is used in a report or publication, please cite the repository and associated documentation according to your organization’s citation standards.

Contact and support

Questions, issues, and enhancement requests should be submitted through the project’s issue tracker or directed to the repository maintainer.
