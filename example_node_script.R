
# Read arguments from CD.
args <- commandArgs()


# 6th argument is the name of the JSON file
inputFile <- args[6]


# Open JSON file, find exported files, read into tables
library(rjson)
CD_json_in <- fromJSON(file=inputFile)

Compounds <- read.table(CD_json_in$Tables[[1]]$DataFile, header=TRUE, check.names = FALSE, stringsAsFactors = FALSE)

save.image(file="C:/Users/Ingalls Lab/Desktop/compound_discoverer_tools/node_output.RData")

# load("C:\\TEMP\\Rimage.dat")

