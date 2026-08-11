# sanger-tol/metagenomeassembly: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.0dev] - Polly on the Shore - [TBD]

### `Added`

- [#95](https://github.com/sanger-tol/metagenomeassembly/pull/95/) Circular contig extraction (by @prototaxites)
  - Circular contigs above a given size are now treated as complete genomes. This can be disabled by setting `--extract_circular_contigs false`.
  - The threshold for circular contig minimum size can be configured with `--minimum_circular_contig_length`
- Hi-C BAM is now converted to a pairs file, which is fed into Metator
- [#96](https://github.com/sanger-tol/metagenomeassembly/pull/96/) Add three new binners - ComeBin, SemiBin2, and VAMB.
- [#98](https://github.com/sanger-tol/metagenomeassembly/pull/96/) Allow filtering of assembled contigs by size (`--min_contig_length`, `--max_contig_length`), as well as by Tiara classification (`--tiara_exclude_classifications`) if Tiara is run (`--enable_tiara`).
- [#98](https://github.com/sanger-tol/metagenomeassembly/pull/96/) Add binning with TaxVAMB. This uses contig-level taxonomic classifications classified by Centrifuge - a centrifuge DB must be supplied to `--centrifuge_db`.
- [#98](https://github.com/sanger-tol/metagenomeassembly/pull/96/) GTDBTk updated to 2.7.2. This requires the new r232 database.
  - The `--gtdbtk_skip_ani_screen` parameter has been replaced with the `--gtdbtk_place_species` parameter.
- [#100](https://github.com/sanger-tol/metagenomeassembly/pull/100/) Added bin refinement with Binette, which can be enabled with `--enable_binette`. Binette uses the Checkm2 database, and thus the `--checkm2_db` parameter is required.

### `Fixed`

- [#95](https://github.com/sanger-tol/metagenomeassembly/pull/95/) Remove all references to `params` outside the entry subworkflow (by @prototaxites)
- [#95](https://github.com/sanger-tol/metagenomeassembly/pull/95/) tRNAscan-SE now runs once per assembly rather than for each bin. The results are aggregated as with the rRNA results (by @prototaxites)
- [#96](https://github.com/sanger-tol/metagenomeassembly/pull/96/) MaxBin2 is now disabled by default.
- [#96](https://github.com/sanger-tol/metagenomeassembly/pull/96/) The `hic: cram: enzymes:` section of the samplesheet is deprecated - please supply enzymes as an optional comma-separated list of enzymes to `--hic_enzymes`.
- [#97](https://github.com/sanger-tol/metagenomeassembly/pull/97/) Update to nf-core template version 4.0.2
  - Note that this update removes the existing Teams and Slack notification functionality. If
    you were using this functionality, please configure the
    [nf-slack](https://github.com/seqeralabs/nf-slack) or [nf-teams](https://github.com/nvnieuwk/nf-teams) Nextflow plugins.

### `Removed`

- [#95](https://github.com/sanger-tol/metagenomeassembly/pull/95/) Bin3C is now deprecated. It was not maintainable, as it depended on a container provided by the developer (by @prototaxites)
- [#100](https://github.com/sanger-tol/metagenomeassembly/pull/100/) MagScoT has been removed from the pipeline as it did not provide satisfactory results and was not compatible with Conda (by @prototaxites)

### `Dependencies`

| module                        | tools       | old versions | new versions |
| ----------------------------- | ----------- | ------------ | ------------ |
| bin3c/mkmap                   | bin3c       | 0.3.3        | -            |
| bin3c/cluster                 | bin3c       | 0.3.3        | -            |
| binette                       | binette     | -            | 1.2.1        |
| tiara/tiara                   | tiara       | -            | 1.0.3        |
| centrifuger/centrifuger       | centrifuger | -            | 1.1.1        |
| centrifuger/lineage           | centrifuger | -            | 1.1.1        |
| gtdbtk/classifywf             | gtdbtk      | 2.6.1        | 2.7.2        |
| gtdbtk/gtdbtoncbimajorityvote | gtdbtk      | 2.6.1        | 2.7.2        |
| myloasm                       | myloasm     | 0.5.1        | 0.6.0        |
| pairtools/parsefiltersort     | pairtools   | -            | 1.1.3        |
| ripgrep                       | ripgrep     | -            | 14.1.1       |

### `Deprecated`

- Removed the parameters `hmm_gtdb_tigrfam` and `hmm_gtdb_pfam`, as MagScoT has been removed.

## [1.4.0] - Lovely Molly - [2025-04-27]

### `Added`

- Added [myloasm](https://myloasm-docs.github.io/) as an alternative assembler - supply `--assembler myloasm` to select it.
- Added a pipeline logo.

### `Fixed`

- Updated metaMDBG to 1.3.1, improving the quality of output assemblies.

### `Dependencies`

| module            | tools    | old versions | new versions |
| ----------------- | -------- | ------------ | ------------ |
| metamdbg          | metamdbg | 1.2.0        | 1.3.1        |
| myloasm           | myloasm  | -            | 0.5.1        |
| gtdbtk/classifywf | gtdbtk   | 2.5.2        | 2.6.1        |

## [1.3.2] - Glasgow Peggie (patch 2) - [2025-03-31]

### `Added`

- Pipeline now supports input of fastq files for long reads.

### `Fixed`

- Move pipeline code to Nextflow strict syntax

### `Deprecated`

### `Dependencies`

| module           | tools   | old versions | new versions |
| ---------------- | ------- | ------------ | ------------ |
| genomad/endtoend | genomad | 1.11.0       | 1.11.2       |

## [1.3.1] - Glasgow Peggie (patch 1) - [2025-11-29]

### `Fixed`

- Correctly emit the versions from the FASTX_MAP_LONG_READS subworkflow. (by @prototaxites)

## [1.3.0] - Glasgow Peggie - [2025-11-28]

### `Added`

- Switch the read mapping and Hi-C mapping to use the new sanger-tol subworkflows. (by @prototaxites)
- gunzip all assemblies and operate on assemblies in decompressed space internally. (by @prototaxites)
- Operate on decompressed assemblies downstream to avoid lack of bgzipping. (by @prototaxites)

### `Fixed`

- Sometimes MAGScoT fails, for unknown reasons. The pipeline will no longer exit if this happens. (by @prototaxites)
- If no circular contigs are found, a FASTA file will no longer be written and GeNomad will no longer run (and fail). (by @prototaxites)
- Change the minimum percent identity during read mapping to 99% to reflect accuracy of PacBio reads. (by @prototaxites)

### `Deprecated`

- Removed the parameter `params.hic_mapping_merge_mode`, as we now use the new Hi-C mapping subworkflow. (by @prototaxites)
- Removed the parameter `params.enable_assembly` - assembly now always runs by default unless an assembly is provided. (by @prototaxites)

### `Dependencies`

| module                     | tools    | old versions | new versions |
| -------------------------- | -------- | ------------ | ------------ |
| gunzip                     | gzip     | -            | 1.13         |
| gzip_get_decompressed_size | gzip     | 1.13         | -            |
| fastxalign/pyfastxindex    | pyfastx  | -            | 2.2.0        |
| fastxalign/minimap2align   | pyfastx  | -            | 2.2.0        |
| fastxalign/minimap2align   | minimap2 | -            | 2.30         |
| fastxalign/minimap2align   | samtools | -            | 1.22.1       |
| cramalign/gencramchunks    | -        | -            | 1.1.0        |
| cramalign/bwamem2align     | bwa-mem2 | -            | 1.22.1       |
| cramalign/bwamem2align     | samtools | -            | 1.22.1       |
| cramalign/minimap2align    | minimap2 | -            | 2.30         |
| cramalign/minimap2align    | samtools | -            | 1.22.1       |
| minimap2/align             | minimap2 | 2.2.9        | -            |
| minimap2/align             | samtools | 1.21         | -            |
| samtools/sort              | samtools | -            | 1.22.1       |
| samtools/mergedup          | samtools | -            | 1.22.1       |
| samtools/faidx             | samtools | -            | 1.22.1       |
| samtools/splitheader       | samtools | -            | 1.22.1       |

## [1.2.1] - Fair Margaret and Sweet William (patch 1) - [2025-10-24]

### `Added`

### `Fixed`

- tRNAScan-SE summary now correctly calculates the total number of tRNA hits (by @prototaxites)

### `Deprecated`

### `Dependencies`

## [1.2.0] - Fair Margaret and Sweet William - [2025-09-23]

### `Added`

- Pipeline-level nf-test implemented - update to template 3.3.2 (by @prototaxites)
- GTDB-Tk updates:
  - Update GTDB-Tk to 2.5.2 to fix conda env issues (by @prototaxites)
  - Remove patch from gtdbtk/classifywf module and switch to the new gtdbtk/gtdbtoncbimajorityvote module to convert to NCBI taxonomy (by @prototaxites)
  - Added `gtdbtk_use_full_tree` parameter. This is enabled in the nf-test tests to allow use of the mock DB, but if enabled using the full GTDB-Tk
    db, all bacterial bins will be placed into the full bacterial tree. This requires >=320 GB of memory (by @prototaxites)
  - Added `gtdbtk_skip_ani_screen` parameter. This is also enabled in the nf-test tests to allow use of the mock DB. Skips running the ANI pre-screen step using skani for classification without using marker genes (by @prototaxites)
  - Join NCBI classifications to GTDB-Tk summary and output this file instead (by @prototaxites)
  - GTDB classification method included in bin summary (by @prototaxites)
- Return free-disk-space to nf-test CI runners (by @prototaxites)
- Emit all contig2bin files in the output directory (by @prototaxites)
- Include filename in bin_summary.tsv results file (by @prototaxites)
- Add extra output TSV file with per-contig information (length, GC, circularity) (by @prototaxites)
- Use nf-core infernal/cmsearch module (by @prototaxites)
- Estimate bin coverage with coverm/genome (by @prototaxites)
- (Sanger internal use) - add a Tree of Life Assembly profile to configure access to databases (by @prototaxites)

### `Fixed`

- Fixed bug where Metator bin FASTA files were not being published (by @prototaxites)
- Fixed bug where bin3C bins were not being passed to GTDB-Tk due to a silently failing join (by @prototaxites)
- Fixed bug where coverm contig depths were not being published (by @prototaxites)
- Ensure contig2bins are always tab-separated and have tsv ending (by @prototaxites)
- Updated all out-of-date nf-core modules (by @prototaxites)
- Relax Nextflow version dependency after bugfix (by @prototaxites)
- Fixed bug where the BIN_SUMMARY process would run if binning was disabled (by @prototaxites)

### `Deprecated`

- Removed the code that automatically downloads the CheckM2 and Genomad databases if they are not provided, as these can now
  be specified for download in the nf-test setup block and are thus not required (by @prototaxites)
- Removed TaxonKit - the code for generating submittable taxnames/taxids did not work well (by @prototaxites)
- Removed `enable_summary` parameter (by @prototaxites)
- Removed `ncbi_taxonomy_dir` parameter (by @prototaxites)
- Removed `gtdbtk_mash_db` parameter as it is now deprecated (by @prototaxites)

### `Dependencies`

| module                        | tools                        | old versions | new versions |
| ----------------------------- | ---------------------------- | ------------ | ------------ |
| metamdbg/asm                  | metamdbg                     | 1.1          | 1.2          |
| gtdbtk/classifywf             | gtdbtk                       | 2.4.0        | 2.5.2        |
| gtdbtk/gtdbtoncbimajorityvote | gtdbtk_to_ncbi_majority_vote | -            | 0.2.1        |
| minimap2/align                | minimap2                     | 2.28         | 2.29         |
| minimap2/align                | samtools                     | 1.20         | 1.21         |
| taxonkit/name2taxid           | taxonkit                     | 0.15.1       | -            |
| samtools/merge                | samtools                     | 1.21         | 1.22.1       |
| samtools/index                | samtools                     | 1.21         | 1.22.1       |
| nextflow                      | nextflow                     | 25.04.02     | 24.04.02     |

## [1.1.1] - The Elfin Knight (patch 1) - [2025-06-02]

### `Fixed`

- Fixed bug where single-file inputs to metaMDBG caused a file-not-found error (by @prototaxites)
- Upgrade Metator to avoid bug in Conda

### `Dependencies`

| module           | tools    | old versions | new versions |
| ---------------- | -------- | ------------ | ------------ |
| metator/pipeline | metator  | 1.3.7        | 1.3.10       |
| nextflow         | nextflow | 24.04.02     | 25.04.02     |

## [1.1.0] - The Elfin Knight - [2025-04-14]

### `Added`

- Adds genomad for classification of circular contigs to determine whether they are plasmids (by @prototaxites)
  - adds `--enable_genomad` to turn on and off this step (enabled by default)
  - adds `--genomad_splits` to control memory usage - increasing this value from the default 1 increases
    chunking of the genomad database, reducing memory usage at the cost of increased runtime

### `Fixed`

- Fixed missing output channel in gtdbtk/classifywf (by @prototaxites)
- Add in some previously-excluded parts of the template (by @prototaxites)

### `Dependencies`

| module           | tools                | old versions | new versions          |
| ---------------- | -------------------- | ------------ | --------------------- |
| find_circles     | seqkit,samtools,gawk | 2.9.0, -, -  | 2.10.0, 1.21.0, 5.3.0 |
| genomad/download | genomad              | -            | 1.11.0                |
| genomad/endtoend | genomad              | -            | 1.11.0                |

### `Deprecated`

## ## [[1.0.3](https://github.com/sanger-tol/metagenomeassembly/releases/tag/1.0.3)] - Scarborough Fair (patch 3) - [2025-04-08]

- Relicensed this repository as MIT
- Updated the GTDB-Tk container to a sanger-tol container that has both GTDB-Tk and the `gtdb_to_ncbi_majority_vote.py` script (by @prototaxites)
- Minor change to GTDB database channel preparation to reflect new changes to the nf-core module (by @prototaxites)

## ## [[1.0.2](https://github.com/sanger-tol/metagenomeassembly/releases/tag/1.0.2)] - Scarborough Fair (patch 2) - [2025-04-08]

Post-release fix - the actual license at this stage is GPL-3.0.
v1.0.0 and v1.0.1 should be considered GPL-3.0 as well, despite the wrong LICENSE file.

## ## [[1.0.1](https://github.com/sanger-tol/metagenomeassembly/releases/tag/1.0.1)] - Scarborough Fair (patch 1) - [2025-03-31]

Post-release fix - adds Zenodo release to pipline code.

### `Added`

- Add Zenodo DOI (10.5281/zenodo.15090769) to `README.md`, `CITATION.cff` and `nextflow.config` (by @prototaxites)
- Add pretty sanger-tol logo to `--help` output (by @muffato)

### `Fixed`

- Fix `ci.yml` to correctly trigger on `main` rather than `master` (by @prototaxites)
- Fix schema `$id` path in `assets/schema_input.json` (by @prototaxites)
- Conda fixes:
  - Add missing environment.yml reference to cram_filter_bwamem2_align_fixmate_sort (by @prototaxites)
  - Add explicit catch in binning subworkflow to only run Bin3C and MagScoT if conda is not enabled (by @prototaxites)
  - Update metator to ensure conda works correctly (by @prototaxites)

### `Dependencies`

| module           | tools   | old versions | new versions |
| ---------------- | ------- | ------------ | ------------ |
| metator/pipeline | metator | 1.3.2        | 1.3.7        |

### `Deprecated`

## [[1.0.0](https://github.com/sanger-tol/metagenomeassembly/releases/tag/1.0.0)] - Scarborough Fair - [2025-03-26]

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
