/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_longreadmag_pipeline'
include { ASSEMBLY               } from '../subworkflows/local/assembly'
include { BINNING                } from '../subworkflows/local/binning'
include { BIN_REFINEMENT         } from '../subworkflows/local/bin_refinement'
include { PREPARE_DATA           } from '../subworkflows/local/prepare_data'
include { READ_MAPPING           } from '../subworkflows/local/read_mapping'

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

        READ_MAPPING(
            ASSEMBLY.out.assemblies,
            pacbio_fasta,
            PREPARE_DATA.out.hic_reads
        )
        ch_versions = ch_versions.mix(READ_MAPPING.out.versions)

        if(params.enable_binning) {
            BINNING(
                ASSEMBLY.out.assemblies,
                READ_MAPPING.out.depths,
                PREPARE_DATA.out.hic_reads,
                READ_MAPPING.out.hic_bam,
                hic_enzymes
            )

            if(params.enable_bin_refinement) {
                BIN_REFINEMENT(
                    ASSEMBLY.out.assemblies,
                    BINNING.out.bins
                )
            }

            ch_bins = BINNING.out.bins
                | BIN_REFINEMENT.out.refined_bins
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
