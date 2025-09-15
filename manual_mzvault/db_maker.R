
library(tidyverse)
library(RaMS)
library(DBI)

# This script creates an mzVault database for use in the Thermo ecosystem
# of mass-spec instruments and software. It requires as input a list of
# compounds with their retention time bounds and m/z values as well as a
# database of MS2 data, e.g. that produced by the mzml2db package.
# It produces as output an mzVault database with the .db ending ready for
# import into Compound Discoverer or mzVault. Users can modify the algorithm
# used to select MS2 spectra below.



# Build an MS database from the files we want to look in for the vault
# devtools::install_github("wkumler/mzml2db", build_vignettes = TRUE)
library(mzml2db)
# Point to the location of your mzML files that have MS2 data in them
# ms_files <- list.files(pattern = "mzML")
# Convert to a duckdb database (will take a few minutes)
all_ms2_database_filename <- "manual_mzvault/standards.duckdb"
# mzml2db(ms_files, db_name = all_ms2_database_filename, overwrite_ok = TRUE)


# Build a list of all the standards for which you'd like to generate an mzVault
# This gets written out as a CSV that can then be edited in Excel to add RT bounds
# read_csv("https://github.com/IngallsLabUW/Ingalls_Standards/raw/refs/heads/master/Ingalls_Lab_Standards.csv") %>%
#   filter(z>0) %>%
#   filter(Column=="HILIC") %>%
#   select(Compound_Name, mz, HILIC_Mix, Empirical_Formula) %>%
#   mutate(rtmin=NA, rtmax=NA) %>%
#   write_csv("manual_mzvault/stan_list.csv")
# The unmodified standard list is used to loop over the various compounds
# interactively to identify peak boundaries if necessary
# stan_list <- read_csv("manual_mzvault/stan_list.csv")
# Read in standard list with rtmin and rtmax bounds for use
stan_list <- readxl::read_excel("manual_mzvault/stan_list.xlsx", col_types = c("text", "numeric", "text", "text", "numeric", "numeric", "text"), na = "NA") %>%
  filter(!is.na(rtmin))


# Confirm that stan list exists and has the correct info
is(stan_list, "data.frame")
"rtmin"%in%names(stan_list)
"rtmax"%in%names(stan_list)
"Compound_Name"%in%names(stan_list)
"Empirical_Formula"%in%names(stan_list)

# Confirm that the duckdb file exists and has the correct info
file.exists("manual_mzvault/standards.duckdb")
duckcon <- dbConnect(duckdb::duckdb(), all_ms2_database_filename, read_only=FALSE)
"MS2"%in%dbListTables(duckcon)
"rt"%in%dbListFields(duckcon, "MS2")
"premz"%in%dbListFields(duckcon, "MS2")
"fragmz"%in%dbListFields(duckcon, "MS2")
"int"%in%dbListFields(duckcon, "MS2")



duckcon <- dbConnect(duckdb::duckdb(), "manual_mzvault/standards.duckdb", read_only=FALSE)
# dbSendQuery(duckcon, "UPDATE MS1 SET rt = rt * 60")
# dbSendQuery(duckcon, "UPDATE MS2 SET rt = rt * 60")
extracted_ms2s <- stan_list %>%
  # slice(1) %>%
  pmap(function(...){
    row_data <- list(...)
    mzmin_i <- pmppm(row_data$mz, 10)[1]
    mzmax_i <- pmppm(row_data$mz, 10)[2]
    rtmin_i <- row_data$rtmin
    rtmax_i <- row_data$rtmax
    
    # Query the database for MS2 data associated with the given compound
    duckquery <- sprintf(paste("SELECT * FROM MS2 WHERE premz BETWEEN %f AND %f",
                                "AND rt BETWEEN %f AND %f"), 
                         mzmin_i, mzmax_i, rtmin_i, rtmax_i)
    sarc_data <- dbGetQuery(duckcon, duckquery)
    

    # Decide how to convert multiple scans into a single unique spectrum
    # Must return a data frame with compound name, formula, rt, scan_number, premz, fragmz, and intensity
    sarc_data %>%
      # Use the top 5 most intense scans
      arrange(desc(int)) %>%
      filter(scan_idx%in%unique(scan_idx)[1:10], .by = filename) %>%
      # Remove fragments below 1% maximum intensity
      mutate(int=int/max(int)*100, .by=c(scan_idx, filename)) %>%
      # filter(int>5) %>%
      # Group fragments
      mutate(frag_group=mz_group(fragmz, ppm = 10), .by = c(filename)) %>%
      # Remove fragments that don't appear in at least 50% of the scans
      mutate(n_scans=n(), .by=c(filename, frag_group)) %>%
      filter(n_scans>=max(n_scans)*1, .by=filename) %>%
      select(-n_scans) %>%
      # Remove fragments that only appear in one file
      mutate(frag_group=mz_group(fragmz, ppm = 10)) %>%
      mutate(n_files=length(unique(filename)), .by=frag_group) %>%
      filter(n_files>0) %>%
      select(-n_files) %>%
      # Calculate consensus spectrum
      summarise(first_scan=min(scan_idx), med_fragmz=median(fragmz), med_premz=median(premz),
                med_int=median(int), rt=median(rt),
                compound_name=row_data$Compound_Name, .by=frag_group) %>%
      arrange(med_fragmz)
  }, .progress=TRUE) %>%
  bind_rows()
write_csv(extracted_ms2s, "manual_mzvault/extracted_ms2s.csv")
dbDisconnect(duckcon)


# Need to build 4 tables corresponding to dbListTables(dbcon)
# CompoundTable contains info about the individual compounds
# SpectrumTable contains a combined spectrum for each compound, linked by CompoundId
# MaintenanceTable is empty??
# HeaderTable records version and afaics is always the same
buildCompoundTable <- function(stans){
  data.frame(CompoundId=seq_len(nrow(stans)),
             Formula=stans$Empirical_Formula,
             Name=stans$Compound_Name,
             Synonyms="", Tag="", Sequence="", CASId="", ChemSpiderId="", HMDBId="", KEGGId="", PubChemId="", 
             Structure="", mzCloudId=NA_integer_, CompoundClass="", SmilesDescription="", InChiKey="",
             check.names = FALSE)
}
outCompoundTable <- buildCompoundTable(stan_list)

mzVaultEncode <- function(num_vec){
  blob::blob(writeBin(num_vec, raw(), size = 8, endian = "little"))
}
buildSpectrumTable <- function(scan_stuff){
  scan_stuff %>%
    summarise(RetentionTime=mean(rt), ScanNumber=min(first_scan), PrecursorMass=mean(med_premz), 
              blobMass=mzVaultEncode(med_fragmz), blobIntensity=mzVaultEncode(med_int), .by = compound_name) %>%
    mutate(SpectrumId=row_number(), CompoundId=row_number(), mzCloudURL="", ScanFilter="", NeutralMass=0,
           CollisionEnergy="35.00", Polarity="+", FragmentationMode="HCD", IonizationMode="ESI",
           MassAnalyzer="", InstrumentName="Orbitrap Astral OA10249", InstrumentOperator="Ingalls Lab",
           RawFileURL="C:\\Users\\Ingalls Lab\\Desktop\\MATBD_comp_CD\\250625_Std_4uMStdsMix2InH2O_pos1.raw",
           blobAccuracy="", blobResolution="", blobNoises="", blobFlags="", blobTopPeaks="",
           Version=5L, CreationDate=format(Sys.time(), "%m/%d/%Y %H:%M:%S"), Curator="", CurationType="Averaged",
           PrecursorIonType="", Accession="") %>%
    # Reorder in the correct order in case that matters
    select("SpectrumId", "CompoundId", "mzCloudURL", "ScanFilter", "RetentionTime", 
           "ScanNumber", "PrecursorMass", "NeutralMass", "CollisionEnergy", 
           "Polarity", "FragmentationMode", "IonizationMode", "MassAnalyzer", 
           "InstrumentName", "InstrumentOperator", "RawFileURL", "blobMass", 
           "blobIntensity", "blobAccuracy", "blobResolution", "blobNoises", 
           "blobFlags", "blobTopPeaks", "Version", "CreationDate", "Curator", 
           "CurationType", "PrecursorIonType", "Accession")
}
outSpectrumTable <- buildSpectrumTable(extracted_ms2s)

outMaintenanceTable <- data.frame(
  CreationDate=character(0), NoofCompoundsModified=numeric(0), Description=character(0)
)
outHeaderTable <- data.frame(
  version=5L, CreationDate=NA_character_, LastModifiedDate=NA_character_, Description=NA_character_, 
  Company=NA_character_, ReadOnly=NA_real_, UserAccess=NA_character_, PartialEdits=NA_real_
)

# Write out to new database
# Schema have been stolen from a random existing database
out_db_name <- "manual_mzvault/ingalls_mzvault_pos_70CE.db"
if(file.exists(out_db_name)){
  unlink(out_db_name)
}

writecon <- dbConnect(RSQLite::SQLite(), out_db_name)

create_cmpd <- "CREATE TABLE CompoundTable (CompoundId INTEGER PRIMARY KEY, Formula TEXT, Name TEXT, Synonyms BLOB_TEXT, Tag TEXT, Sequence TEXT, CASId TEXT, ChemSpiderId TEXT, HMDBId TEXT, KEGGId TEXT, PubChemId TEXT, Structure BLOB_TEXT, mzCloudId INTEGER, CompoundClass TEXT, SmilesDescription TEXT, InChiKey TEXT )"
dbExecute(writecon, create_cmpd)
dbAppendTable(writecon, "CompoundTable", outCompoundTable)

create_head <- "CREATE TABLE HeaderTable (version INTEGER, CreationDate TEXT, LastModifiedDate TEXT, Description TEXT, Company TEXT, ReadOnly BOOL, UserAccess TEXT, PartialEdits BOOL)"
dbExecute(writecon, create_head)
dbAppendTable(writecon, "HeaderTable", outHeaderTable)

create_maint <- "CREATE TABLE MaintenanceTable (CreationDate TEXT, NoofCompoundsModified INTEGER, Description TEXT)"
dbExecute(writecon, create_maint)
dbAppendTable(writecon, "MaintenanceTable", outMaintenanceTable)

create_maint <- "CREATE TABLE SpectrumTable (SpectrumId INTEGER PRIMARY KEY, CompoundId INTEGER, mzCloudURL TEXT, ScanFilter TEXT, RetentionTime DOUBLE, ScanNumber INTEGER, PrecursorMass DOUBLE, NeutralMass DOUBLE, CollisionEnergy TEXT, Polarity TEXT, FragmentationMode TEXT, IonizationMode TEXT, MassAnalyzer TEXT, InstrumentName TEXT, InstrumentOperator TEXT, RawFileURL TEXT, blobMass BLOB, blobIntensity BLOB, blobAccuracy BLOB, blobResolution BLOB, blobNoises BLOB, blobFlags BLOB, blobTopPeaks BLOB, Version INTEGER, CreationDate TEXT, Curator TEXT, CurationType , PrecursorIonType TEXT, Accession TEXT)"
dbExecute(writecon, create_maint)
dbAppendTable(writecon, "SpectrumTable", outSpectrumTable)

dbDisconnect(writecon)
