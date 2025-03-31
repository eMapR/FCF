###############
## libraries ##
library(terra)

# Load your config
cfg <- yaml::read_yaml("/vol/v1/FCF/spatial-model-walkthrough/assets/test-bed-models/old_scripts/config.yml")

# Use it
print(cfg$input_path)
print(cfg$output_path)
print(cfg$phi)

check_file_path <- function(path) {
  if (!file.exists(path) || file.info(path)$isdir) {
    message("The file path provided does not point to a real file.")
    message("Please check and edit your config file.")
    stop("Invalid file path: ", path)
  }
}


# Example usage
check_file_path(cfg$input_path)
check_file_path(cfg$output_path)
######
## Check parameters in YAML

## check file paths 

## chech values 



