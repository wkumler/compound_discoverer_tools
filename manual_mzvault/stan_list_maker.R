
library(tidyverse)
library(RaMS)
ms1_files <- list.files(r"(Z:\1_QEdata\2025\250625_ExtractionTests_Phytos_POS-NEG\pos_ms1)",
                        full.names = TRUE, pattern="Std.*Mix\\dInH2O")
ms1_data <- grabMSdata(ms1_files)


ms1_data$MS1[mz%between%pmppm(118.0862, 10)] %>%
  slice_max(int, by=c(rt, filename)) %>%
  qplotMS1data(color_col="filename") +
  theme(legend.position = "none")
plotly::ggplotly()


rt_bounds <- tribble(
  ~Compound_Name, ~rtmin, ~rtmax,
  "Sarcosine", 10.25, 10.85,
  "L-Alanine",10.85, 11.61,
  "beta-Alanine", 11.61, 12.2,
  "Adenine", 4.5, 5.3,
  "Guanine", 8.3, 9.1,
  "L-Arginine", 17.6, 18.7,
  "Glycine betaine", 7.1, 7.9,
  "L-Valine", 8.4, 9
)

stan_list <- read_csv("https://github.com/IngallsLabUW/Ingalls_Standards/raw/refs/heads/master/Ingalls_Lab_Standards.csv") %>%
  filter(z>0) %>%
  filter(Column=="HILIC") %>%
  select(Compound_Name, mz, HILIC_Mix, Empirical_Formula) %>%
  left_join(rt_bounds)

write_csv(stan_list, "manual_mzvault/stan_list.csv")

