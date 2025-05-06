# Load libraries
library(tcltk)
library(yaml)

# Source all the subpanel scripts
source("panels/console_panel.R")
source("panels/plot_panel.R")
source("panels/checklist_panel.R")
source("panels/run_buttons_panel.R")
source("panels/yaml_editor_panel.R")
source("panels/help_panel.R")
source("handlers/run_my_script.R")
source("handlers/run_script_0.R")
source("handlers/yaml_handlers.R")
source("handlers/checklist_handlers.R")


# Create the main window
main_window <- tktoplevel()
tkwm.title(main_window, "My Bayes Update")
main_frame <- tkframe(main_window)
tkpack(main_frame, expand = TRUE, fill = "both")

# Create the three main vertical columns
left_frame <- tkframe(main_frame)
center_frame <- tkframe(main_frame)
right_frame <- tkframe(main_frame)

tkpack(left_frame, center_frame, right_frame, side = "left", fill = "both", expand = TRUE)

# ==== LEFT COLUMN ====
checklist <- create_checklist_panel(left_frame)
tkpack(checklist$frame, expand = TRUE, fill = "both", padx = 5, pady = 5)

# ==== CENTER COLUMN ====
# Console output
console <- create_console_panel(center_frame)
tkpack(console$frame, side = "top", fill = "both", expand = TRUE, padx = 5, pady = 5)

# Plot output
plot <- create_plot_panel(center_frame)
tkpack(plot$frame, side = "top", fill = "both", expand = TRUE, padx = 5, pady = 5)

# Run buttons
run_buttons <- create_run_buttons_panel(center_frame)
tkpack(run_buttons$frame, side = "top", fill = "both", padx = 5, pady = 5)

# ==== RIGHT COLUMN ====
# YAML editor
yaml_editor <- create_yaml_editor_panel(right_frame)
# Frame already packed inside function

# Help/documentation area
help_panel <- create_help_panel(right_frame)
tkpack(help_panel$frame, expand = TRUE, fill = "both", padx = 5, pady = 5)

# ======

# Connect Run Buttons
tkconfigure(run_buttons$buttons$step1, 
            command = function() run_script_0(console$text_widget, plot$plot_widget, "step0.R", checklist$labels, "Check YAML File"))
tkconfigure(run_buttons$buttons$step2, 
            command = function() run_my_script(console$text_widget, plot$plot_widget, "step1.R", checklist$labels, "Check YAML File"))
tkconfigure(run_buttons$buttons$step3, 
            command = function() run_my_script(console$text_widget, plot$plot_widget, "step2.R", checklist$labels, "Check Raster"))
tkconfigure(run_buttons$buttons$step4, 
            command = function() run_my_script(console$text_widget, plot$plot_widget, "step3.R", checklist$labels, "Load Image"))

# Connect YAML Load/Save buttons
tkconfigure(yaml_editor$load_button, 
            command = function() load_yaml_file(yaml_editor$text_widget))
tkconfigure(yaml_editor$save_button, 
            command = function() save_yaml_file(yaml_editor$text_widget))



# Keep window open
tkwait.window(main_window)
