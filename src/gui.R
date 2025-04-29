library(tcltk)
library(yaml)

# Globals
last_plot_image <- NULL
output_file <- tempfile()
plot_path <- "plot.png"  # <-- image saved by step1.R
yaml_data <- NULL
yaml_file_path <- NULL

# Function to run script and stream output
run_my_script <- function(console_text, plot_label, step) {
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

# Load YAML file and display in editor
load_yaml_file <- function(text_widget) {
  yaml_file <- tclvalue(tkgetOpenFile(filetypes = "{{YAML Files} {.yaml .yml}} {{All files} *}"))
  if (yaml_file == "") return()

  yaml_content <- read_yaml(yaml_file)
  assign("yaml_data", yaml_content, envir = .GlobalEnv)
  assign("yaml_file_path", yaml_file, envir = .GlobalEnv)

  yaml_text <- as.yaml(yaml_content)
  tkdelete(text_widget, "1.0", "end")
  tkinsert(text_widget, "end", yaml_text)
}

# Save edits back to YAML file
save_yaml_file <- function(text_widget) {
  if (is.null(yaml_file_path)) {
    tkmessageBox(message = "No YAML file loaded.", icon = "warning")
    return()
  }

  edited_text <- tclvalue(tkget(text_widget, "1.0", "end"))
  tryCatch({
    edited_yaml <- yaml::yaml.load(edited_text)
    write_yaml(edited_yaml, file = yaml_file_path)
    tkmessageBox(message = "YAML saved successfully!", icon = "info")
  }, error = function(e) {
    tkmessageBox(message = paste("Failed to save YAML:", e$message), icon = "error")
  })
}

# --- GUI Layout ---
tt <- tktoplevel()
tkwm.title(tt, "Script Runner with YAML Editor and Plot Viewer")

# Top-level horizontal frame
main_frame <- tkframe(tt)
tkgrid(main_frame)

# Create a left frame for console
left_frame <- tkframe(main_frame)
tkgrid(left_frame, row = 0, column = 0, sticky = "nw")

# Console label
tkgrid(tklabel(left_frame, text = "Console Output:"), sticky = "w")

# Console frame for text and scrollbar
console_frame <- tkframe(left_frame)

# Create console text widget
console_text <- tktext(console_frame, width = 60, height = 10)

# Create scrollbar
scroll <- tkscrollbar(console_frame, orient = "vertical", 
                      command = function(...) tkyview(console_text, ...))

# Link scrollbar to text widget
tkconfigure(console_text, yscrollcommand = function(...) tkset(scroll, ...))

# Pack them together
tkpack(console_text, side = "left", fill = "both", expand = TRUE)
tkpack(scroll, side = "right", fill = "y")

# Grid the console frame
tkgrid(console_frame)

# Plot output
tkgrid(tklabel(left_frame, text = "Plot Output:"), sticky = "w")
plot_label <- tklabel(left_frame)
tkgrid(plot_label)

# Run button (under plot)
button_frame <- tkframe(left_frame)
button1 <- tkbutton(button_frame, text = "Run Step 1", command = function() run_my_script(console_text, plot_label,"step1.R"))
button2 <- tkbutton(button_frame, text = "Run Step 2", command = function() run_my_script(console_text, plot_label,"step2.R"))
button3 <- tkbutton(button_frame, text = "Run Step 3", command = function() run_my_script(console_text, plot_label,"step3.R"))
tkgrid(button1,button2,button3)
tkgrid(button_frame)

# Right side: YAML editor and buttons
right_frame <- tkframe(main_frame)
tkgrid(right_frame, row = 0, column = 1, sticky = "ne", padx = 10)

tkgrid(tklabel(right_frame, text = "YAML Editor:"), sticky = "w")
yaml_frame <- tkframe(right_frame)
yaml_text <- tktext(yaml_frame, width = 50, height = 25, wrap = "word")
#scroll2 <- tkscrollbar(yaml_frame, orient = "vertical", command = function(...) tkyview(yaml_text, ...))
tkpack(yaml_text, side = "left", fill = "both", expand = TRUE)
#tkpack(scroll2, side = "right", fill = "y")
tkgrid(yaml_frame)

# YAML Buttons
yaml_btn_frame <- tkframe(right_frame)
tkpack(tkbutton(yaml_btn_frame, text = "Load YAML", command = function() load_yaml_file(yaml_text)), side = "left", padx = 5)
tkpack(tkbutton(yaml_btn_frame, text = "Save YAML", command = function() save_yaml_file(yaml_text)), side = "left", padx = 5)
tkgrid(yaml_btn_frame, pady = 10)

tkwait.window(tt)
