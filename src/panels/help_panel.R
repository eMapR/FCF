create_help_panel <- function(parent_frame) {
  help_frame <- tkframe(parent_frame)
  
  help_label <- tklabel(help_frame, text = "Help / Documentation Area", width = 60, height = 10, relief = "groove", wraplength = 400, justify = "left")
  
  tkpack(help_label, expand = TRUE, fill = "both")

  return(list(frame = help_frame, help_widget = help_label))
}
