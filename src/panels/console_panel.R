create_console_panel <- function(parent_frame) {
  console_frame <- tkframe(parent_frame)
  
  console_text <- tktext(console_frame, width = 80, height = 10)
  console_scroll <- tkscrollbar(console_frame, orient = "vertical", 
                                command = function(...) tkyview(console_text, ...))
  
  tkconfigure(console_text, yscrollcommand = function(...) tkset(console_scroll, ...))
  
  tkpack(console_text, side = "left", fill = "both", expand = TRUE)
  tkpack(console_scroll, side = "right", fill = "y")
  
  return(list(frame = console_frame, text_widget = console_text))
}
