run_my_script <- function(console_text, plot_label, step_script, checklist_labels, step_name) {
  # Define output paths
  output_file <- "output.txt"
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

          if (grepl("YAML file exists and is valid", line)) {
            update_checklist_status(checklist_labels, "Check YAML File", "pass")
          } else if (grepl("Failed to read YAML file", line)){
            update_checklist_status(checklist_labels, "Check YAML File", "fail")
          }

          if (grepl("Config is valid", line)) {
            update_checklist_status(checklist_labels, "Check YAML Syntax", "pass")
          } else if (grepl("should be character but is", line)) {
            update_checklist_status(checklist_labels, "Check YAML Syntax", "fail")
          } else if (grepl("should be numeric but", line)) {
            update_checklist_status(checklist_labels, "Check YAML Syntax", "fail")
          } else if (grepl("Missing required field", line)) {
            update_checklist_status(checklist_labels, "Check YAML Syntax", "fail")
          } else if (grepl("must be less than", line)) {
            update_checklist_status(checklist_labels, "Check YAML Syntax", "fail")
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
