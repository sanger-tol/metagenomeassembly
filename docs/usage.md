# sanger-tol/metagenomeassembly: Usage

> _Documentation of pipeline parameters is generated automatically from the pipeline schema and can no longer be found in markdown files._

## Introduction

`sanger-tol/metagenomeassembly` is a pipeline for the assembly and binning of metagenomic long reads. Input to the pipeline is passed via the `--input` parameter, which takes a YAML or JSON file that describes the samples and their data for processing.

```bash
--input '[path to samplesheet file]'
```

### Full samplesheet

Each sample is represented in a separate list element in the input file. The ID field identifies the sample, and the platform field specifies the sequencing technology used to generate the reads, and can be one of `pacbio_hifi`, `oxford_nanopore`, or `illumina_hic`. The reads field is a list of paths to the read files for that sample. Illumina Hi-C data must be provided in unaligned CRAM format - see below for details if you have FASTQ files.

Sample IDs must be unique for PacBio and ONT entries; IDs for Illumina Hi-C data must match a PacBio or ONT sample ID to be used for Hi-C binning.

```yaml title="input.yaml"
- id: SampleName1
  platform: pacbio_hifi
  reads:
    - /path/to/pacbio/file1.fasta.gz
    - /path/to/pacbio/file2.fasta.gz
- id: SampleName1
  platform: illumina_hic
  reads:
    - /path/to/pacbio/file1.fasta.gz
    - /path/to/pacbio/file2.fasta.gz
- id: SampleName2
  platform: oxford_nanopore
  reads:
    - /path/to/pacbio/file1.fastq.gz
    - /path/to/pacbio/file2.fastq.gz
```

If you have one, it is possible to provide a pre-computed assembly for a sample to skip the assembly stage. Simply add the `assembly` and `assembler` fields as follows:

```yaml
- id: SampleName1
  platform: pacbio_hifi
  reads:
    - /path/to/pacbio/file1.fasta.gz
    - /path/to/pacbio/file2.fasta.gz
  assembly: /path/to/contigs.fasta.gz
  assembler: metamdbg
```

Note that some assembler-specific features of the pipeline (such as identification of circular contigs) may not operate if providing contigs from an unsupported assembler.

An [example samplesheet](../assets/example_input.yaml) has been provided with the pipeline.

## Tuning the pipeline

### Required databases

The pipeline requires a number of databases to be provided for a full run.

- [CheckM2](https://zenodo.org/records/14897628) - required to assess bin completeness and contamination. Supply the extracted `.dmnd` file to the parameter `--checkm2_db`.
- [GTDB-Tk](https://data.gtdb.aau.ecogenomic.org/releases/latest/auxillary_files/gtdbtk_package/full_package/) - required for taxonomic classification of bins. Supply the extracted directory to the parmater `--gtdbtk_db`.
- [Genomad](https://zenodo.org/records/14886553) - required for plasmid detection. Supply the extracted directory to the parameter `--genomad_db`.
- [Centrifuger](https://github.com/mourisl/centrifuger) - for binning with TaxVamb, you will need to supply a Centrifuger DB (`.cfg` file) to the parameter `--centrifuger_db`. These can be downloaded with the `centrifuger-download` command from the Centrifuger repository.

### Filtering the assemblies

Each produced assembly can be filtered prior to binning. Specifically, contigs can be length-filtered with the following parameters: `--minimum_contig_size` and `--maximum_contig_size`. Contigs outside of this range will be removed from the assembly prior to binning. Contigs can also be filtered by domain classification from Tiara, such as to remove all Eukaryotic contigs. To do this, supply a comma-separated list of tiara domains (`eukarya`,`prokarya`,`bacteria`,`archaea`,`organelle`, and `unknown`) to `--tiara_exclude_classifications`.

### Selecting binners

The pipeline also includes a large array of binning methods, not all of which may be desirable to run. The parameters to control which binning methods are run are as follows:

- `--extract_circular_contigs` - Extract circular genomes from the assembly prior to binning as individual genomes.
- `--enable_metabat2` - Enable binning with MetaBAT2.
- `--enable_maxbin2` - Enable binning with MaxBin2.
- `--enable_comebin` - Enable binning with ComeBIN.
- `--enable_semibin2` - Enable binning with SemiBin2.
- `--enable_vamb` - Enable binning with VAMB.
- `--enable_taxvamb` - Enable binning with TaxVAMB. Requires a Centrifuger DB to be provided via `--centrifuger_db`.
- `--enable_metator` - Enable binning with MetaTOR. Requires Hi-C data for at least one sample to be provided.

If multiple samples are provided, the pipeline can also be run in "multisplit mode" via `--enable_multisplit`. In this case, if binning with VAMB or SemiBin2, all assemblies are concatenated and reads from all samples are mapped to the concatenated assembly. The concatenated assembly is then binned and the bins are separated back into their respective samples.

The pipeline also includes two approaches for ensemble bin refinement:

`--enable_dastool` - Enable bin refinement with DASTool. Requires at least two binning methods to be enabled.
`--enable_binette` - Enable bin refinement with Binette. Requires at least two binning methods to be enabled.

## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run sanger-tol/metagenomeassembly --input ./input.yaml --outdir ./results  -profile docker
```

This will launch the pipeline with the `docker` configuration profile. See below for more information about profiles.

Note that the pipeline will create the following files in your working directory:

```bash
work                # Directory containing the nextflow working files
<OUTDIR>            # Finished results in specified location (defined with --outdir)
.nextflow_log       # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

If you wish to repeatedly use the same parameters for multiple runs, rather than specifying each flag in the command, you can specify these in a params file.

Pipeline settings can be provided in a `yaml` or `json` file via `-params-file <file>`.

> [!WARNING]
> Do not use `-c <file>` to specify parameters as this will result in errors. Custom config files specified with `-c` must only be used for [tuning process resource specifications](https://nf-co.re/docs/running/run-pipelines#configuring-pipelines), other infrastructural tweaks (such as output directories), or module arguments (args).

The above pipeline run specified with a params file in yaml format:

```bash
nextflow run sanger-tol/metagenomeassembly -profile docker -params-file params.yaml
```

with:

```yaml title="params.yaml"
input: './samplesheet.csv'
outdir: './results/'
<...>
```

You can also generate such `YAML`/`JSON` files via [nf-core/launch](https://nf-co.re/launch).

## Additional setup procedures

### CRAM files for Hi-C and Illumina input data

Hi-C input data must currently be provided in unaligned CRAM format. If you have reads in FASTQ format, you can convert these to CRAM with the following command:

```bash
samtools import -@8 -r ID:{prefix} -r CN:{hic-kit} -r PU:{prefix} -r SM:{sample_name} {prefix}_R1.fastq.gz {prefix}_R2.fastq.gz -o {prefix}.cram
```

### Updating the pipeline

When you run the above command, Nextflow automatically pulls the pipeline code from GitHub and stores it as a cached version. When running the pipeline after this, it will always use the cached version if available - even if the pipeline has been updated since. To make sure that you're running the latest version of the pipeline, make sure that you regularly update the cached version of the pipeline:

```bash
nextflow pull sanger-tol/metagenomeassembly
```

### Reproducibility

It is a good idea to specify the pipeline version when running the pipeline on your data. This ensures that a specific version of the pipeline code and software are used when you run your pipeline. If you keep using the same tag, you'll be running the same version of the pipeline, even if there have been changes to the code since.

First, go to the [sanger-tol/metagenomeassembly releases page](https://github.com/sanger-tol/metagenomeassembly/releases) and find the latest pipeline version - numeric only (eg. `1.3.1`). Then specify this when running the pipeline with `-r` (one hyphen) - eg. `-r 1.3.1`. Of course, you can switch to another version by changing the number after the `-r` flag.

This version number will be logged in reports when you run the pipeline, so that you'll know what you used when you look back in the future.

To further assist in reproducibility, you can use share and reuse [parameter files](#running-the-pipeline) to repeat pipeline runs with the same settings without having to write out a command with every single parameter.

> [!TIP]
> If you wish to share such profile (such as upload as supplementary material for academic publications), make sure to NOT include cluster specific paths to files, nor institutional specific profiles.

## Core Nextflow arguments

> [!NOTE]
> These options are part of Nextflow and use a _single_ hyphen (pipeline parameters use a double-hyphen)

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments.

Several generic profiles are bundled with the pipeline which instruct the pipeline to use software packaged using different methods (Docker, Singularity, Podman, Shifter, Charliecloud, Apptainer, Conda) - see below.

> [!IMPORTANT]
> We highly recommend the use of Docker or Singularity containers for full pipeline reproducibility, however when this is not possible, Conda is also supported.

The pipeline also dynamically loads configurations from [https://github.com/nf-core/configs](https://github.com/nf-core/configs) when it runs, making multiple config profiles for various institutional clusters available at run time. For more information and to check if your system is supported, please see the [nf-core/configs documentation](https://github.com/nf-core/configs#documentation).

Note that multiple profiles can be loaded, for example: `-profile test,docker` - the order of arguments is important!
They are loaded in sequence, so later profiles can overwrite earlier profiles.

If `-profile` is not specified, the pipeline will run locally and expect all software to be installed and available on the `PATH`. This is _not_ recommended, since it can lead to different results on different machines dependent on the computer environment.

- `test`
  - A profile with a complete configuration for automated testing
  - Includes links to test data so needs no other parameters
- `docker`
  - A generic configuration profile to be used with [Docker](https://docker.com/)
- `singularity`
  - A generic configuration profile to be used with [Singularity](https://sylabs.io/docs/)
- `podman`
  - A generic configuration profile to be used with [Podman](https://podman.io/)
- `shifter`
  - A generic configuration profile to be used with [Shifter](https://nersc.gitlab.io/development/shifter/how-to-use/)
- `charliecloud`
  - A generic configuration profile to be used with [Charliecloud](https://charliecloud.io/)
- `apptainer`
  - A generic configuration profile to be used with [Apptainer](https://apptainer.org/)
- `wave`
  - A generic configuration profile to enable [Wave](https://seqera.io/wave/) containers. Use together with one of the above (requires Nextflow `24.03.0-edge` or later).
- `conda`
  - A generic configuration profile to be used with [Conda](https://conda.io/docs/). Please only use Conda as a last resort i.e. when it's not possible to run the pipeline with Docker, Singularity, Podman, Shifter, Charliecloud, or Apptainer.

### `-resume`

Specify this when restarting a pipeline. Nextflow will use cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously. For input to be considered the same, not only the names must be identical but the files' contents as well. For more info about this parameter, see [this blog post](https://www.nextflow.io/blog/2019/demystifying-nextflow-resume.html).

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

### `-c`

Specify the path to a specific config file (this is a core Nextflow command). See the [nf-core website documentation](https://nf-co.re/usage/configuration) for more information.

## Custom configuration

### Resource requests

Whilst the default requirements set within the pipeline will hopefully work for most people and with most input data, you may find that you want to customise the compute resources that the pipeline requests. Each step in the pipeline has a default set of requirements for number of CPUs, memory and time. For most of the pipeline steps, if the job exits with any of the error codes specified [here](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/conf/base.config#L18) it will automatically be resubmitted with higher resources request (2 x original, then 3 x original). If it still fails after the third attempt then the pipeline execution is stopped.

To change the resource requests, please see the [max resources](https://nf-co.re/docs/running/configuration/nextflow-for-your-system#set-max-resources) and [customise process resources](https://nf-co.re/docs/running/configuration/nextflow-for-your-system#customize-process-resources) section of the nf-core website.

### Custom Containers

In some cases, you may wish to change the container or conda environment used by a pipeline steps for a particular tool. By default, nf-core pipelines use containers and software from the [biocontainers](https://biocontainers.pro/) or [bioconda](https://bioconda.github.io/) projects. However, in some cases the pipeline specified version maybe out of date.

To use a different container from the default container or conda environment specified in a pipeline, please see the [updating tool versions](https://nf-co.re/docs/running/configuration/nextflow-for-your-system#update-tool-versions) section of the nf-core website.

### Custom Tool Arguments

A pipeline might not always support every possible argument or option of a particular tool used in pipeline. Fortunately, nf-core pipelines provide some freedom to users to insert additional parameters that the pipeline does not include by default.

To learn how to provide additional arguments to a particular tool of the pipeline, please see the [customising tool arguments](https://nf-co.re/docs/running/configuration/nextflow-for-your-system#modifying-tool-arguments) section of the nf-core website.

### nf-core/configs

In most cases, you will only need to create a custom config as a one-off but if you and others within your organisation are likely to be running nf-core pipelines regularly and need to use the same settings regularly it may be a good idea to request that your custom config file is uploaded to the `nf-core/configs` git repository. Before you do this please can you test that the config file works with your pipeline of choice using the `-c` parameter. You can then create a pull request to the `nf-core/configs` repository with the addition of your config file, associated documentation file (see examples in [`nf-core/configs/docs`](https://github.com/nf-core/configs/tree/master/docs)), and amending [`nfcore_custom.config`](https://github.com/nf-core/configs/blob/master/nfcore_custom.config) to include your custom profile.

See the main [Nextflow documentation](https://www.nextflow.io/docs/latest/config.html) for more information about creating your own configuration files.

If you have any questions or issues please send us a message on [Slack](https://nf-co.re/join/slack) on the [`#configs` channel](https://nfcore.slack.com/channels/configs).

## Running in the background

Nextflow handles job submissions and supervises the running jobs. The Nextflow process must run until the pipeline is finished.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow does not stop if you log out of your session. The logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or similar tool to create a detached session which you can log back into at a later time.
Some HPC setups also allow you to run nextflow within a cluster job submitted your job scheduler (from where it submits more jobs).

## Nextflow memory requirements

In some cases, the Nextflow Java virtual machines can start to request a large amount of memory.
We recommend adding the following line to your environment to limit this (typically in `~/.bashrc` or `~./bash_profile`):

```bash
NXF_OPTS='-Xms1g -Xmx4g'
```
