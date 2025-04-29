run_my_script <- function(console_text, plot_label, step) {
  # Define output paths
  output_file <- "output.txt"
  plot_path <- "plot.png"
  
  tkdelete(console_text, "1.0", "end")
  
  if (file.exists(output_file)) file.remove(output_file)

  last_line_count <- 0  # Track how many lines already displayed

  # Run script in background
  system2("Rscript", args = step, stdout = output_file, stderr = output_file, wait = FALSE)

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

    # Keep streaming every 1000 ms
    tcl("after", 1000, stream_output)
  }

  stream_output()
}
