# sanger-tol/metagenomeassembly: Output

## Introduction

This document describes the output produced by the pipeline.

The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory.

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/) and processes data using the following steps:

- [Assembly](#assembly) - Metagenomic assembly of raw PacBio HiFi reads.
- [Assembly QC](#assembly-qc) - QC of metagenome assemblies including statistics and rRNA identification.
- [Read mapping](#read-mapping) - Mapping of PacBio HiFi reads and Illumina Hi-C reads to the assembly for coverage estimation and contact map generation.
- [Binning](#binning) - Binning of total metagenome assemblies into genome bins.
- [Bin refinement](#bin-refinement) - Refining of genome bins by assessing single-copy gene content.
- [Bin QC](#bin-refinement) - QC of genome bins including basic statistics, rRNA content assessment, and tRNA annotation.
- [Bin taxonomy](#bin-taxonomy) - Taxonomic classification of bins with GTDB-Tk and conversion of these classifications to NCBI names.
- [Pipeline summary](#pipeline-summary) - Summarising key information into a final table, scoring and classification of bins into quality categories according to completeness, contamination, tRNA and rRNA content.
- [Pipeline information](#pipeline-information) - Report metrics generated during the workflow execution.

## Output directory structure

If a single sample is assembled, the specified output directory will contain the results for that single sample. However, if multiple samples are assembled, the output directory will contain a subdirectory for each sample, named according to the sample ID specified in the input samplesheet. Each sample subdirectory will contain the same structure as described below.

## Assembly

Assembly of raw input reads using a long-read assembler, either [metaMDBG](https://github.com/GaetanBenoitDev/metaMDBG) or myloasm [myloasm](https://github.com/bluenote-1577/myloasm/).

<details markdown="1">
<summary>Output files</summary>

- `assembly/`
  - `[sampleid].contigs.fasta.gz`: If metaMDBG is used as the assembler, the output contigs.
  - `[sampleid].assembly_primary.fa.gz`: If myloasm is used as the assembler, the output contigs.
  - `metamdbg/[sampleid].metaMDBG.log`: log file detailing metaMDBG assembly process.
  - `myloasm/`: full output of myloasm, including assembly graphs.

</details>

## Assembly analyis

Analyses on the primary genome assembly, including basic statistics ([GFAStats](<>)), ncRNA annotation ([tRNAScan-SE](https://github.com/UCSC-LoweLab/tRNAscan-SE), [Infernal for rRNA genes](https://eddylab.org/infernal/)), [Genomad](https://github.com/apcamargo/genomad/) classification of contigs as plasmids or viruses, and [Tiara](https://github.com/ibe-uw/tiara) domain classifications of contigs.

<details markdown="1">
<summary>Output files</summary>

- `assembly/`
  - `[sampleid].{contigs,assembly_primary}.{fasta,fa}.assembly_summary`: GFAStats ssummary of assembly
  - `trnascanse/[sampleid].trna,{gff,log,stats,tsv}`: outputs of tRNAScan-SE including a GFF of tRNA annotations.
  - `rrna/[sampleid].gff`: GFF file of rRNA annotations
  - `genomad/[sampleid]/`: Outputs from Genomad
  - `tiara/[sampleid].txt`: Tiara domain classifications by contig
  - `tiara/log_[sampleid].txt`: Tiara classification log file

</details>

## Read mapping

Mapping of long reads to the assembly using [minimap2](https://github.com/lh3/minimap2), and Hi-C reads to the assembly using [bwa-mem2](https://github.com/bwa-mem2/bwa-mem2). Mean coverage estimation of contigs using [CoverM](https://github.com/wwood/CoverM). BAM files are only published if `--save_bam` is set.

<details markdown="1">
<summary>Output files</summary>

- `assembly/mapping/`
  - `[sampleid].[readid].[sequencing_platform].bam`: Alignment BAM of reads from sample [readid] to assembly [sampleid].
  - `[sampleid].all.depth.tsv`: TSV of per-contig mean coverages estimated using CoverM.
  - `[sampleid].hic.bam`: Alignment BAM of HiFi reads to the assembly.

</details>

## Binning

Binning of assembled contigs using [MetaBat2](https://bitbucket.org/berkeleylab/metabat/src/master/), [MaxBin2](https://sourceforge.net/projects/maxbin2/), and [Metator](https://github.com/koszullab/metaTOR/) (Hi-C binning).

<details markdown="1">
<summary>Output files</summary>

- `binning/bins/`
  - `[binner]/fasta/[sampleid].[binner]_{n}.*.fa.gz`: Bins in gzipped fasta format output by the given binner.
  - `[binner]/*`: Log files and other output from each binner.

</details>

## Bin refinement

Refinement of genome bins using [DAS_Tool](https://github.com/cmks/DAS_Tool) and [Binette](https://github.com/genotoul-bioinfo/Binette).

<details markdown="1">
<summary>Output files</summary>

- `binning/bins/`
  - `[binner]/fasta/[sampleid].[binner]_{n}.*.fa.gz`: Bins in gzipped fasta format output by the given binner.
  - `[binner]/*`: Log files and other output from each binner.

## Bin QC

QC of genome bins, including summary statistics using [Seqkit](https://bioinf.shenwei.me/seqkit/), completeness/contamination assessment using [CheckM2](https://github.com/chklovski/CheckM2), rRNA identification using the assembly rRNA annotations, and tRNA annotation using [tRNAscan-SE](https://github.com/UCSC-LoweLab/tRNAscan-SE).

<details markdown="1">
<summary>Output files</summary>

- `binning/`
  - `[sampleid]_checkm2_report.tsv`: TSV of single-copy-gene checking results for all bins from CheckM2.
  - `[sampleid].coverm.genome.tsv`: TSV of mean coverage of each bin in each sample.

</details>

## Bin Taxonomy

Taxonomic classification of bins with [GTDB-TK](https://github.com/Ecogenomics/GTDBTk/) and conversion of GTDB taxonomy classifications to NCBI classifications using [TaxonKit](https://bioinf.shenwei.me/taxonkit/).

<details markdown="1">
<summary>Output files</summary>

- `binning/`
  - `gtdbtk/[sampleid]/[sampleid].summary.tsv`: GTDB-Tk summary TSV with classifications for each bin.
  - `gtdbtk/[sampleid]/[sampleid]_ncbi.tsv`: TSV file containing the GTDB-Tk to NCBI classification translation.
  - `gtdbtk/[sampleid]/[sampleid].classify.tree.gz`: Reference tree in Newick format containing query genomes placed with pplacer.
  - `gtdbtk/[sampleid]/[sampleid].markers_summary.tsv`: A summary of unique, duplicated, and missing markers within the 120 bacterial marker set, or the 53 archaeal marker set for each submitted genome.
  - `gtdbtk/[sampleid]/[sampleid].*msa.fasta.gz`: FASTA files containing MSA of submitted and reference genomes.
  - `gtdbtk/[sampleid]/[sampleid].filtered.tsv`: A list of genomes with an insufficient number of amino acids in MSA.
  - `gtdbtk/[sampleid]/[sampleid].failed_genomes.tsv`: TSV of genomes which failed classification by GTDB-TK.
  - `gtdbtk/[sampleid]/[sampleid].log`: The console output of GTDB-Tk saved to disk.
  - `gtdbtk/[sampleid]/[sampleid].warnings.log`: The verbose output of any GTDB-Tk warnings which were encountered.
  - `[sampleid].gtdb_summary.csv`: Combined summary from GTDB-Tk (archaea and bacteria) with added NCBI classifications.

</details>

## Bin summary

Summarising key information into a final table, scoring and classification of bins into quality categories according to completeness, contamination, tRNA and rRNA content.

<details markdown="1">
<summary>Output files</summary>

- `bins/`
  - `[sampleid].bins_summary.tsv`: Bin level summary with statistics, completeness/contamination checks, ncRNA content, and taxonomic classifications.
  - `[sampleid].groups_summary.tsv`: Aggregated summary for each assembly:binner combination showing the counts of bins in each MiMAG quality category.

</details>

## Pipeline information

<details markdown="1">
<summary>Output files</summary>

- `pipeline_info/`
  - Reports generated by Nextflow: `execution_report.html`, `execution_timeline.html`, `execution_trace.txt` and `pipeline_dag.dot`/`pipeline_dag.svg`.
  - Reports generated by the pipeline: `pipeline_report.html`, `pipeline_report.txt` and `software_versions.yml`. The `pipeline_report*` files will only be present if the `--email` / `--email_on_fail` parameter's are used when running the pipeline.
  - Reformatted samplesheet files used as input to the pipeline: `samplesheet.valid.csv`.
  - Parameters used by the pipeline run: `params.json`.

</details>

[Nextflow](https://docs.seqera.io/platform-cloud/reports/overview) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.
