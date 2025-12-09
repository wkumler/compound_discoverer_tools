This folder contains code used for implementing a new node in Compound Discoverer via the scripting option.
The new node builds a SQL database from the input files using the (development) 
[mzml2db package](https://github.com/wkumler/mzml2db) in R.

The repository contains two files:

1. The sql_db_builder.R script
2. The node.json file required for standalone installation in CD

## Installation

To install the SQL builder, ensure R is installed and obtain its path (typically XXX)
You will need to install the `rjson` package from CRAN, the `mzml2db` package from
Github, as well as `DBI` and whatever database driver you'd like to use. Right
now only DuckDB and SQLite are supported.

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

Under "General":

  - `Archive Datafiles` exports the files used by Compound Discoverer during this node's operation
  (i.e. the Input Files table). Required by CD but not super useful imo.
  - `Database type` determines which kind of database is written out. The two supported ones
  at the moment are DuckDB and SQLite. These are driven by the associated R packages
  `duckdb` and `RSQLite` which must be installed to export the files properly.
  - `Output database pathname` controls where the database is written. The full path is required 
  including the database name at the end of it (e.g. 'C:/Users/Will/Desktop/msdata.duckdb')
  because CD launches R from an awkward spot and controlling the working directory can be difficult.
  Single quotes are required if the path name has spaces in it and are a good idea otherwise as well.
  - `MS levels` determine which MS levels are processed. These are parsed by `msconvert` so their 
  ["int-set"](https://proteowizard.sourceforge.io/tools/msconvert.html)
  syntax applies. The default setting processes all MS levels and writes them to disk.
  - `Sort by` controls whether the data written into the database is sorted first. This can massively
  improve DuckDB's performance but has minimal affect on SQLite.
  - `Database file subset` because sometimes the entire dataset doesn't need to be written into
  the database. This parameter accepts any regex string and passes it along to `grepl`. The default
  setting parses all of the files. The regex is run on the full path name so you can include the
  names of directories containing the raw data as well as the filename itself. For example, if you
  had authentic standards that all had "Std" in the name you could use `Std` as the argument here
  and only files with "Std" somewhere in the name would be written to the database.

Under "Advanced":

  - `Centroid?`
  - `msconvert path`
  - `Intermediate mzML write path`
  - `Remove mzMLs?`

