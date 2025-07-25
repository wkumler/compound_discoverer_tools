
library(tidyverse)
library(RaMS)

# Read in standard list
stan_list <- read_csv("manual_mzvault/stan_list.csv") %>%
  filter(!is.na(rtmin))

# Connect to MS2 database and extract MS2 spectra
# matdb_stans.duckdb comes from running duckdb_conv.R
library(DBI)
duckcon <- dbConnect(duckdb::duckdb(), "manual_mzvault/matbd_stans.duckdb", read_only=TRUE)
extracted_ms2s <- stan_list %>%
  pmap(function(...){
    row_data <- list(...)
    mzmin_i <- pmppm(row_data$mz, 10)[1]
    mzmax_i <- pmppm(row_data$mz, 10)[2]
    rtmin_i <- row_data$rtmin
    rtmax_i <- row_data$rtmax
    
    duckquery <- sprintf(paste("SELECT * FROM MS2 WHERE premz BETWEEN %f AND %f",
                                "AND rt BETWEEN %f AND %f",
                                "AND filename LIKE '%%%s%%'"), 
                         mzmin_i, mzmax_i, rtmin_i, rtmax_i, row_data$HILIC_Mix)
    sarc_data <- dbGetQuery(duckcon, duckquery)

    sarc_data %>%
      # Use the top 5 most intense scans
      arrange(desc(int)) %>%
      filter(scan_idx%in%unique(scan_idx)[1:5], .by = filename) %>%
      # Remove fragments below 1% maximum intensity
      mutate(int=int/max(int)*100, .by=c(scan_idx, filename)) %>%
      # filter(int>5) %>%
      # Group fragments
      mutate(frag_group=mz_group(fragmz, ppm = 10), .by = c(filename)) %>%
      # Remove fragments that don't appear in at least 50% of the scans
      mutate(n_scans=n(), .by=c(filename, frag_group)) %>%
      filter(n_scans>=max(n_scans)*0.5, .by=filename) %>%
      select(-n_scans) %>%
      # Remove fragments that only appear in one file
      mutate(frag_group=mz_group(fragmz, ppm = 10)) %>%
      mutate(n_files=length(unique(filename)), .by=frag_group) %>%
      filter(n_files>1) %>%
      select(-n_files) %>%
      # Calculate consensus spectrum
      summarise(first_scan=min(scan_idx), med_fragmz=median(fragmz), med_premz=median(premz),
                med_int=median(int), rt=median(rt),
                compound_name=row_data$Compound_Name, .by=frag_group)
  }) %>%
  bind_rows()
dbDisconnect(duckcon)


# Need to build 4 tables corresponding to dbListTables(dbcon)
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
writecon <- dbConnect(RSQLite::SQLite(), "manual_mzvault/manual_vault.db")

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
