This folder contains code for a new node in Compound Discoverer implemented via the scripting option.
The new node performs quantification according to a single-point calibration
curve estimated from a known concentration of authentic standard added to a
representative matrix. Quantified measurements are added to the Result file 
in nanomolar concentration.

The repository contains two files:

1. The quant_node_script.R script
2. The node.json file required for standalone installation in CD

## Installation

To install the quant node, ensure R is installed and obtain its path (often `C:\Program Files\R\R-X.X.X\bin\R.exe`)
You will need to install the `rjson` package from CRAN and the `tidyverse` packages
for data manipulation internally.

```r
install.packages("rjson")
install.packages("tidyverse")
```

Copy both the quant_node_script.R script and the node.json files into a new folder in the 
Compound Discoverer Scripts directory (typically at 
C:\Program Files\Thermo\Compound Discoverer 3.4\Tools\Scripts, and not to be 
confused with C:\Program Files\Compound Discoverer 3.4 :eyeroll:). E.g.:
C:\Program Files\Thermo\Compound Discoverer 3.4\Tools\Scripts\quant_node_script.R.

Edit the JSON file to reflect the location of your R installation `"ExecutablePath"`() and the new
location of the bmis_normalization.R script (`"ExecutableCommandLineArguments"`) in lines 17 and 18. Make sure you
keep the `%NODEARGS% %PARAMETERS%` and `\\bin\\Rscript.exe` stuff at the end of it.

```
"ExecutableCommandLineArguments": "C:\\Program Files\\Thermo\\Compound Discoverer 3.4\\Tools\\Scripts\\ingalls_quant\\quant_node_script.R %NODEARGS% %PARAMETERS%"
"ExecutablePath": "C:\\Program Files\\R\\R-4.5.1\\bin\\Rscript.exe"
```

In CD, run the Scan for Missing Features tool (under Help -> License Manager)
then close and reopen CD. You can check that it worked by looking at Help->About
under the Nodes list. More details 
[here](https://docs.thermofisher.com/r/Proteome-Discoverer-3.2-User-Guide/1325241867v1en-US1614263563).

The node can then be found at the bottom of the node list in the workflow builder
under the "Ingalls Lab custom nodes" section and treated like any other CD node.

## Parameters

The node takes several arguments that allow you to control how it operates.

Under "General":

  - `Standard sheet source` determines what standards can be quantified in the
  data. This should be either a local CSV file or a commit in the [Ingalls 
  Standard Sheet](https://github.com/IngallsLabUW/Ingalls_Standards/blob/master/Ingalls_Lab_Standards.csv)
  history. If left blank, it will use the most recent one which can cause issues
  if standards have been added since your samples were run. The required columns
  are Compound_Name, Column, Polarity, HILIC_Mix, and Concentration_uM.
  - `Column type` determines which standards are matched to your samples.
  Current options are HILIC, RP (reversed phase), CYANO, or C18 corresponding
  to the columns we use in the lab and therefore the entries in the Ingalls 
  Standards Sheet.
  - `Volume filtered (L)` is the amount of water that was sampled, in liters. In
  the Ingalls lab this is typically 1-2 liters for particulate and 0.04-0.06
  liters for dissolved measurements. This is used to calculate the degree to which
  samples were essentially "concentrated" by being reconstituted into a much
  smaller volume after being fully dried down.
  - `Reconstitution volume (L)` is the amount of solvent used to reconstitute
  samples after they were fully dried down during the extraction process. In
  the Ingalls lab this is typically 0.0004 (400 microliters). In combination
  with the above, this is used to calculate the degree to which
  samples were essentially "concentrated" by being reconstituted into a much
  smaller volume after being fully dried down.
  - `Dilution applied` is a general factor that can be used to alter the
  concentrations if a dilution was applied during the extraction, e.g. if the
  samples were too concentrated initially. A value of 2 will dilute them 1:1.
  - `Standard file regex` is the regular expression used to detect the files
  in which authentic standards were run. In the In the Ingalls Lab, we include
  `_Std_` in file names of the single-point standard curve so we can pass the 
  '_Std_' regular expression to str_detect to identify them. This is a value
  that should return TRUE for the standards in water, standards in matrix, and
  the water in matrix samples used for quantification when passed to 
  `str_detect` given the filename.
  - `Matrix regex` is the regular expression used to distinguish the matrix
  standards from the standards in water. This is a value that should return TRUE 
  for the standards in matrix and water in matrix samples used for 
  quantification when passed to `str_detect` given the filename. In the Ingalls
  lab, this is often "Matrix" or something similar.
  - `Raw or BMISed areas` allows for quantification on either the raw peak areas
  or those produced by the best-matched internal standard node.

---

README last updated April 29th, 2026.

