create_yaml_editor_panel <- function(parent_frame) {
  yaml_frame <- tkframe(parent_frame)
  
  yaml_text <- tktext(yaml_frame, width = 60, height = 15)
  yaml_scroll <- tkscrollbar(yaml_frame, orient = "vertical", 
                             command = function(...) tkyview(yaml_text, ...))
  
  tkconfigure(yaml_text, yscrollcommand = function(...) tkset(yaml_scroll, ...))
  
  tkpack(yaml_text, side = "left", fill = "both", expand = TRUE)
  tkpack(yaml_scroll, side = "right", fill = "y")

  # Load and Save buttons
  button_frame <- tkframe(parent_frame)
  load_button <- tkbutton(button_frame, text = "Load YAML")
  save_button <- tkbutton(button_frame, text = "Save YAML")
  
  tkpack(load_button, save_button, side = "left", padx = 5, pady = 5)

  tkpack(yaml_frame, fill = "both", expand = TRUE)
  tkpack(button_frame, fill = "x")
  
  return(list(frame = yaml_frame, 
              text_widget = yaml_text, 
              load_button = load_button, 
              save_button = save_button))
}
