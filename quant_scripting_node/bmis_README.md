This folder contains code used for implementing a new node in Compound Discoverer via the scripting option.
The new node performs best-matched internal standard normalization (BMIS) according to
the process detailed in [Boysen et al. (2018)](https://doi.org/10.1021/acs.analchem.7b04400).
Internal standards are picked out from the labels assigned by Compound Discoverer and
new columns are added to the Result file with the correctly normalized areas.

The repository contains two files:

1. The bmis_normalization.R script
2. The node.json file required for standalone installation in CD

## Installation

To install the BMIS normalizer, ensure R is installed and obtain its path (typically XXX)
You will need to install the `rjson` package from CRAN and the `tidyverse` packages
for data manipulation internally.

```r
install.packages("rjson")
install.packages("tidyverse")
```

Copy both the BMIS_normalization.R script and the node.json files into a new folder in the 
Compound Discoverer Scripts directory (typically at 
C:\Program Files\Thermo\Compound Discoverer 3.4\Tools\Scripts, and not to be 
confused with C:\Program Files\Compound Discoverer 3.4 :eyeroll:). E.g.:
C:\Program Files\Thermo\Compound Discoverer 3.4\Tools\Scripts\bmis_norm.

Edit the JSON file to reflect the location of your R installation `"ExecutablePath"`() and the new
location of the bmis_normalization.R script (`"ExecutableCommandLineArguments"`) in lines 17 and 18. Make sure you
keep the `%NODEARGS% %PARAMETERS%` and `\\bin\\Rscript.exe` stuff at the end of it.

```
"ExecutableCommandLineArguments": "C:\\Program Files\\Thermo\\Compound Discoverer 3.4\\Tools\\Scripts\\bmis_norm\\bmis_normalization.R %NODEARGS% %PARAMETERS%"
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

  - `Internal standard regex` determines which compounds are flagged as internal 
  standards using a regular expression in the CD-assigned compound name. Ingalls
  internal standards are all isotopically labeled and named using the compound
  name followed by a comma, space, and then either 2H, 13C or 15N (or other numeric).
  We can thus identify our internal standards with the regular expression `, \\d`
  where `\\d` stands for any number. This is passed directly to `str_detect`
  internally.
  - `Pooled sample regex` determines which compounds are flagged as internal 
  standards using a regular expression in the file name. Ingalls pooled samples
  are identified with a `_Poo_` in the sample name so this can be used to ID
  them with `str_detect`.
  - `Dilution regex` determines which samples are full strength or 1:1 diluted.
  BMIS operates on the difference in peak area between these two so correctly
  identifying which ones are diluted is critical. The parameter here should
  return either "Full" or "Half" when the file name is passed to `str_extract`
  internally.
  - `Exclude standards` is a boolean option allowing for a slightly cleaner
  output in CD. Standards in water don't have any internal standards added
  so they can't be normalized to such. This option matches against the `_Std_`
  character match in the file name if True.
  - `Minimal improvement threshold` refers to the required decrease in RSD that
  the intenal standard normalization must produce for it to be "acceptable". See
  the BMIS paper for more details (link above).
  - `Already good enough threshold` refers to the RSD below which compounds can
  be considered as already having a low enough RSD and for which normalization
  is unlikely to help. See the BMIS paper for more details (link above).

---

README last updated Jan 6th, 2026.

