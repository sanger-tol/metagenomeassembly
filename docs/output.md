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

## Assembly

Assembly of raw input HiFi reads.

### metaMDBG

[metaMDBG](https://github.com/GaetanBenoitDev/metaMDBG) is a metagenome assembler for long read (PacBio HiFi and ONT) data.

<details markdown="1">
<summary>Output files</summary>

- `assembly/`
  - `fasta/[sampleid]_metamdbg.contigs.fasta.gz`: the output assembled contigs.
  - `log/[sampleid]_metamdbg.metaMDBG.log`: log file detailing metaMDBG assembly process.

</details>

## Assembly QC

Genome assembly statistics (contig counts, length, N50, etc.) tallied using [Seqkit](https://bioinf.shenwei.me/seqkit/), as well as information on the number of circular contigs, and ribosomal RNA annotations using [Infernal](http://eddylab.org/infernal/).

<details markdown="1">
<summary>Output files</summary>

- `assembly/qc/`
  - `[sampleid]_[assembler].stats.tsv`: TSV of assembly statistics.
  - `[sampleid]_[assembler].rrna.tbl`: TSV of rRNA annotations per contig.

</details>

## Read mapping

Mapping of HiFi reads to the assembly using [minimap2](https://github.com/lh3/minimap2), and Hi-C reads to the assembly using [bwa-mem2](https://github.com/bwa-mem2/bwa-mem2). Mean coverage estimation of contigs using [CoverM](https://github.com/wwood/CoverM).

<details markdown="1">
<summary>Output files</summary>

- `assembly/mapping/`
  - `[sampleid]_[assembler].minimap2.hifi.bam`: Alignment BAM of HiFi reads to the assembly.
  - `[sampleid]_[assembler].minimap2.hifi.depth.txt`: TSV of per-contig mean coverages estimated using CoverM.
  - `[sampleid]_[assembler].bwa-mem2.hic.bam`: Alignment BAM of HiFi reads to the assembly.

</details>

## Binning

Binning of assembled contigs using [MetaBat2](https://bitbucket.org/berkeleylab/metabat/src/master/), [MaxBin2](https://sourceforge.net/projects/maxbin2/), [Bin3C](https://github.com/cerebis/bin3C) (Hi-C binning), and [Metator](https://github.com/koszullab/metaTOR/) (Hi-C binning).

<details markdown="1">
<summary>Output files</summary>

- `bins/`
  - `fasta/[binner]/*.f(n|ast)a.gz`: Bins in gzipped fasta format output by the given binner.
  - `log/[binner]/*`: Log files and other output from each binner.

</details>

## Bin refinement

Refinement of genome bins using [DAS_Tool](https://github.com/cmks/DAS_Tool) and [MagScoT](https://github.com/ikmb/MAGScoT).

<details markdown="1">
<summary>Output files</summary>

- `bins/`
  - `fasta/[binner]/*.f(n|ast)a.gz`: Bins in gzipped fasta format output by the given binner.
  - `log/[binner]/*`: Log files and other output from each binner.

## Bin QC

QC of genome bins, including summary statistics using [Seqkit](https://bioinf.shenwei.me/seqkit/), completeness/contamination assessment using [CheckM2](https://github.com/chklovski/CheckM2), rRNA identification using the assembly rRNA annotations, and tRNA annotation using [tRNAscan-SE](https://github.com/UCSC-LoweLab/tRNAscan-SE).

<details markdown="1">
<summary>Output files</summary>

- `bins/`
  - `qc/[sampleid]-[assembler]-[binner].stats.tsv`: TSV of assembly statistics.
  - `qc/[sampleid]-checkm2.tsv`: TSV of single-copy-gene checking results for all bins from CheckM2.
  - `qc/trnascan-se/[sampleid]-[assembler]-[binner]*`: Bin-level outputs of tRNAScan-SE.
  - `qc/[sampleid]-[assembler]-[binner].trnascan_summary.tsv`: Aggregated summary of tRNAScan-SE results for all bins.
  - `qc/[sampleid]-[assembler]-[binner].rrna_summary.tsv`: Counts of rRNA genes for each bin.

</details>

## Bin Taxonomy

Taxonomic classification of bins with [GTDB-TK](https://github.com/Ecogenomics/GTDBTk/) and conversion of GTDB taxonomy classifications to NCBI classifications using [TaxonKit](https://bioinf.shenwei.me/taxonkit/).

<details markdown="1">
<summary>Output files</summary>

- `bins/`
  - `taxonomy/gtdbtk.[sampleid].summary.tsv`: GTDB-Tk summary TSV with classifications for each bin.
  - `taxonomy/gtdbtk.[sampleid]_ncbi.tsv`: TSV file containing the GTDB-Tk to NCBI classification translation.
  - `taxonomy/[sampleid].gtdb_to_ncbi.tsv`: TSV file containing the GTDB-Tk to NCBI classification translation, with associated NCBI taxids.
  - `taxonomy/gtdbtk.[sampleid].classify.tree.gz`: Reference tree in Newick format containing query genomes placed with pplacer.
  - `taxonomy/gtdbtk.[sampleid].markers_summary.tsv`: A summary of unique, duplicated, and missing markers within the 120 bacterial marker set, or the 53 archaeal marker set for each submitted genome.
  - `taxonomy/gtdbtk.[sampleid].*msa.fasta.gz`: FASTA files containing MSA of submitted and reference genomes.
  - `taxonomy/gtdbtk.[sampleid].filtered.tsv`: A list of genomes with an insufficient number of amino acids in MSA.
  - `taxonomy/gtdbtk.[sampleid].failed_genomes.tsv`: TSV of genomes which failed classification by GTDB-TK.
  - `taxonomy/gtdbtk.[sampleid].log`: The console output of GTDB-Tk saved to disk.
  - `taxonomy/gtdbtk.[sampleid].warnings.log`: The verbose output of any GTDB-Tk warnings which were encountered.

</details>

## Bin summary

Summarising key information into a final table, scoring and classification of bins into quality categories according to completeness, contamination, tRNA and rRNA content.

<details markdown="1">
<summary>Output files</summary>

- `bins/`
  - `[sampleid].bin_summary.tsv`: Bin level summary with statistics, completeness/contamination checks, ncRNA content, and taxonomic classifications.
  - `[sampleid].group_summary.tsv`: Aggregated summary for each assembly:binner combination showing the counts of bins in each quality category.

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

[Nextflow](https://www.nextflow.io/docs/latest/tracing.html) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.
