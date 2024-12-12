/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap                    } from 'plugin/nf-schema'
include { paramsSummaryMultiqc                } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML              } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText              } from '../subworkflows/local/utils_nfcore_longreadmag_pipeline'
include { ASSEMBLY                            } from '../subworkflows/local/assembly'
include { BINNING                             } from '../subworkflows/local/binning'
include { BIN_QC                              } from '../subworkflows/local/bin_qc.nf'
include { BIN_TAXONOMY                        } from '../subworkflows/local/bin_taxonomy'
include { BIN_REFINEMENT                      } from '../subworkflows/local/bin_refinement'
include { CONTIG2BIN2FASTA as BINS_TO_PROTEIN } from '../modules/local/contig2bin2fasta/main'
include { PREPARE_DATA                        } from '../subworkflows/local/prepare_data'
include { READ_MAPPING                        } from '../subworkflows/local/read_mapping'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow LONGREADMAG {
    take:
    pacbio_fasta // channel: pacbio read in from yaml
    hic_cram     // channel: hic cram files from yaml
    hic_enzymes  // channel: hic enzyme list from yaml

    main:
    ch_versions = Channel.empty()
    // ch_multiqc_files = Channel.empty()

    PREPARE_DATA(
        hic_cram
    )
    ch_versions = ch_versions.mix(PREPARE_DATA.out.versions)

    if(params.enable_assembly) {
        ASSEMBLY(pacbio_fasta)
        ch_versions = ch_versions.mix(ASSEMBLY.out.versions)
        ch_assemblies = ASSEMBLY.out.assemblies
        ch_proteins = ASSEMBLY.out.proteins

        READ_MAPPING(
            ch_assemblies,
            pacbio_fasta,
            PREPARE_DATA.out.hic_reads
        )
        ch_versions = ch_versions.mix(READ_MAPPING.out.versions)

        if(params.enable_binning) {
            BINNING(
                ch_assemblies,
                READ_MAPPING.out.depths,
                PREPARE_DATA.out.hic_reads,
                READ_MAPPING.out.hic_bam,
                hic_enzymes
            )
            ch_contig2bin = BINNING.out.contig2bin

            if(params.enable_bin_refinement) {
                BIN_REFINEMENT(
                    ch_assemblies,
                    ch_proteins,
                    ch_contig2bin
                )
            }

            ch_bins = BINNING.out.bins
                | mix(BIN_REFINEMENT.out.refined_bins)

            ch_contig2bins = BINNING.out.contig2bin
                | mix(BIN_REFINEMENT.out.contig2bin)

            //
            // LOGIC: Convert nucleotide bins to amino acid bins using the
            //        predicted proteins from pyrodigal as many downstream processes
            //        repeat protein prediction
            //
            ch_c2b_to_join = ch_contig2bins
                | map { meta, c2b -> [meta - meta.subMap("binner"), meta, c2b] }
            ch_bin_to_protein_input = ch_c2b_to_join
                | combine(ch_proteins, by: 0)
                | map { meta, meta_c2b, c2b, faa -> [ meta_c2b, faa, c2b ] }

            BINS_TO_PROTEIN(ch_bin_to_protein_input, true)
            ch_aa_bins = BINS_TO_PROTEIN.out.bins

            //
            // LOGIC: (optional) collate bins from different binning steps into
            //        single input to reduce redundant high-memory processes
            //
            if(params.collate_bins) {
                ch_bins = ch_bins
                    | map { meta, bins ->
                        [ meta.subMap("id") + [assembler: "all"] + [binner: "all"], bins]
                    }
                    | transpose
                    | groupTuple(by: 0)

                ch_aa_bins = ch_aa_bins
                    | map { meta, bins ->
                        [ meta.subMap("id") + [assembler: "all"] + [binner: "all"], bins]
                    }
                    | transpose
                    | groupTuple(by: 0)
            }

            if(params.enable_binqc) {
                BIN_QC(ch_bins, ch_aa_bins)
                ch_versions = ch_versions.mix(BIN_QC.out.versions)
                ch_checkm2_tsv = BIN_QC.out.checkm_tsv
            } else {
                ch_checkm2_tsv = Channel.empty()
            }

            if(params.enable_taxonomy) {
                BIN_TAXONOMY(ch_aa_bins, ch_checkm2_tsv)
                ch_versions = ch_versions.mix(BIN_TAXONOMY.out.versions)
            }
        }
    }
    //
    // Collate and save software versions
    //
    // softwareVersionsToYAML(ch_versions)
    //     .collectFile(
    //         storeDir: "${params.outdir}/pipeline_info",
    //         name:  ''  + 'pipeline_software_' +  'mqc_'  + 'versions.yml',
    //         sort: true,
    //         newLine: true
    //     ).set { ch_collated_versions }


    // //
    // // MODULE: MultiQC
    // //
    // ch_multiqc_config        = Channel.fromPath(
    //     "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    // ch_multiqc_custom_config = params.multiqc_config ?
    //     Channel.fromPath(params.multiqc_config, checkIfExists: true) :
    //     Channel.empty()
    // ch_multiqc_logo          = params.multiqc_logo ?
    //     Channel.fromPath(params.multiqc_logo, checkIfExists: true) :
    //     Channel.empty()

    // summary_params      = paramsSummaryMap(
    //     workflow, parameters_schema: "nextflow_schema.json")
    // ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))
    // ch_multiqc_files = ch_multiqc_files.mix(
    //     ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    // ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
    //     file(params.multiqc_methods_description, checkIfExists: true) :
    //     file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    // ch_methods_description                = Channel.value(
    //     methodsDescriptionText(ch_multiqc_custom_methods_description))

    // ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    // ch_multiqc_files = ch_multiqc_files.mix(
    //     ch_methods_description.collectFile(
    //         name: 'methods_description_mqc.yaml',
    //         sort: true
    //     )
    // )

    // MULTIQC (
    //     ch_multiqc_files.collect(),
    //     ch_multiqc_config.toList(),
    //     ch_multiqc_custom_config.toList(),
    //     ch_multiqc_logo.toList(),
    //     [],
    //     []
    // )

    emit:
    // multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
