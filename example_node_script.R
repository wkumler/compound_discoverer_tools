
library(rjson)
CD_json_in <- fromJSON(file=commandArgs()[6])

node_dev_dir <- "C:/Users/Ingalls Lab/Desktop/compound_discoverer_tools"
project_dir <- "/duckdb_scripting_node"

lapply(CD_json_in$Tables, function(table_info_i){
  table_i <- read.table(table_info_i$DataFile, header=TRUE, check.names = FALSE)
  name_i <- paste0(node_dev_dir, project_dir, "/", table_info_i$TableName, ".csv")
  assign(x = gsub(" ", "_", table_info_i$TableName), envir = globalenv())
  write.csv(table_i, name_i, row.names = FALSE)
})

save.image(file=paste0(node_dev_dir, project_dir, "/node_output.RData"))

# load("C:/Users/Ingalls Lab/Desktop/compound_discoverer_tools/duckdb_scripting_node/node_output.RData")
