# Handler environment (private memory for YAML stuff)
yaml_env <- new.env()

# Load YAML file and display in editor
load_yaml_file <- function(text_widget) {
  yaml_file <- tclvalue(tkgetOpenFile(filetypes = "{{YAML Files} {.yaml .yml}} {{All files} {*.*}}"))
  if (yaml_file == "") return()

  yaml_content <- yaml::read_yaml(yaml_file)
  yaml_env$yaml_data <- yaml_content
  yaml_env$yaml_file_path <- yaml_file

  yaml_text <- yaml::as.yaml(yaml_content)
  tkdelete(text_widget, "1.0", "end")
  tkinsert(text_widget, "end", yaml_text)
}

# Save edits back to YAML file
save_yaml_file <- function(text_widget) {
  if (is.null(yaml_env$yaml_file_path)) {
    tkmessageBox(message = "No YAML file loaded.", icon = "warning")
    return()
  }

  edited_text <- tclvalue(tkget(text_widget, "1.0", "end"))
  tryCatch({
    edited_yaml <- yaml::yaml.load(edited_text)
    yaml::write_yaml(edited_yaml, file = yaml_env$yaml_file_path)
    tkmessageBox(message = "YAML saved successfully!", icon = "info")
  }, error = function(e) {
    tkmessageBox(message = paste("Failed to save YAML:", e$message), icon = "error")
  })
}
