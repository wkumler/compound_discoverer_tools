This folder contains code used for implementing a new node in Compound Discoverer via the scripting option.
The new node builds a SQL database from the input files using the (development) 
[mzml2db package](https://github.com/wkumler/mzml2db) in R.

The repository contains two files:

1. The sql_db_builder.R script
2. The node.json file required for standalone installation in CD

## Installation

To install the SQL builder, ensure R is installed and obtain its path (typically XXX)
You will need to install the `rjson` package from CRAN, the `mzml2db` package from
Github, as well as `DBI` and whatever database driver you'd like to use.

```r
install.packages("rjson")
remotes::install_github("https://github.com/wkumler/mzml2db")
install.packages("DBI")
install.packages("RSQLite") # For a SQLite database
install.packages("duckdb")  # For a DuckDB database
```

Copy both the sql_db_builder.R script and the node.json files into a new folder in the 
Compound Discoverer Scripts directory (typically at 
C:\Program Files\Thermo\Compound Discoverer 3.4\Tools\Scripts, and not to be 
confused with C:\Program Files\Compound Discoverer 3.4 :eyeroll:). E.g.:
C:\Program Files\Thermo\Compound Discoverer 3.4\Tools\Scripts\sql_db_builder_node.

Edit the JSON file to reflect the location of your R installation `"ExecutablePath"`() and the new
location of the sql_db_builder.R script (`"ExecutableCommandLineArguments"`) in lines 17 and 18. Make sure you
keep the `%NODEARGS% %PARAMETERS%` and `\\bin\\Rscript.exe` stuff at the end of it.

```
"ExecutableCommandLineArguments": "C:\\Program Files\\Thermo\\Compound Discoverer 3.4\\Tools\\Scripts\\sql_db_builder.R %NODEARGS% %PARAMETERS%"
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