# compound_discoverer_tools
Some tools and workflow extensions for Thermo's Compound Discoverer (CD).

Currently included tools are:

## manual_mzvault
  Allows for building an mzVault from scratch (e.g. a CSV of fragments and intensities)
  with a lot of fine control over how the SQLite database is built. The resulting mzVault
  can then be queried from CD during a normal run after being added to Spectral Databases.

## duckdb_scripting_node
  An extension to Compound Discoverer that allows for the construction of a
  DuckDB or SQLite database containing the raw data (filename, rt, m/z, and intensity)
  in the raw files. Currently uses msconvert to build the mzMLs and then
  mzml2db to convert them into a database.

## bmis_scripting_node
  An extension to Compound Discoverer that performs best-matched internal
  standard normalization on the compounds per Boysen et al. (2018). Returns
  the usual Compounds table with additional columns for the name of the chosen 
  BMIS and the normalized areas.

## quant_scripting_node (planned)
  An extension to Compound Discoverer that performs quantification using a
  single-point calibration curve as is the norm for the Ingalls Lab.

