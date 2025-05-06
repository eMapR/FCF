create_checklist_panel <- function(parent_frame) {
  checklist_frame <- tkframe(parent_frame)
  
  steps <- c("Check YAML File", "Check YAML Syntax", "Load Image", "Train Model")
  checklist_labels <- list()

  for (step in steps) {
    lbl <- tklabel(checklist_frame, text = step, anchor = "w", justify = "left")
    tkpack(lbl, side = "top", anchor = "w")
    checklist_labels[[step]] <- lbl
  }
  
  return(list(frame = checklist_frame, labels = checklist_labels))
}
