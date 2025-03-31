# sanger-tol/metagenomeassembly: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.0.1 - [2025-03-31]

Post-release fix - adds Zenodo release to pipline code.

### `Added`

- Add Zenodo DOI (10.5281/zenodo.15090769) to `README.md`, `CITATION.cff` and `nextflow.config`. (by @prototaxites)
- Add pretty sanger-tol logo to `--help` output. (by @muffato)
- Fix `ci.yml` to correctly trigger on `main` rather than `master`. (by @prototaxites)
- Fix schema `$id` path in `assets/schema_input.json` (by @prototaxites)

### `Fixed`

### `Dependencies`

### `Deprecated`

## v1.0.0 - [2025-03-26]

Initial release of sanger-tol/metagenomeassembly, created with the [nf-core](https://nf-co.re/) template.

### `Added`

All added by @prototaxites, reviewed by @DLBPointon, @weaglesBio, @ksenia-krasheninnikova:

- Raw assembly of PacBio reads with metaMDBG.
- Mapping of PacBio reads to assembly with minimap2
- Estimation of contig mean coverages with coverm
- Chunked mapping of Hi-C reads to assembly with bwa-mem2
- Binning with:
  - Metabat2
  - MaxBin2
  - Bin3C (Hi-C)
  - Metator (Hi-C)
- Bin refinement with:
  - DAS_Tool
  - MagScoT
- Assembly and bin QC:
  - Seqkit stats - size, N50, etc.
  - Counts of circular contigs
  - rRNA (5S, 16S, 18S) identification and counting
- Bin QC only:
  - Assessing bin completeness and contamination with CheckM2
  - Assessing tRNA content of bins with tRNAScan-SE
- Bin taxonomic assignment:
  - GTDB-Tk for taxonomic classification
  - TaxonKit to convert GTDB-Tk taxonomic classifications to NCBI
- Per-bin and aggregated summaries

### `Fixed`

### `Dependencies`

Note, since the pipeline is using Nextflow DSL2, each process will be run with its own Biocontainer. This means that on occasion it is entirely possible for the pipeline to be using different versions of the same tool. However, the overall software dependency changes compared to the last release have been listed below for reference.

| module                                 | tools                             | old versions | new versions        |
| -------------------------------------- | --------------------------------- | ------------ | ------------------- |
| bin_rrnas                              | gawk                              | -            | 5.3.0               |
| bin_summary                            | r-base, r-tidyverse               | -            | 4.4.2, 2.0          |
| bin3c/mkmap                            | bin3c, gzip, ngzip                | -            | 0.3.3               |
| bin3c/cluster                          | bin3c, gzip, ngzip                | -            | 0.3.3, 1.9. 1.9     |
| bwamem2/index                          | bwa-mem2                          | -            | 2.2.1               |
| checkm2_predict                        | checkm2                           | -            | 1.0.2               |
| checkm2_databasedownload               | aria2                             | -            | 1.36.0              |
| contig2bintofasta                      | seqkit                            | -            | 2.9.0               |
| coverm/contig                          | coverm                            | -            | 0.7                 |
| cram_filter_bwamem2_align_fixmate_sort | staden_io_lib, samtools, bwa-mem2 | -            | 1.15.0, 1.21, 2.2.1 |
| dastool/dastool                        | dastool                           | -            | 1.1.7               |
| find_circles                           | gawk                              | -            | 5.3.0               |
| gawk                                   | gawk                              | -            | 5.3.0               |
| genome_stats                           | seqkit                            | -            | 2.9.0               |
| gtdbtk/classify_wf                     | gtdb-tk                           | -            | 2.4.0               |
| gzip_get_decompressed_size             | gzip                              | -            | 1.13                |
| hmmer/hmmsearch                        | hmmer                             | -            | 3.4                 |
| infernal/cmsearch                      | infernal                          | -            | 1.1.5               |
| magscot/magscot                        | magscot                           | -            | 1.1.0               |
| maxbin2                                | maxbin2                           | -            | 2.2.7               |
| metabat2/metabat2                      | metabat2                          | -            | 2.17                |
| metamdbg                               | metamdbg                          | -            | 1.1                 |
| metator/pipeline                       | metator                           | -            | 1.3.2               |
| metator/process_input_bam              | samtools, bioawk                  | -            | 1.21, 1.0           |
| minimap2                               | minimap2, samtools                | -            | 2.28, 1.21          |
| pyrodigal                              | pyrodigal                         | -            | 3.6.3               |
| samtools/merge_hic_bam                 | samtools                          | -            | 1.21                |
| samtools_catsort                       | samtools                          | -            | 1.21                |
| taxonkit/name2taxid                    | taxonkit                          | -            | 0.15.1              |
| trnascan_se                            | trnascan-se                       | -            | 2.0.12              |

### `Deprecated`
