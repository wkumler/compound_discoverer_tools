
## Manual mzVault

Thermo's mzVaults are mass spectral libraries designed to play nicely with
Compound Discoverer but I haven't found a trivial way to convert peak bounds
(e.g. rtmin, rtmax, mzmin, mzmax) into mzVaults so I wrote some code to do that.
Unlike the existing mzVault software, this repo allows for incredibly fine
control over how multiple scans are handled (averaged? best selected? whatever
the heck consensus means?) rather than just a single scan and can be scripted
instead of punching each scan in manually.

Inputs to the db_maker.R script are a database of rt/mz/int tuples (e.g. 
produced by mzml2db) and the rt/mz bounds of any compounds of interest. The
database then gets queried for any MS2 data within those bounds.

Unfortunately the internals of an mzVault aren't documented anywhere. They're
pretty clearly SQLite databases with a couple tables but I have no idea what
most of the parameters do so everything here should be taken with a grain of
salt and some cautious testing on your own setups.

mzVaults are just 4 tables internally:

  - CompoundTable, simply linking together IDs with Formulae and Compound Names
  - HeaderTable, which literally just contains the software(?) version (5)
  - MaintenanceTable, which is empty but probably would get filled in if using
  the software properly
  - SpectrumTable, which is the actually useful one

SpectrumTable has fields for SpectrumId that links to CompoundId (because maybe
one compound has multiple spectra) and is composed of individual scans. It
documents the retention time and scan number of each as well as the precursor 
mass, instrument name, polarity, voltage, scan type etc. The actual data is
encoded as two blobs (of course ugh) one for intensity and one for mass. Fortunately
these blobs are pretty simple and can be written with some simple code 
(unlike [other thermo blobs](https://github.com/wkumler/compound_discoverer_tools/issues/10)).

```r
blob::blob(writeBin(num_vec, raw(), size = 8, endian = "little"))
```

In the code there's a lot of ways to change how the single spectrum is written
out from multiple, like we get on the Astral. I've currently got it summarizing
things by using the top 10 most intense scans and fragments above 1% maximum 
intensity, grouping using a 10 ppm window, then requiring that the fragment
appear in at least 10% of the scans within a single file and more than zero 
files. All of these can be easily changed and I'm honestly interested in doing
some more optimization once I get the process fully streamlined. Of course, 
you can change the matching algorithm within Compound Discoverer too
to try optimizing for your own preferred spectra. Hopefully that's easier with
a programmatic tool instead of rebuilding by hand each time!

