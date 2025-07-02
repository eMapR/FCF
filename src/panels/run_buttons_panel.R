create_run_buttons_panel <- function(parent_frame) {
  button_frame <- tkframe(parent_frame)
  
  run_step1 <- tkbutton(button_frame, text = "Check Assets")
  run_step2 <- tkbutton(button_frame, text = "Run Step 2")
  run_step3 <- tkbutton(button_frame, text = "Run Step 3")
  run_step4 <- tkbutton(button_frame, text = "Run Step 4")
  
  tkpack(run_step1, run_step2, run_step3, run_step4, side = "top", padx = 2, pady = 2, fill = "x")
  
  # Checkbox for auto-populate parameters
  auto_populate <- tclVar(0)
  auto_checkbox <- tkcheckbutton(button_frame, text = "Auto-populate Parameters", variable = auto_populate)
  tkpack(auto_checkbox, side = "top", pady = 5)

  return(list(frame = button_frame, 
              buttons = list(step1 = run_step1, step2 = run_step2, step3 = run_step3, step4 = run_step4),
              auto_populate_var = auto_populate))
}
