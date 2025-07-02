update_checklist_status <- function(labels, step_name, status) {
  lbl <- labels[[step_name]]
  
  if (is.null(lbl)) {
    warning(paste("Checklist step not found:", step_name))
    return()
  }
  
  if (tolower(status) == "pass") {
    tkconfigure(lbl, foreground = "green", font = "TkDefaultFont 10 bold")
  } else if (tolower(status) == "fail") {
    tkconfigure(lbl, foreground = "red", font = "TkDefaultFont 10 bold")
  } else if (tolower(status) == "running") {
    tkconfigure(lbl, foreground = "blue", font = "TkDefaultFont 10 italic")
  } else {
    tkconfigure(lbl, foreground = "black", font = "TkDefaultFont 10")
  }
}
