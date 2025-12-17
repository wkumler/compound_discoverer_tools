
message("Script starting!")

library(rjson)
CD_json_in <- fromJSON(file=commandArgs()[6])

node_dev_dir <- "C:/Users/Ingalls Lab/Desktop/compound_discoverer_tools"
project_dir <- "/bmis_scripting_node"

v <- lapply(CD_json_in$Tables, function(table_info_i){
  print(table_info_i$TableName)
  table_i <- read.table(table_info_i$DataFile, header=TRUE, check.names = FALSE)
  name_i <- paste0(node_dev_dir, project_dir, "/", table_info_i$TableName, ".csv")
  assign(x = gsub(" ", "_", table_info_i$TableName), table_i, envir = globalenv())
  write.csv(table_i, name_i, row.names = FALSE)
})

save.image(file=paste0(node_dev_dir, project_dir, "/node_envir.RData"))

# load("C:/Users/Ingalls Lab/Desktop/compound_discoverer_tools/duckdb_scripting_node/node_output.RData")






# load("bmis_scripting_node/node_envir.RData")

library(tidyverse)

colname_regex_str <- c(
  "Area",
  "Gap Status",
  "Gap Fill Status",
  "PQF Zig-Zag Index",
  "PQF FWHM2Base",
  "PQF Jaggedness",
  "PQF Modality",
  "PQF Area Ratio",
  "PQF Gaps Ratio",
  "PQF Number of Point",
  "PQF Number of Gap",
  "Peak Rating"
) %>%
  str_replace_all(" ", "_") %>%
  paste0(collapse = "|") %>%
  paste0("^(", ., ") ")

Compounds_long <- Compounds %>%
  # slice(1) %>%
  # select(`Compounds ID`, matches("^(Area|Peak Rating) ")) %>%
  rename_with(
    ~ str_replace_all(str_remove_all(.x, "raw F\\d+"), " (?=.* [0-9]{6}_.*$)", "_")
  ) %>%
  pivot_longer(
    cols = matches(colname_regex_str),
    names_to = c(".value", "File Name"),
    names_sep = " ",
    values_drop_na = FALSE
  )


