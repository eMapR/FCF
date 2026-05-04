library(tcltk)
library(yaml)

debug_output <- FALSE

required_packages <- c("tcltk", "yaml", "terra", "geoR", "spBayes")

step_definitions <- list(
  step0 = list(
    label = "Step 0: Check Inputs",
    file = "step0.R",
    estimate = "Usually under a minute.",
    description = "Validate the config, file structure, CRS, and raster coverage.",
    prereq = character(0)
  ),
  step1 = list(
    label = "Step 1: Fit Variogram",
    file = "step1.R",
    estimate = "Usually seconds to a few minutes.",
    description = "Fit the non-spatial model and estimate nugget and sill.",
    prereq = "step0"
  ),
  step2 = list(
    label = "Step 2: Fit Spatial Model",
    file = "step2.R",
    estimate = "Can take minutes to many hours.",
    description = "Run MCMC and recover posterior summaries.",
    prereq = "step1"
  ),
  step3 = list(
    label = "Step 3: Predict Outputs",
    file = "step3.R",
    estimate = "Can take hours or days on large rasters.",
    description = "Generate both per-pixel and joint prediction outputs.",
    prereq = "step2"
  )
)

get_script_dir <- function() {
  cmd_args <- commandArgs(trailingOnly = FALSE)
  file_arg <- "--file="
  match <- grep(file_arg, cmd_args)

  if (length(match) > 0) {
    script_path <- sub(file_arg, "", cmd_args[match[1]])
    return(dirname(normalizePath(script_path, winslash = "/", mustWork = TRUE)))
  }

  for (i in rev(seq_len(sys.nframe()))) {
    if (!is.null(sys.frame(i)$ofile)) {
      return(dirname(normalizePath(sys.frame(i)$ofile, winslash = "/", mustWork = TRUE)))
    }
  }

  normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}

script_dir <- get_script_dir()
default_yaml_path <- file.path(script_dir, "config.yaml")
template_yaml_path <- file.path(script_dir, "config_example.yaml")

app_state <- new.env(parent = emptyenv())
app_state$last_plot_image <- NULL
app_state$yaml_file_path <- NULL
app_state$runtime_yaml_path <- default_yaml_path
app_state$after_id <- NULL
app_state$current_output_file <- NULL
app_state$running_step <- NULL
app_state$plot_path <- file.path(script_dir, "plot.png")
app_state$step_status <- stats::setNames(as.list(rep("pending", length(step_definitions))), names(step_definitions))
app_state$step_buttons <- list()
app_state$step_status_vars <- list()
app_state$status_var <- tclVar("Idle.")
app_state$out_of_order_var <- tclVar("0")
app_state$form_vars <- list(
  site = tclVar(""),
  data_dir = tclVar(""),
  output_dir = tclVar("")
)

append_console <- function(console_text, text) {
  tkinsert(console_text, "end", text)
  tkyview(console_text, "moveto", 1)
}

set_status <- function(message) {
  tclvalue(app_state$status_var) <- message
}

stop_streaming <- function() {
  if (!is.null(app_state$after_id)) {
    try(tcl("after", "cancel", app_state$after_id), silent = TRUE)
    app_state$after_id <- NULL
  }
}

safe_read_log <- function(path) {
  if (!file.exists(path)) {
    return(NULL)
  }

  tmp_copy <- tempfile(fileext = ".log")
  ok <- suppressWarnings(
    tryCatch(
      file.copy(path, tmp_copy, overwrite = TRUE),
      error = function(e) FALSE
    )
  )

  if (!isTRUE(ok) || !file.exists(tmp_copy)) {
    return(NULL)
  }

  suppressWarnings(
    tryCatch(
      readLines(tmp_copy, warn = FALSE),
      error = function(e) NULL
    )
  )
}

refresh_plot <- function(plot_label) {
  if (!file.exists(app_state$plot_path)) {
    return()
  }

  tryCatch({
    Sys.sleep(0.05)
    img <- tkimage.create("photo", file = app_state$plot_path)
    tkconfigure(plot_label, image = img)
    app_state$last_plot_image <- img
  }, error = function(e) {
    invisible(NULL)
  })
}

`%||%` <- function(x, y) {
  if (is.null(x) || identical(x, "")) y else x
}

current_yaml_text <- function(text_widget) {
  tclvalue(tkget(text_widget, "1.0", "end"))
}

parse_yaml_from_widget <- function(text_widget) {
  tryCatch(
    yaml::yaml.load(current_yaml_text(text_widget)),
    error = function(e) e
  )
}

render_yaml <- function(text_widget, yaml_object) {
  tkdelete(text_widget, "1.0", "end")
  tkinsert(text_widget, "end", yaml::as.yaml(yaml_object))
}

yaml_scalar <- function(value) {
  if (is.null(value) || length(value) == 0) {
    return("")
  }

  as.character(value[[1]])
}

sync_form_from_yaml <- function(text_widget) {
  yaml_object <- parse_yaml_from_widget(text_widget)

  if (inherits(yaml_object, "error")) {
    return(invisible(FALSE))
  }

  tclvalue(app_state$form_vars$site) <- yaml_scalar(yaml_object$site)
  tclvalue(app_state$form_vars$data_dir) <- yaml_scalar(yaml_object$data_dir)
  tclvalue(app_state$form_vars$output_dir) <- yaml_scalar(yaml_object$output_dir)

  invisible(TRUE)
}

apply_form_to_yaml <- function(text_widget) {
  yaml_object <- parse_yaml_from_widget(text_widget)

  if (inherits(yaml_object, "error") || is.null(yaml_object)) {
    yaml_object <- list()
  }

  yaml_object$site <- tclvalue(app_state$form_vars$site)
  yaml_object$data_dir <- tclvalue(app_state$form_vars$data_dir)
  yaml_object$output_dir <- tclvalue(app_state$form_vars$output_dir)

  render_yaml(text_widget, yaml_object)
}

load_yaml_path <- function(path, text_widget) {
  tryCatch({
    yaml_content <- yaml::read_yaml(path)
    render_yaml(text_widget, yaml_content)
    app_state$yaml_file_path <- normalizePath(path, winslash = "/", mustWork = FALSE)
    sync_form_from_yaml(text_widget)
    set_status(sprintf("Loaded YAML: %s", basename(path)))
  }, error = function(e) {
    tkmessageBox(
      title = "Error",
      message = paste("Failed to load YAML:", e$message),
      icon = "error"
    )
  })
}

save_yaml_to_path <- function(text_widget, path, quiet = FALSE) {
  yaml_object <- parse_yaml_from_widget(text_widget)

  if (inherits(yaml_object, "error")) {
    if (!quiet) {
      tkmessageBox(
        title = "Error",
        message = paste("Failed to save YAML:", yaml_object$message),
        icon = "error"
      )
    }
    return(FALSE)
  }

  tryCatch({
    yaml::write_yaml(yaml_object, file = path)
    app_state$yaml_file_path <- normalizePath(path, winslash = "/", mustWork = FALSE)
    sync_form_from_yaml(text_widget)
    if (!quiet) {
      tkmessageBox(
        title = "Saved",
        message = paste("YAML saved to", path),
        icon = "info"
      )
    }
    TRUE
  }, error = function(e) {
    if (!quiet) {
      tkmessageBox(
        title = "Error",
        message = paste("Failed to save YAML:", e$message),
        icon = "error"
      )
    }
    FALSE
  })
}

get_runtime_yaml_path <- function() {
  loaded_path <- app_state$yaml_file_path

  if (is.null(loaded_path) || basename(loaded_path) == basename(template_yaml_path)) {
    return(default_yaml_path)
  }

  loaded_path
}

load_yaml_file <- function(text_widget) {
  yaml_file <- tclvalue(
    tkgetOpenFile(filetypes = "{{YAML Files} {.yaml .yml}} {{All files} *}")
  )

  if (yaml_file == "") {
    return(invisible(NULL))
  }

  load_yaml_path(yaml_file, text_widget)
}

save_yaml_file <- function(text_widget) {
  path <- app_state$yaml_file_path %||% default_yaml_path
  save_yaml_to_path(text_widget, path)
}

save_yaml_as_file <- function(text_widget) {
  initial_name <- basename(app_state$yaml_file_path %||% default_yaml_path)
  yaml_file <- tclvalue(
    tkgetSaveFile(
      defaultextension = ".yaml",
      initialfile = initial_name,
      filetypes = "{{YAML Files} {.yaml .yml}} {{All files} *}"
    )
  )

  if (yaml_file == "") {
    return(invisible(NULL))
  }

  save_yaml_to_path(text_widget, yaml_file)
}

load_template_yaml <- function(text_widget) {
  if (!file.exists(template_yaml_path)) {
    tkmessageBox(
      title = "Error",
      message = sprintf("Template file not found: %s", template_yaml_path),
      icon = "error"
    )
    return(invisible(NULL))
  }

  load_yaml_path(template_yaml_path, text_widget)
}

browse_directory_into_field <- function(var_name, text_widget) {
  initial_dir <- tclvalue(app_state$form_vars[[var_name]])
  selected_dir <- tclvalue(
    tkchooseDirectory(initialdir = initial_dir)
  )

  if (selected_dir == "") {
    return(invisible(NULL))
  }

  tclvalue(app_state$form_vars[[var_name]]) <- selected_dir
  apply_form_to_yaml(text_widget)
  set_status(sprintf("Updated %s in the editor.", var_name))
}

format_step_state <- function(status) {
  switch(
    status,
    pending = "Pending",
    running = "Running",
    complete = "Complete",
    failed = "Failed",
    status
  )
}

update_step_labels <- function() {
  for (step_id in names(step_definitions)) {
    status <- app_state$step_status[[step_id]]
    label <- sprintf("%s [%s]", step_definitions[[step_id]]$label, format_step_state(status))
    tclvalue(app_state$step_status_vars[[step_id]]) <- label
  }
}

can_run_step <- function(step_id) {
  if (!is.null(app_state$running_step)) {
    return(FALSE)
  }

  if (tclvalue(app_state$out_of_order_var) == "1") {
    return(TRUE)
  }

  prereq <- step_definitions[[step_id]]$prereq
  if (length(prereq) == 0) {
    return(TRUE)
  }

  all(vapply(prereq, function(id) identical(app_state$step_status[[id]], "complete"), logical(1)))
}

update_button_states <- function() {
  for (step_id in names(step_definitions)) {
    button <- app_state$step_buttons[[step_id]]
    if (is.null(button)) {
      next
    }

    state <- if (can_run_step(step_id)) "normal" else "disabled"
    tkconfigure(button, state = state)
  }
}

mark_step_status <- function(step_id, status) {
  app_state$step_status[[step_id]] <- status
  update_step_labels()
  update_button_states()
}

report_package_status <- function(console_text) {
  append_console(console_text, "Workflow packages:\n")
  for (pkg in required_packages) {
    installed <- requireNamespace(pkg, quietly = TRUE)
    append_console(
      console_text,
      sprintf("  %s: %s\n", pkg, if (installed) "installed" else "missing")
    )
  }
  append_console(console_text, "\n")
}

show_environment_info <- function(console_text) {
  append_console(console_text, sprintf("GUI directory: %s\n", script_dir))
  append_console(console_text, sprintf("Default runtime YAML: %s\n", default_yaml_path))
  append_console(console_text, sprintf("Plot preview file: %s\n\n", app_state$plot_path))
  report_package_status(console_text)
}

make_streamer <- function(console_text, plot_label, output_file, step_id) {
  last_line_count <- 0
  finished <- FALSE

  finish_run <- function(status, message) {
    if (finished) {
      return(invisible(NULL))
    }

    finished <<- TRUE
    stop_streaming()
    app_state$running_step <- NULL
    mark_step_status(step_id, status)
    set_status(message)
  }

  stream_output <- function() {
    lines <- safe_read_log(output_file)

    if (!is.null(lines) && length(lines) > last_line_count) {
      new_lines <- lines[(last_line_count + 1):length(lines)]
      for (line in new_lines) {
        if (debug_output || !grepl("^STEP_COMPLETE:", line)) {
          append_console(console_text, paste0(line, "\n"))
        }

        if (grepl("^STEP_COMPLETE:", line)) {
          finish_run("complete", sprintf("%s finished.", step_definitions[[step_id]]$label))
        } else if (grepl("Execution halted", line) || grepl("^Error", line) || grepl("^Error in ", line)) {
          finish_run("failed", sprintf("%s failed.", step_definitions[[step_id]]$label))
        }
      }
      last_line_count <<- length(lines)
    }

    refresh_plot(plot_label)

    if (!finished) {
      app_state$after_id <- tcl("after", 500, stream_output)
    }
  }

  stream_output
}

run_step <- function(console_text, plot_label, yaml_text, step_id) {
  if (!can_run_step(step_id)) {
    prereq <- step_definitions[[step_id]]$prereq
    message <- if (length(prereq) == 0) {
      "Another step is already running."
    } else {
      prereq_labels <- vapply(prereq, function(id) step_definitions[[id]]$label, character(1))
      sprintf("Run %s before starting this step.", paste(prereq_labels, collapse = " and "))
    }

    tkmessageBox(title = "Step Order", message = message, icon = "warning")
    return(invisible(NULL))
  }

  runtime_yaml_path <- get_runtime_yaml_path()
  if (!save_yaml_to_path(yaml_text, runtime_yaml_path, quiet = TRUE)) {
    tkmessageBox(
      title = "Error",
      message = "Fix the YAML before running a step.",
      icon = "error"
    )
    return(invisible(NULL))
  }

  stop_streaming()
  if (file.exists(app_state$plot_path)) {
    try(file.remove(app_state$plot_path), silent = TRUE)
  }

  tkdelete(console_text, "1.0", "end")

  step_info <- step_definitions[[step_id]]
  append_console(console_text, sprintf("%s\n", step_info$label))
  append_console(console_text, sprintf("%s\n", step_info$description))
  append_console(console_text, sprintf("%s\n", step_info$estimate))
  append_console(console_text, sprintf("Config file: %s\n\n", runtime_yaml_path))

  step_path <- file.path(script_dir, step_info$file)
  if (!file.exists(step_path)) {
    append_console(console_text, sprintf("Error: missing step script %s\n", step_path))
    mark_step_status(step_id, "failed")
    set_status(sprintf("%s failed to start.", step_info$label))
    return(invisible(NULL))
  }

  output_file <- tempfile(pattern = paste0(step_id, "_"), fileext = ".log")
  app_state$current_output_file <- output_file
  app_state$runtime_yaml_path <- runtime_yaml_path
  app_state$running_step <- step_id
  mark_step_status(step_id, "running")
  set_status(sprintf("%s is running.", step_info$label))

  rscript_path <- file.path(R.home("bin"), "Rscript.exe")
  if (!file.exists(rscript_path)) {
    rscript_path <- file.path(R.home("bin"), "Rscript")
  }

  old_wd <- getwd()
  on.exit(setwd(old_wd), add = TRUE)
  setwd(script_dir)

  tryCatch({
    system2(
      command = rscript_path,
      args = normalizePath(step_path, winslash = "/", mustWork = TRUE),
      stdout = output_file,
      stderr = output_file,
      wait = FALSE,
      env = sprintf(
        "FCF_CONFIG_PATH=%s",
        normalizePath(runtime_yaml_path, winslash = "/", mustWork = FALSE)
      )
    )
  }, error = function(e) {
    app_state$running_step <- NULL
    mark_step_status(step_id, "failed")
    set_status(sprintf("%s failed to start.", step_info$label))
    append_console(console_text, paste0("Failed to start script: ", e$message, "\n"))
    return(invisible(NULL))
  })

  streamer <- make_streamer(console_text, plot_label, output_file, step_id)
  streamer()
}

build_help_text <- function() {
  paste(
    "Input structure:",
    "Set data_dir to the parent directory that contains one folder per site.",
    "The site value should match that folder name exactly.",
    "Expected files inside data_dir/site/: bnd/bnd.shp, plots/plots.shp, carbon-map.tif.",
    "",
    "Output behavior:",
    "Step 3 writes both pred.tif (per-pixel mean and SD products) and pred-joint.tif",
    "(joint predictive samples for aggregation-friendly uncertainty). One click produces both.",
    "",
    "Config editing:",
    "Use the shortcut fields for site, data_dir, and output_dir, then Apply to YAML.",
    "Use Save As before branching experiments so the template stays untouched.",
    "",
    "Step order:",
    "By default the GUI enforces Step 0 -> Step 1 -> Step 2 -> Step 3.",
    "Enable 'Allow out-of-order runs' only if you know the required outputs already exist.",
    "",
    "Tuning guidance:",
    "Most users should edit site paths and basic run settings first.",
    "The variogram step helps populate sill and nugget-related values before Step 2.",
    sep = "\n"
  )
}

tt <- tktoplevel()
tkwm.title(tt, "Bayesian Spatial Carbon Modeling")
tkwm.minsize(tt, 1200, 760)
tkwm.geometry(tt, "1500x950")

main_frame <- tkframe(tt)
tkgrid(main_frame, row = 0, column = 0, sticky = "nsew", padx = 10, pady = 10)

tkgrid.rowconfigure(tt, 0, weight = 1)
tkgrid.columnconfigure(tt, 0, weight = 1)
tkgrid.rowconfigure(main_frame, 0, weight = 1)
tkgrid.columnconfigure(main_frame, 0, weight = 2)
tkgrid.columnconfigure(main_frame, 1, weight = 3)

left_frame <- tkframe(main_frame)
right_frame <- tkframe(main_frame)
tkgrid(left_frame, row = 0, column = 0, sticky = "nsew", padx = c(0, 10))
tkgrid(right_frame, row = 0, column = 1, sticky = "nsew")

tkgrid.rowconfigure(left_frame, 1, weight = 1)
tkgrid.rowconfigure(left_frame, 3, weight = 1)
tkgrid.columnconfigure(left_frame, 0, weight = 1)
tkgrid.rowconfigure(right_frame, 1, weight = 1)
tkgrid.rowconfigure(right_frame, 2, weight = 1)
tkgrid.columnconfigure(right_frame, 0, weight = 1)

tkgrid(tklabel(left_frame, text = "Console Output"), row = 0, column = 0, sticky = "w")

console_frame <- tkframe(left_frame)
tkgrid(console_frame, row = 1, column = 0, sticky = "nsew")
tkgrid.rowconfigure(console_frame, 0, weight = 1)
tkgrid.columnconfigure(console_frame, 0, weight = 1)

console_text <- tktext(console_frame, width = 90, height = 18, wrap = "word")
console_scroll <- tkscrollbar(
  console_frame,
  orient = "vertical",
  command = function(...) tkyview(console_text, ...)
)
tkconfigure(console_text, yscrollcommand = function(...) tkset(console_scroll, ...))
tkgrid(console_text, row = 0, column = 0, sticky = "nsew")
tkgrid(console_scroll, row = 0, column = 1, sticky = "ns")

tkgrid(tklabel(left_frame, text = "Plot Preview"), row = 2, column = 0, sticky = "w", pady = c(10, 0))

plot_frame <- tkframe(left_frame, relief = "sunken", borderwidth = 1)
tkgrid(plot_frame, row = 3, column = 0, sticky = "nsew")
tkgrid.rowconfigure(plot_frame, 0, weight = 1)
tkgrid.columnconfigure(plot_frame, 0, weight = 1)
plot_label <- tklabel(plot_frame)
tkgrid(plot_label, row = 0, column = 0, sticky = "nsew", padx = 5, pady = 5)

shortcut_frame <- tkframe(right_frame, relief = "groove", borderwidth = 1)
tkgrid(shortcut_frame, row = 0, column = 0, sticky = "ew", pady = c(0, 10))
tkgrid.columnconfigure(shortcut_frame, 1, weight = 1)

tkgrid(tklabel(shortcut_frame, text = "Quick Config Shortcuts"), row = 0, column = 0, columnspan = 3, sticky = "w", padx = 6, pady = c(6, 4))

tkgrid(tklabel(shortcut_frame, text = "Site"), row = 1, column = 0, sticky = "w", padx = 6, pady = 2)
site_entry <- tkentry(shortcut_frame, textvariable = app_state$form_vars$site)
tkgrid(site_entry, row = 1, column = 1, sticky = "ew", padx = 6, pady = 2)

tkgrid(tklabel(shortcut_frame, text = "Data Dir"), row = 2, column = 0, sticky = "w", padx = 6, pady = 2)
data_dir_entry <- tkentry(shortcut_frame, textvariable = app_state$form_vars$data_dir)
tkgrid(data_dir_entry, row = 2, column = 1, sticky = "ew", padx = 6, pady = 2)
data_dir_button <- tkbutton(shortcut_frame, text = "Browse", command = function() browse_directory_into_field("data_dir", yaml_text))

tkgrid(tklabel(shortcut_frame, text = "Output Dir"), row = 3, column = 0, sticky = "w", padx = 6, pady = 2)
output_dir_entry <- tkentry(shortcut_frame, textvariable = app_state$form_vars$output_dir)
tkgrid(output_dir_entry, row = 3, column = 1, sticky = "ew", padx = 6, pady = 2)
output_dir_button <- tkbutton(shortcut_frame, text = "Browse", command = function() browse_directory_into_field("output_dir", yaml_text))

apply_shortcuts_button <- tkbutton(shortcut_frame, text = "Apply To YAML", command = function() apply_form_to_yaml(yaml_text))
sync_shortcuts_button <- tkbutton(shortcut_frame, text = "Pull From YAML", command = function() sync_form_from_yaml(yaml_text))

yaml_frame <- tkframe(right_frame)
tkgrid(yaml_frame, row = 1, column = 0, sticky = "nsew", pady = c(0, 10))
tkgrid.rowconfigure(yaml_frame, 1, weight = 1)
tkgrid.columnconfigure(yaml_frame, 0, weight = 1)

tkgrid(tklabel(yaml_frame, text = "YAML Editor"), row = 0, column = 0, sticky = "w")

yaml_editor_frame <- tkframe(yaml_frame)
tkgrid(yaml_editor_frame, row = 1, column = 0, sticky = "nsew")
tkgrid.rowconfigure(yaml_editor_frame, 0, weight = 1)
tkgrid.columnconfigure(yaml_editor_frame, 0, weight = 1)

yaml_text <- tktext(yaml_editor_frame, width = 60, height = 24, wrap = "none")
yaml_scroll_y <- tkscrollbar(yaml_editor_frame, orient = "vertical", command = function(...) tkyview(yaml_text, ...))
tkconfigure(yaml_text, yscrollcommand = function(...) tkset(yaml_scroll_y, ...))
tkgrid(yaml_text, row = 0, column = 0, sticky = "nsew")
tkgrid(yaml_scroll_y, row = 0, column = 1, sticky = "ns")

yaml_button_frame <- tkframe(yaml_frame)
tkgrid(yaml_button_frame, row = 2, column = 0, sticky = "ew", pady = c(6, 0))

load_button <- tkbutton(yaml_button_frame, text = "Load YAML", command = function() load_yaml_file(yaml_text))
template_button <- tkbutton(yaml_button_frame, text = "Load Template", command = function() load_template_yaml(yaml_text))
save_button <- tkbutton(yaml_button_frame, text = "Save", command = function() save_yaml_file(yaml_text))
save_as_button <- tkbutton(yaml_button_frame, text = "Save As", command = function() save_yaml_as_file(yaml_text))

controls_frame <- tkframe(right_frame, relief = "groove", borderwidth = 1)
tkgrid(controls_frame, row = 2, column = 0, sticky = "nsew")
tkgrid.columnconfigure(controls_frame, 0, weight = 1)
tkgrid.columnconfigure(controls_frame, 1, weight = 1)

tkgrid(tklabel(controls_frame, text = "Run Workflow"), row = 0, column = 0, columnspan = 2, sticky = "w", padx = 6, pady = c(6, 4))

row_index <- 1
for (step_id in names(step_definitions)) {
  app_state$step_status_vars[[step_id]] <- tclVar(step_definitions[[step_id]]$label)
  status_label <- tklabel(controls_frame, textvariable = app_state$step_status_vars[[step_id]], anchor = "w", justify = "left")
  button <- tkbutton(
    controls_frame,
    text = step_definitions[[step_id]]$label,
    command = local({
      step_key <- step_id
      function() run_step(console_text, plot_label, yaml_text, step_key)
    })
  )
  app_state$step_buttons[[step_id]] <- button
  tkgrid(status_label, row = row_index, column = 0, sticky = "w", padx = 6, pady = 2)
  tkgrid(button, row = row_index, column = 1, sticky = "ew", padx = 6, pady = 2)
  row_index <- row_index + 1
}

out_of_order_checkbox <- tkcheckbutton(
  controls_frame,
  text = "Allow out-of-order runs",
  variable = app_state$out_of_order_var,
  command = update_button_states
)
tkgrid(out_of_order_checkbox, row = row_index, column = 0, columnspan = 2, sticky = "w", padx = 6, pady = c(6, 2))
row_index <- row_index + 1

status_label <- tklabel(
  controls_frame,
  textvariable = app_state$status_var,
  anchor = "w",
  justify = "left",
  wraplength = 360
)
tkgrid(status_label, row = row_index, column = 0, columnspan = 2, sticky = "ew", padx = 6, pady = c(4, 8))

help_frame <- tkframe(right_frame, relief = "groove", borderwidth = 1)
tkgrid(help_frame, row = 3, column = 0, sticky = "ew", pady = c(10, 0))
tkgrid.columnconfigure(help_frame, 0, weight = 1)
help_label <- tklabel(
  help_frame,
  text = build_help_text(),
  justify = "left",
  anchor = "w",
  wraplength = 420
)
tkgrid(help_label, row = 0, column = 0, sticky = "ew", padx = 6, pady = 6)

tkgrid(data_dir_button, row = 2, column = 2, sticky = "ew", padx = c(0, 6), pady = 2)
tkgrid(output_dir_button, row = 3, column = 2, sticky = "ew", padx = c(0, 6), pady = 2)
tkgrid(apply_shortcuts_button, row = 4, column = 1, sticky = "ew", padx = 6, pady = c(4, 6))
tkgrid(sync_shortcuts_button, row = 4, column = 2, sticky = "ew", padx = c(0, 6), pady = c(4, 6))

tkgrid(load_button, row = 0, column = 0, padx = c(0, 6))
tkgrid(template_button, row = 0, column = 1, padx = c(0, 6))
tkgrid(save_button, row = 0, column = 2, padx = c(0, 6))
tkgrid(save_as_button, row = 0, column = 3)

if (file.exists(default_yaml_path)) {
  load_yaml_path(default_yaml_path, yaml_text)
} else {
  load_template_yaml(yaml_text)
}

show_environment_info(console_text)
update_step_labels()
update_button_states()

tkbind(tt, "<Destroy>", function() {
  stop_streaming()
})

tkwait.window(tt)
