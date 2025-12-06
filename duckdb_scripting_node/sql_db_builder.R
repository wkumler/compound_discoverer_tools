
library(rjson)
library(mzml2db)

CD_json_in <- fromJSON(file=commandArgs()[6])
saveRDS(CD_json_in, file = "C:\\Users\\Ingalls Lab\\Desktop\\compound_discoverer_tools\\duckdb_scripting_node\\CD_json_in.rds")
CD_json_in <- readRDS("C:\\Users\\Ingalls Lab\\Desktop\\compound_discoverer_tools\\duckdb_scripting_node\\CD_json_in.rds")

db_engine <- CD_json_in$NodeParameters$`Database type`
# db_engine <- "duckdb"
if(db_engine=="duckdb"){
  library(duckdb)
} else if(db_engine=="SQLite"){
  library(RSQLite)
} else {
  stop(paste("Database type", db_engine, "not supported"))
}

output_file <- CD_json_in$NodeParameters$`Output database pathname`
# output_file <- "C:\\Users\\Ingalls Lab\\Desktop\\compound_discoverer_tools\\duckdb_scripting_node\\msdata.duckdb"

ms_levels_to_convert <- CD_json_in$NodeParameters$`MS levels`
# ms_levels_to_convert <- 1
# ms_levels_to_convert <- [1-3]

file_subset_pattern <- CD_json_in$NodeParameters$`Database file subset`
# file_subset_pattern <- "Poo"


msconvert_exe_path <- CD_json_in$NodeParameters$`msconvert path`
# msconvert_exe_path <- ""

centroid <- as.logical(CD_json_in$NodeParameters$`Centroid?`)
# centroid <- TRUE

mzml_write_path <- CD_json_in$NodeParameters$`Intermediate mzML write path`
# mzml_write_path <- ""

remove_mzmls <- as.logical(CD_json_in$NodeParameters$`Remove mzMLs?`)
# remove_mzmls <- TRUE

if(mzml_write_path=="" && !remove_mzmls){
  warning("mzMLs are being written to a temporary path and not removed")
}

WorkflowInputFiles <- read.table(CD_json_in$Tables[[1]]$DataFile, header=TRUE)
raw_file_paths <- WorkflowInputFiles$File.Name
if(file_subset_pattern!=""){
  message(paste("Filtering for file pattern \"", file_subset_pattern, "\""))
  raw_file_paths <- raw_file_paths[grepl(file_subset_pattern, raw_file_paths)]
}

first_few <- basename(raw_file_paths[1:min(length(raw_file_paths), 3)])
message(paste("Successfully read WorkflowInputFiles, first few filenames:", 
              paste(first_few, collapse = "; ")))


if(msconvert_exe_path==""){
  msconvert_cmd <- paste("msconvert", paste0("\"", raw_file_paths, "\"", collapse = " "))
  message("Using msconvert on PATH")
} else {
  msconvert_cmd <- paste(msconvert_exe_path, paste(raw_file_paths, collapse = " "))
  message(paste("Using msconvert at"), msconvert_exe_path)
}

if(is.null(mzml_write_path)){
  temp_dir <- tempdir()
} else {
  temp_dir <- mzml_write_path
}
message(paste("Writing temporary mzMLs to", temp_dir))
msconvert_cmd <- paste(msconvert_cmd, "-o", temp_dir)

mzml_paths <- paste(temp_dir, basename(raw_file_paths), sep = "\\")
mzml_paths <- gsub("\\.raw$", "\\.mzML", mzml_paths)
if(remove_mzmls){
  on.exit(file.remove(mzml_paths))
}

if(centroid){
  msconvert_cmd <- paste(msconvert_cmd, "--filter \"peakPicking true 1-\"")
}

if(ms_levels_to_convert==""){
  msconvert_cmd <- paste(msconvert_cmd, "--filter \"msLevel", ms_levels_to_convert, "\"")
}

message(paste("msconvert command:", msconvert_cmd))
system(msconvert_cmd, show.output.on.console = FALSE)

message(paste("Converting to", db_engine))
engine <- eval(parse(text=paste0(db_engine, "()")))
mzml2db(ms_files = mzml_paths, db_engine = engine, db_name = output_file, verbosity = 0, sort_by = "mz", overwrite_ok=TRUE)
message(paste("Database constructed at", output_file))
