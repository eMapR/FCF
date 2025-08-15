run_script_1 <- function(console_text, plot_label, step_script, checklist_labels, step_name, auto_populate) {
  # Define output paths
  output_file <- "01_log.txt"
  file.remove("plot.png")
  plot_path <- "plot.png"
  tkdelete(console_text, "1.0", "end")
  
  if (file.exists(output_file)) file.remove(output_file)

  last_line_count <- 0  # Track how many lines already displayed

  # Function to update YAML file with new values
  update_yaml_scales <- function(yaml_path, fitted_sill, nugget_estimate, auto_update = TRUE) {
    if (!auto_update) return(invisible(NULL))

    # Load existing YAML config
    config <- yaml.load_file(yaml_path)

    # Update with adjusted values
    config[["spatial.variance.scale"]] <- fitted_sill / 2
    config[["nugget.variance.scale"]] <- nugget_estimate

    # Write updated YAML
    write_yaml(config, yaml_path)
  }

  # First update checklist to "running" state
  #update_checklist_status(checklist_labels, step_name, "running")

  # Run script in background
  system2("Rscript", args = step_script, stdout = output_file, stderr = output_file, wait = FALSE)

  # Stream output and refresh plot
  stream_output <- function() {
    if (file.exists(output_file)) {
      lines <- tryCatch(readLines(output_file), error = function(e) character(0))
      if (length(lines) > last_line_count) {
        new_lines <- lines[(last_line_count + 1):length(lines)]  # Only truly new lines
         
        # Get scroll position correctly
        yview_raw <- tclvalue(tkyview(console_text))
        yview_info <- as.numeric(strsplit(yview_raw, " ")[[1]][2])
        at_bottom <- (yview_info >= 0.99)

        for (line in new_lines) {
          tkinsert(console_text, "end", paste0(line, "\n"))

          if (grepl("variogram", line)) {
            update_checklist_status(checklist_labels, "Compute Variogram", "pass")
          } else if (grepl("Failed to read YAML file", line)){
            update_checklist_status(checklist_labels, "Compute Variogram", "fail")
          }

          if (grepl("Nugget", line)) {
            update_checklist_status(checklist_labels, "Estimate Nugget", "pass")

            # Extract numeric value
            nugget_val <- as.numeric(sub(".*Nugget:\\s*", "", line))
          } else if (grepl("should be character but is", line)) {
            update_checklist_status(checklist_labels, "Estimate Nugget", "fail")
          }

          if (grepl("Sill", line)) {
            update_checklist_status(checklist_labels, "Fit Sill", "pass")

            # Extract numeric value
            sill_val <- as.numeric(sub(".*Sill:\\s*", "", line))
          } else if (grepl("should be character but is", line)) {
            update_checklist_status(checklist_labels, "Fit Sill", "fail")
          }

          # If both values are found and auto-populate is enabled, update YAML
          if (exists("nugget_val") && exists("sill_val")) {
            auto_pop <- as.logical(as.integer(tclvalue(run_buttons$auto_populate_var)))
            if (auto_pop) {
              update_yaml_scales("config.yaml", sill_val, nugget_val, TRUE)
              # Only update once — remove vars
              rm(nugget_val, sill_val)
            }
          }
        }


        if (at_bottom) {
          tkyview(console_text, "moveto", 1)
        }

        last_line_count <<- length(lines)  # Update last_line_count
      }
    }

    # Refresh plot
    if (file.exists(plot_path)) {
      tryCatch({
        img <- tkimage.create("photo", file = plot_path)
        tkconfigure(plot_label, image = img)
        assign("last_plot_image", img, envir = .GlobalEnv)  # prevent garbage collection
      }, error = function(e) {
        cat("Could not load image:", e$message, "\n")
      })
    }

    # ? Assume script is complete when output stabilizes
    #if (file.exists(output_file) && last_line_count > 0) {
    #  update_checklist_status(checklist_labels, step_name, "pass")
    #}

    # Keep streaming every 1000 ms
    tcl("after", 1000, stream_output)
  }

  stream_output()
}
