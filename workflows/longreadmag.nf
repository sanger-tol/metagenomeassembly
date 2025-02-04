/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_longreadmag_pipeline'
include { ASSEMBLY               } from '../subworkflows/local/assembly'
include { ASSEMBLY_QC            } from '../subworkflows/local/assembly_qc'
include { BINNING                } from '../subworkflows/local/binning'
include { BIN_QC                 } from '../subworkflows/local/bin_qc.nf'
include { BIN_TAXONOMY           } from '../subworkflows/local/bin_taxonomy'
include { BIN_REFINEMENT         } from '../subworkflows/local/bin_refinement'
include { BIN_SUMMARY            } from '../modules/local/bin_summary'
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

    if(params.enable_assembly) {
        ASSEMBLY(pacbio_fasta)
        ch_versions = ch_versions.mix(ASSEMBLY.out.versions)
        ch_assemblies = ASSEMBLY.out.assemblies

        ASSEMBLY_QC(ch_assemblies)
        ch_versions = ch_versions.mix(ASSEMBLY_QC.out.versions)
        ch_assembly_rrna = ASSEMBLY_QC.out.rrna
        ch_circles = ASSEMBLY_QC.out.circle_list

        READ_MAPPING(
            ch_assemblies,
            pacbio_fasta,
            PREPARE_DATA.out.hic_cram
        )
        ch_versions = ch_versions.mix(READ_MAPPING.out.versions)

        if(params.enable_binning) {
            BINNING(
                ch_assemblies,
                READ_MAPPING.out.depths,
                READ_MAPPING.out.hic_bam,
                hic_enzymes
            )
            ch_versions   = ch_versions.mix(BINNING.out.versions)
            ch_bins       = BINNING.out.bins
            ch_contig2bin = BINNING.out.contig2bin

            if(params.enable_bin_refinement) {
                BIN_REFINEMENT(
                    ch_assemblies,
                    ch_contig2bin
                )
                ch_versions   = ch_versions.mix(BIN_REFINEMENT.out.versions)
                ch_bins       = ch_bins.mix(BIN_REFINEMENT.out.refined_bins)
                ch_contig2bin = ch_contig2bin.mix(BIN_REFINEMENT.out.contig2bin)
            }

            if(params.enable_binqc) {
                BIN_QC(
                    ch_bins,
                    ch_contig2bin,
                    ch_circles,
                    ch_assembly_rrna
                )
                ch_versions = ch_versions.mix(BIN_QC.out.versions)

                if(params.enable_taxonomy) {
                    BIN_TAXONOMY(
                        ch_bins,
                        BIN_QC.out.checkm2_tsv
                    )
                    ch_versions = ch_versions.mix(BIN_TAXONOMY.out.versions)

                    ch_taxonomy_tsv = BIN_TAXONOMY.out.gtdb_ncbi
                } else {
                    ch_taxonomy_tsv = Channel.empty()
                }

                if(params.enable_summary) {
                    ch_stats_collated = BIN_QC.out.stats
                        | map { meta, tsv -> [ meta.subMap('id'), tsv ] }
                        | groupTuple(by: 0)

                    ch_checkm2_collated = BIN_QC.out.checkm2_tsv
                        | map { meta, tsv -> [ meta.subMap('id'), tsv ] }
                        | groupTuple(by: 0)

                    ch_taxonomy_collated = ch_taxonomy_tsv
                        | map { meta, tsv -> [ meta.subMap('id'), tsv ] }
                        | groupTuple(by: 0)

                    ch_trnascan_collated = BIN_QC.out.trnascan_summary
                        | map { meta, tsv -> [ meta.subMap('id'), tsv ] }
                        | groupTuple(by: 0)

                    ch_rrna_collated = BIN_QC.out.rrna_summary
                        | map { meta, tsv -> [ meta.subMap('id'), tsv ] }
                        | groupTuple(by: 0)

                    BIN_SUMMARY(
                        ch_stats_collated,
                        ch_checkm2_collated,
                        ch_taxonomy_collated,
                        ch_trnascan_collated,
                        ch_rrna_collated
                    )
                    ch_versions = ch_versions.mix(BIN_SUMMARY.out.versions)
                }
            }
        }
    }
    // //
    // // Collate and save software versions
    // //
    // softwareVersionsToYAML(ch_versions)
    //     .collectFile(
    //         storeDir: "${params.outdir}/pipeline_info",
    //         name:  'sangertol_longreadmag_'  + 'pipeline_software_' +  'mqc_'  + 'versions.yml',
    //         sort: true,
    //         newLine: true
    //     ).set { ch_collated_versions }

    emit:
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
