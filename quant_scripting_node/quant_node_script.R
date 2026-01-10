
print("Script starting!")

options(tidyverse.quiet = TRUE)
library(tidyverse)
suppressWarnings(library(rjson))

CD_json_in <- fromJSON(file=commandArgs()[6])
saveRDS(CD_json_in, "~/../Desktop/CD_json_in.rds")
# CD_json_in <- readRDS("~/../Desktop/CD_json_in.rds")

colname_regex_str <- c(
  "Area",
  "NormArea BMISed Area",
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

Compounds <- read.table(CD_json_in$Tables[[1]]$DataFile, header=TRUE, check.names = FALSE)

# internal_standard_regex <- CD_json_in$NodeParameters$`Internal standard regex`
# pooled_sample_regex <- CD_json_in$NodeParameters$`Pooled sample regex`
# half_v_full_regex <- CD_json_in$NodeParameters$`Dilution regex`
# exclude_std <- as.logical(CD_json_in$NodeParameters$`Exclude standards`)
# min_improvement <- as.numeric(CD_json_in$NodeParameters$`Minimal improvement threshold`)
# already_good <- as.numeric(CD_json_in$NodeParameters$`Already good enough threshold`)

stan_source <- "" # filename, commit number, or "" (pull down most recent)
column_type <- "HILIC"
recon_volume <- as.numeric(0.0004)
filter_volume <- as.numeric(2)
dilution_applied <- as.numeric(1)
stan_regex <- "_Std_"
matrix_regex <- "Matrix"

# If empty, pull down most recent
# If commit is referenced (either 6 chars or longer, alphanum, no slashes), expand to URL
# Otherwise read file directly (either URL or file path)
if(stan_source==""){
  stan_source <- "https://github.com/IngallsLabUW/Ingalls_Standards/raw/refs/heads/master/Ingalls_Lab_Standards.csv"
}
if(!str_detect(stan_source, "\\/")){
  # Assuming stan source is a commit if it doesn't look like a path
  stan_source <- paste0("https://github.com/IngallsLabUW/Ingalls_Standards/raw/", stan_source, "/Ingalls_Lab_Standards.csv")
}

stan_data <- stan_source %>%
  read_csv(show_col_types = FALSE) %>%
  filter(Column==column_type) %>% #Match column type
  filter(!is.na(HILIC_Mix)) %>% #Remove IS
  mutate(Polarity=ifelse(z<0, "Negative", "Positive")) %>%
  select(Compound_Name, Polarity, HILIC_Mix, Concentration_uM)

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
  ) %>%
  filter(`File Name`!="Max") %>%
  filter(Name!="")

RFs <- Compounds_long %>%
  filter(str_detect(`File Name`, stan_regex)) %>%
  select(`Compounds ID`, Name, `File Name`, Polarity, Area) %>%
  inner_join(stan_data, by = join_by(Name==Compound_Name, Polarity)) %>%
  mutate(mix_type=ifelse(str_detect(`File Name`, HILIC_Mix), "correct_mix", "other_mix")) %>%
  filter(str_detect(`File Name`, "Matrix")) %>%
  select(`Compounds ID`, Name, Area, Concentration_uM, mix_type) %>%
  pivot_wider(names_from = mix_type, values_from = Area, values_fn = mean) %>%
  mutate(RF=(correct_mix-other_mix)/Concentration_uM) %>%
  select(`Compounds ID`, RF)

quant_concs <- Compounds_long %>%
  inner_join(RFs) %>%
  mutate(conc_in_nM=NormArea_BMISed_Area/RF/filter_volume*recon_volume*1000*dilution_applied) %>%
  select(`Compounds ID`, Name, Polarity, RF, `File Name`, conc_in_nM) %>%
  # pivot_wider(names_from = c(Name, `Compounds ID`), values_from = conc_in_nM, names_glue = "{Name} ({`Compounds ID`})")
  print()


matched_names <- data.frame(
  `File Name`=str_subset(colnames(Compounds), "^Area .* F\\d+"),
  patched=unique(quant_concs$`File Name`), 
  check.names = FALSE
)

wide_quant <- quant_concs %>%
  left_join(matched_names, by=join_by(`File Name`==patched), suffix = c(" patched", "")) %>%
  select(`Compounds ID`, RF, `File Name`, conc_in_nM) %>%
  mutate(`File Name`=str_replace(`File Name`, "^Area ", "nM ")) %>%
  pivot_wider(names_from = `File Name`, values_from = conc_in_nM)
# data.output <- left_join(Compounds, wide_BMIS, by = "Compounds ID")
data.output <- wide_quant # Apparently CD only wants the new columns???

CD_json_out <- CD_json_in
newcolumn <- list()
newcolumn[[1]] = "RF"       ## ColumnName
newcolumn[[2]] = FALSE     ## IsID
newcolumn[[3]] = "String"    ## DataType
newcolumn[[4]] <- list()    ## Options
names(newcolumn) <- c("ColumnName", "IsID", "DataType", "Options")

new_col_descs <- lapply(matched_names$`File Name`, function(filename_i){
  list(
    ColumnName=filename_i,
    IsID=FALSE,
    DataType="Float",
    Options=list(
      DataGroupName="Conc."
    )
  )
})
CD_json_out$Tables[[1]]$ColumnDescriptions <- c(list(newcolumn), new_col_descs)

# Write modified table to temporary folder.
datafile <- CD_json_out$Tables[[1]]$DataFile
resultout <- gsub(".txt", ".out.txt", datafile)
write.table(data.output, file = resultout, sep='\t', row.names = FALSE)

# Write out node_response.json file - use same file as node_args.json but change the pathway input file to the new one
CD_json_out$Tables[[1]]$DataFile <- resultout
jsonOutFile <- CD_json_out$ExpectedResponsePath
responseJSON <- toJSON(CD_json_out, indent=1, method="C")

# responseJSON has incorrect format for the empty Options lists.  Will use a regular expression to find and replace the [\n\n\] with the {}
responseJSON2 <- gsub("\\[\n\n[[:blank:]]+\\]", "{ }", responseJSON)
jsonfileconn <- file(jsonOutFile)
writeLines(responseJSON2, jsonfileconn)
close (jsonfileconn)
