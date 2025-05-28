run_script_1 <- function(console_text, plot_label, step_script, checklist_labels, step_name) {
  # Define output paths
  output_file <- "01_log.txt"
  file.remove("plot.png")
  plot_path <- "plot.png"
  tkdelete(console_text, "1.0", "end")
  
  if (file.exists(output_file)) file.remove(output_file)

  last_line_count <- 0  # Track how many lines already displayed

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
          } else if (grepl("should be character but is", line)) {
            update_checklist_status(checklist_labels, "Estimate Nugget", "fail")
          } 

          if (grepl("Sill", line)) {
            update_checklist_status(checklist_labels, "Fit Sill", "pass")
          } else if (grepl("should be character but is", line)) {
            update_checklist_status(checklist_labels, "Fit Sill", "fail")
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
