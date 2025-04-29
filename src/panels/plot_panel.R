create_plot_panel <- function(parent_frame) {
  plot_frame <- tkframe(parent_frame)
  
  plot_label <- tklabel(plot_frame, relief = "sunken")
  
  tkpack(plot_label, expand = TRUE, fill = "both")
  
  return(list(frame = plot_frame, plot_widget = plot_label))
}
