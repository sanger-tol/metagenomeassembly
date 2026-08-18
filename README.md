# sanger-tol/metagenomeassembly

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/sanger-tol-metagenomeassembly_logo_dark.svg">
  <img alt="sanger-tol/genomeassembly" src="docs/images/sanger-tol-metagenomeassembly_logo_light.svg">
</picture>

[![Open in GitHub Codespaces](https://img.shields.io/badge/Open_In_GitHub_Codespaces-black?labelColor=grey&logo=github)](https://github.com/codespaces/new/sanger-tol/metagenomeassembly)
[![GitHub Actions CI Status](https://github.com/sanger-tol/metagenomeassembly/actions/workflows/nf-test.yml/badge.svg)](https://github.com/sanger-tol/metagenomeassembly/actions/workflows/nf-test.yml)
[![GitHub Actions Linting Status](https://github.com/sanger-tol/metagenomeassembly/actions/workflows/linting.yml/badge.svg)](https://github.com/sanger-tol/metagenomeassembly/actions/workflows/linting.yml)[![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.15090769-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.15090769)
[![nf-test](https://img.shields.io/badge/unit_tests-nf--test-337ab7.svg)](https://www.nf-test.com)

[![Nextflow](https://img.shields.io/badge/version-%E2%89%A525.10.4-green?style=flat&logo=nextflow&logoColor=white&color=%230DC09D&link=https%3A%2F%2Fnextflow.io)](https://www.nextflow.io/)
[![nf-core template version](https://img.shields.io/badge/nf--core_template-4.1.0-green?style=flat&logo=nfcore&logoColor=white&color=%2324B064&link=https%3A%2F%2Fnf-co.re)](https://github.com/nf-core/tools/releases/tag/4.1.0)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Launch on Seqera Platform](https://img.shields.io/badge/Launch%20%F0%9F%9A%80-Seqera%20Platform-%234256e7)](https://cloud.seqera.io/launch?pipeline=https://github.com/sanger-tol/metagenomeassembly)

## Introduction

**sanger-tol/metagenomeassembly** is a bioinformatics pipeline for the assembly and binning of metagenomes
using PacBio HiFi data and (optionally) Hi-C Illumina data.

![sanger-tol/metagenomeassembly workflow diagram](docs/images/metagenomeassembly.metromap.svg)

## Pipeline summary

1. Assembles raw reads using [metaMDBG](https://github.com/GaetanBenoitDev/metaMDBG) or [myloasm](https://github.com/bluenote-1577/myloasm).
2. Complete circular genomes are extracted from the assembly directly.
3. Maps HiFi and (optionally) Hi-C reads to the assembly using [minimap2](https://github.com/lh3/minimap2) and [bwa-mem2](https://github.com/bwa-mem2/bwa-mem2).
4. For the remaining contigs, runs a suite of binning tools to split the genome assembly into its constituent genomes:

- [MetaBat2](https://bitbucket.org/berkeleylab/metabat/src/master/)
- [MaxBin2](https://sourceforge.net/projects/maxbin2/)
- [VAMB](https://github.com/RasmussenLab/vamb) - taxVAMB mode is also supported, with contig classifications from [centrifuger](https://github.com/mourisl/centrifuger)
- [COMEBIN](https://github.com/ziyewang/COMEBin)
- [SemiBin2](https://github.com/BigDataBiology/SemiBin)
- [Metator](https://github.com/koszullab/metaTOR/) (Hi-C binning)

5. Refines the bins using [DAS_Tool](https://github.com/cmks/DAS_Tool) and [Binette](https://github.com/genotoul-bioinfo/Binette).
6. Assesses the completeness and contamination of bins using [CheckM2](https://github.com/chklovski/CheckM2) and assesses ncRNA content using [tRNAscan-SE](https://github.com/UCSC-LoweLab/tRNAscan-SE) for tRNA and [Infernal](http://eddylab.org/infernal/)+Rfam for rRNA.
7. Assigns taxonomy to bins using [GTDB-TK](https://github.com/Ecogenomics/GTDBTk/) and converts assignments to NCBI taxonomy labels.
8. Collates information for each bin into a summary table.

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/get_started/environment_setup/overview) on how to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/get_started/run-your-first-pipeline) with `-profile test` before running the workflow on actual data.

First, prepare a YAML with your input data that looks as follows:

`input.yaml`:

```yaml
id: SampleName
pacbio:
  fasta:
    - /path/to/pacbio/file1.fasta.gz
    - /path/to/pacbio/file2.fasta.gz
    - ...
hic:
  cram:
    - /path/to/hic/hic1.cram
    - /path/to/hic/hic2.cram
    - ...
```

Now, you can run the pipeline using:

```bash
nextflow run sanger-tol/metagenomeassembly \
   -profile <docker/singularity/.../institute> \
   --input input.yaml \
   --outdir <OUTDIR>
```

> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_; see [docs](https://nf-co.re/docs/running/run-pipelines#using-parameter-files).

## Credits

sanger-tol/metagenomeassembly was originally written by Jim Downie, Will Eagles, Noah Gettle.

<!-- We thank the following people for their extensive assistance in the development of this pipeline: -->

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](docs/CONTRIBUTING.md).

## Citations

If you use sanger-tol/metagenomeassembly for your analysis, please cite it using the following doi: [10.5281/zenodo.15090769](https://doi.org/10.5281/zenodo.15090769)

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/main/LICENSE).

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
