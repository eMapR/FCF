library(tcltk)
library(yaml)

# -----------------------------
# Helper: find the directory this script lives in
# Works when run with source(".../gui.R") or via Rscript gui.R
# Falls back to getwd() if needed
# -----------------------------
get_script_dir <- function() {
  # Case 1: running via Rscript --file=...
  cmd_args <- commandArgs(trailingOnly = FALSE)
  file_arg <- "--file="
  match <- grep(file_arg, cmd_args)

  if (length(match) > 0) {
    script_path <- sub(file_arg, "", cmd_args[match[1]])
    return(dirname(normalizePath(script_path, winslash = "/", mustWork = TRUE)))
  }

  # Case 2: sourced via source(".../gui.R")
  for (i in rev(seq_len(sys.nframe()))) {
    if (!is.null(sys.frame(i)$ofile)) {
      return(dirname(normalizePath(sys.frame(i)$ofile, winslash = "/", mustWork = TRUE)))
    }
  }

  # Fallback
  normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}

script_dir <- get_script_dir()

# -----------------------------
# App state
# -----------------------------
app_state <- new.env(parent = emptyenv())
app_state$last_plot_image <- NULL
app_state$yaml_data <- NULL
app_state$yaml_file_path <- NULL
app_state$after_id <- NULL
app_state$current_output_file <- NULL
app_state$current_step <- NULL
app_state$current_process <- NULL
app_state$plot_path <- file.path(script_dir, "plot.png")

# -----------------------------
# Helper: append text to console
# -----------------------------
append_console <- function(console_text, text) {
  tkinsert(console_text, "end", text)
  tkyview(console_text, "moveto", 1)
}

# -----------------------------
# Helper: stop previous polling loop
# -----------------------------
stop_streaming <- function() {
  if (!is.null(app_state$after_id)) {
    try(tcl("after", "cancel", app_state$after_id), silent = TRUE)
    app_state$after_id <- NULL
  }
}

# -----------------------------
# Safe file read for Windows lock issues
# -----------------------------
safe_read_log <- function(path) {
  if (!file.exists(path)) return(NULL)

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

# -----------------------------
# Helper: refresh plot if available
# -----------------------------
refresh_plot <- function(plot_label) {
  if (!file.exists(app_state$plot_path)) return()

  tryCatch({
    Sys.sleep(0.05)  # reduce race condition while image is being written
    img <- tkimage.create("photo", file = app_state$plot_path)
    tkconfigure(plot_label, image = img)
    app_state$last_plot_image <- img
  }, error = function(e) {
    # silent; plot may still be mid-write
  })
}

# -----------------------------
# Poll output file and update console/plot
# -----------------------------
make_streamer <- function(console_text, plot_label, output_file) {
  last_line_count <- 0

  stream_output <- function() {
    lines <- safe_read_log(output_file)

    if (!is.null(lines) && length(lines) > last_line_count) {
      new_lines <- lines[(last_line_count + 1):length(lines)]
      for (line in new_lines) {
        append_console(console_text, paste0(line, "\n"))
      }
      last_line_count <<- length(lines)
    }

    refresh_plot(plot_label)

    # keep polling
    app_state$after_id <- tcl("after", 500, stream_output)
  }

  stream_output
}

# -----------------------------
# Run a step script in background
# Assumes step scripts live in the same folder as gui.R
# -----------------------------
run_my_script <- function(console_text, plot_label, step_file) {
  stop_streaming()

  tkdelete(console_text, "1.0", "end")
  append_console(console_text, paste0("Running ", step_file, "...\n"))

  step_path <- file.path(script_dir, step_file)

  if (!file.exists(step_path)) {
    append_console(console_text, paste0("Error: could not find ", step_path, "\n"))
    return(invisible(NULL))
  }

  # fresh output file each run
  output_file <- tempfile(pattern = "gui_run_", fileext = ".log")
  app_state$current_output_file <- output_file
  app_state$current_step <- step_file

  # optional: remove old plot so stale image does not appear
  if (file.exists(app_state$plot_path)) {
    try(file.remove(app_state$plot_path), silent = TRUE)
  }

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
      args = c(normalizePath(step_path, winslash = "/", mustWork = TRUE)),
      stdout = output_file,
      stderr = output_file,
      wait = FALSE
    )
  }, error = function(e) {
    append_console(console_text, paste0("Failed to start script: ", e$message, "\n"))
    return(invisible(NULL))
  })

  streamer <- make_streamer(console_text, plot_label, output_file)
  streamer()
}

# -----------------------------
# YAML load/save
# -----------------------------
load_yaml_file <- function(text_widget) {
  yaml_file <- tclvalue(
    tkgetOpenFile(
      filetypes = "{{YAML Files} {.yaml .yml}} {{All files} *}"
    )
  )

  if (yaml_file == "") return(invisible(NULL))

  tryCatch({
    yaml_content <- read_yaml(yaml_file)
    app_state$yaml_data <- yaml_content
    app_state$yaml_file_path <- yaml_file

    yaml_text <- as.yaml(yaml_content)
    tkdelete(text_widget, "1.0", "end")
    tkinsert(text_widget, "end", yaml_text)
  }, error = function(e) {
    tkmessageBox(
      title = "Error",
      message = paste("Failed to load YAML:", e$message),
      icon = "error"
    )
  })
}

save_yaml_file <- function(text_widget) {
  if (is.null(app_state$yaml_file_path)) {
    tkmessageBox(
      title = "Warning",
      message = "No YAML file loaded.",
      icon = "warning"
    )
    return(invisible(NULL))
  }

  edited_text <- tclvalue(tkget(text_widget, "1.0", "end"))

  tryCatch({
    edited_yaml <- yaml::yaml.load(edited_text)
    write_yaml(edited_yaml, file = app_state$yaml_file_path)
    tkmessageBox(
      title = "Saved",
      message = "YAML saved successfully.",
      icon = "info"
    )
  }, error = function(e) {
    tkmessageBox(
      title = "Error",
      message = paste("Failed to save YAML:", e$message),
      icon = "error"
    )
  })
}

# -----------------------------
# Optional helper: show script_dir in console
# -----------------------------
show_environment_info <- function(console_text) {
  append_console(console_text, paste0("GUI directory: ", script_dir, "\n"))
  append_console(console_text, paste0("Expected plot path: ", app_state$plot_path, "\n"))
  append_console(console_text, "Step files are expected in the same folder as gui.R\n\n")
}

# -----------------------------
# GUI Layout
# -----------------------------
tt <- tktoplevel()
tkwm.title(tt, "Script Runner with YAML Editor and Plot Viewer")

main_frame <- tkframe(tt)
tkgrid(main_frame, padx = 10, pady = 10)

# ---- Left side ----
left_frame <- tkframe(main_frame)
tkgrid(left_frame, row = 0, column = 0, sticky = "n")

tkgrid(tklabel(left_frame, text = "Console Output:"), sticky = "w")

console_frame <- tkframe(left_frame)
tkgrid(console_frame, sticky = "nsew")

console_text <- tktext(console_frame, width = 80, height = 18, wrap = "word")

console_scroll <- tkscrollbar(
  console_frame,
  orient = "vertical",
  command = function(...) tkyview(console_text, ...)
)

tkconfigure(
  console_text,
  yscrollcommand = function(...) tkset(console_scroll, ...)
)

tkpack(console_text, side = "left", fill = "both", expand = TRUE)
tkpack(console_scroll, side = "right", fill = "y")

tkgrid(tklabel(left_frame, text = "Plot Output:"), sticky = "w", pady = c(10, 0))

plot_frame <- tkframe(left_frame, relief = "sunken", borderwidth = 1)
tkgrid(plot_frame, sticky = "nsew")

plot_label <- tklabel(plot_frame)
tkpack(plot_label, padx = 5, pady = 5)

button_frame <- tkframe(left_frame)
tkgrid(button_frame, pady = c(10, 0), sticky = "w")

button1 <- tkbutton(
  button_frame,
  text = "Run Step 1",
  command = function() run_my_script(console_text, plot_label, "step1.R")
)

button2 <- tkbutton(
  button_frame,
  text = "Run Step 2",
  command = function() run_my_script(console_text, plot_label, "step2.R")
)

button3 <- tkbutton(
  button_frame,
  text = "Run Step 3",
  command = function() run_my_script(console_text, plot_label, "step3.R")
)

tkgrid(button1, row = 0, column = 0, padx = 3)
tkgrid(button2, row = 0, column = 1, padx = 3)
tkgrid(button3, row = 0, column = 2, padx = 3)

# ---- Right side ----
right_frame <- tkframe(main_frame)
tkgrid(right_frame, row = 0, column = 1, sticky = "n", padx = c(15, 0))

tkgrid(tklabel(right_frame, text = "YAML Editor:"), sticky = "w")

yaml_frame <- tkframe(right_frame)
tkgrid(yaml_frame, sticky = "nsew")

yaml_text <- tktext(yaml_frame, width = 60, height = 30, wrap = "word")

yaml_scroll <- tkscrollbar(
  yaml_frame,
  orient = "vertical",
  command = function(...) tkyview(yaml_text, ...)
)

tkconfigure(
  yaml_text,
  yscrollcommand = function(...) tkset(yaml_scroll, ...)
)

tkpack(yaml_text, side = "left", fill = "both", expand = TRUE)
tkpack(yaml_scroll, side = "right", fill = "y")

yaml_btn_frame <- tkframe(right_frame)
tkgrid(yaml_btn_frame, pady = 10, sticky = "w")

load_btn <- tkbutton(
  yaml_btn_frame,
  text = "Load YAML",
  command = function() load_yaml_file(yaml_text)
)

save_btn <- tkbutton(
  yaml_btn_frame,
  text = "Save YAML",
  command = function() save_yaml_file(yaml_text)
)

tkgrid(load_btn, row = 0, column = 0, padx = 5)
tkgrid(save_btn, row = 0, column = 1, padx = 5)

# -----------------------------
# Startup info
# -----------------------------
show_environment_info(console_text)

# Clean up polling loop when window closes
tkbind(tt, "<Destroy>", function() {
  stop_streaming()
})

tkwait.window(tt)
