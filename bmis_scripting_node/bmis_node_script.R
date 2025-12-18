
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
  ) %>%
  filter(`File Name`!="Max")

internal_standard_regex <- ", \\d"
pooled_sample_regex <- "_Poo_"
half_v_full_regex <- "Half|Full"
min_improvement <- 0.2
already_good <- 0.1

all_IS <- Compounds_long %>%
  filter(str_detect(Name, internal_standard_regex)) %>%
  mutate(samp_type=ifelse(str_detect(`File Name`, pooled_sample_regex), "Pooled", "All")) %>%
  select(Name, `File Name`, samp_type, Area)

pooled_IS <- Compounds_long %>%
  filter(str_detect(Name, internal_standard_regex)) %>%
  filter(str_detect(`File Name`, pooled_sample_regex)) %>%
  select(Name, `File Name`, Area) %>%
  mutate(pooled_type=str_extract(`File Name`, half_v_full_regex)) %>%
  bind_rows(
    distinct(., `File Name`, pooled_type) %>% 
      mutate(Name="None") %>%
      mutate(Area=ifelse(pooled_type=="Full", 1, 0.5))
  )

ggplot(pooled_IS) +
  geom_boxplot(aes(x=pooled_type, y=Area)) +
  geom_hline(yintercept = 0) +
  facet_wrap(~Name, scales="free_y", ncol=2) +
  theme_bw()
pooled_IS %>%
  mutate(`File Name`=str_remove(`File Name`, half_v_full_regex)) %>%
  pivot_wider(names_from = pooled_type, values_from=Area) %>%
  ggplot() +
  geom_point(aes(x=Full, y=Half, color=Name)) +
  geom_abline(slope = 1, intercept = 0) +
  scale_x_log10() +
  scale_y_log10() +
  coord_equal() +
  theme(legend.position = "top") +
  guides(color=guide_legend(ncol = 2))


IS_areas <- Compounds_long %>%
  filter(str_detect(Name, internal_standard_regex)) %>%
  select(`Compounds ID`, Name, `File Name`, Area) %>%
  mutate(pooled_type=str_extract(`File Name`, half_v_full_regex)) %>%
  mutate(pooled_type=ifelse(is.na(pooled_type), "Unpooled", pooled_type)) %>%
  bind_rows(
    distinct(., `File Name`, pooled_type) %>% 
      mutate(`Compounds ID`=0) %>%
      mutate(Name="None") %>%
      mutate(Area=ifelse(pooled_type=="Half", 0.5, 1))
  ) %>%
  select(Name, `File Name`, Area)

all_cvs <- Compounds_long %>%
  select(`Compounds ID`, Name, `File Name`, Area) %>%
  full_join(IS_areas, by="File Name", suffix = c("", "_IS"), relationship ="many-to-many") %>%
  mutate(pooled_samps=str_detect(`File Name`, pooled_sample_regex)) %>%
  mutate(norm_area=(Area/Area_IS)*mean(Area_IS), .by = c(`Compounds ID`, Name, Name_IS)) %>%
  summarise(all_cv=sd(norm_area)/mean(norm_area),
            pooled_cv=sd(norm_area[pooled_samps])/mean(norm_area[pooled_samps]),
            .by = c(`Compounds ID`, Name, Name_IS)) %>%
  arrange(`Compounds ID`, Name, pooled_cv)

IS_cvs <- all_cvs %>%
  filter(str_detect(Name, internal_standard_regex))
ggplot(IS_cvs) +
  geom_point(aes(x=pooled_cv, y=all_cv, color=Name_IS)) +
  geom_point(aes(x=pooled_cv, y=all_cv), data=subset(IS_cvs, Name_IS=="None"), 
             color="black", size=2) +
  geom_vline(aes(xintercept=pooled_cv), data=subset(IS_cvs, Name_IS=="None")) +
  geom_vline(aes(xintercept=pooled_cv*(1-min_improvement)), data=subset(IS_cvs, Name_IS=="None"), 
             linetype="dashed") +
  facet_wrap(~Name)

# If the compound has a matched IS
#   IS should be the matched IS
# If the cv is already good (i.e. normalizing to dilution volume reduces cv below already_good threshold)
#   IS should be None 
# If the CV doesn't improve by at least min_improvement
#   IS should be None
# Otherwise it's the one that improves the CV the most

all_cvs %>%
  group_by(`Compounds ID`, Name) %>%
  mutate(has_IS=ifelse(Name=="", FALSE, str_detect(Name_IS, Name))) %>%
  mutate(already_good=ifelse(pooled_cv[Name_IS=="None"]<already_good & Name_IS=="None", TRUE, FALSE)) %>%
  mutate(pooled_cv=ifelse(Name_IS=="None", pooled_cv*(1-min_improvement), pooled_cv)) %>%
  arrange(!has_IS, !already_good, pooled_cv) %>%
  slice(1)
