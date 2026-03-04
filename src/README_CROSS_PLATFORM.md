# Cross-Platform Setup Guide

This Bayesian spatial modeling application now works on both Windows and Linux.

## Changes Made for Cross-Platform Compatibility

### 1. Path Handling
- All file paths now use `normalizePath()` and `file.path()` for proper path construction
- Paths work with both forward slashes (/) and backslashes (\)
- R automatically converts paths to the correct format for your OS

### 2. File Operations
- Added `Sys.sleep(0.1)` delays before file removal to handle Windows file locking
- Improved error handling for file operations

### 3. Rscript Execution
- Changed from hardcoded `"Rscript"` to `file.path(R.home("bin"), "Rscript")`
- Ensures the correct Rscript executable is found on both platforms

## Configuration File Setup

### Option 1: Relative Paths (Recommended)
```yaml
data_dir: ./data
output_dir: ./results
```

### Option 2: Absolute Paths

**Windows:**
```yaml
data_dir: C:/Users/YourName/bayesUpdate/data
output_dir: C:/Users/YourName/bayesUpdate/results
```

**Linux:**
```yaml
data_dir: /home/username/bayesUpdate/data
output_dir: /vol/v1/FCF/bayesUpdate/results
```

## Important Notes

1. **Always use forward slashes (/)** in YAML config files, even on Windows
   - ✅ Correct: `C:/Users/data`
   - ❌ Wrong: `C:\Users\data` (backslashes need escaping in YAML)

2. **Directory Structure Required:**
   ```
   data_dir/
   └── [site-name]/
       ├── bnd/
       │   └── bnd.shp (+ .shx, .dbf, .prj)
       ├── plots/
       │   └── plots.shp (+ .shx, .dbf, .prj)
       └── carbon-map.tif
   ```

3. **Required R Packages:**
   ```r
   install.packages(c("tcltk", "yaml", "terra", "geoR", "spBayes"))
   ```

## Running the Application

### On Linux:
```bash
Rscript main_gui.R
```

### On Windows:
```cmd
Rscript main_gui.R
```

Or double-click `main_gui.R` if R is associated with .R files.

## Troubleshooting

### Windows-Specific Issues

**Problem:** "Cannot remove plot.png"
- **Solution:** The brief delays added should handle this, but if issues persist, close any image viewers that might have the file open

**Problem:** Paths not found
- **Solution:** Check that you're using forward slashes in config.yaml

### Linux-Specific Issues

**Problem:** Permission denied
- **Solution:** Ensure you have write permissions for output directories

### Both Platforms

**Problem:** Rscript not found
- **Solution:** Ensure R is installed and in your system PATH
- Test with: `Rscript --version`

**Problem:** Package not found
- **Solution:** Install missing packages in R console:
  ```r
  install.packages("package_name")
  ```

## Testing Your Setup

1. Copy `config_example.yaml` to `config.yaml`
2. Update paths in `config.yaml` for your system
3. Ensure your data directory structure matches the required format
4. Run `Rscript main_gui.R`
5. Click "Check Assets" to validate your configuration
