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
include { BIN_QC                 } from '../subworkflows/local/bin_qc'
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
    pacbio_fasta        // channel: pacbio read in from yaml
    assembly            // channel: pre-built metagenome assembly, optional
    hic_cram            // channel: hic cram files from yaml, optional
    hic_enzymes         // channel: hic enzyme list from yaml, optional
    rfam_rrna_cm        // channel: rRNA cm file from params
    magscot_gtdb_hmm_db // channel: magscot hmm files from params
    checkm2_db          // channel: checkm2 db from params
    gtdbtk_db           // channel: gtdbtk db from params
    gtdbtk_mash_db      // channel: gtdbtk mash db from params

    main:
    ch_versions = Channel.empty()
    ch_assemblies = assembly

    if(params.enable_assembly) {
        // Only provide reads to ASSEMBLY subwf if ch_assemblies is 
        // empty - cross reads with assembly channel, which gets
        // false if empty, and filter to just keep false entries
        ch_assembly_input = pacbio_fasta
            | combine(ch_assemblies.ifEmpty([[:], false]))
            | filter { it[3] == false }
            | map { meta_reads, reads, meta_assembly, assembly -> 
                [ meta_reads, reads ]
            }

        ASSEMBLY(ch_assembly_input)
        ch_versions = ch_versions.mix(ASSEMBLY.out.versions)
        ch_assemblies = ch_assemblies.mix(ASSEMBLY.out.assemblies)
    }

    ASSEMBLY_QC(ch_assemblies, rfam_rrna_cm)
    ch_versions = ch_versions.mix(ASSEMBLY_QC.out.versions)
    ch_assembly_rrna = ASSEMBLY_QC.out.rrna
    ch_circles = ASSEMBLY_QC.out.circle_list

    READ_MAPPING(
        ch_assemblies,
        pacbio_fasta,
        hic_cram
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
                ch_contig2bin,
                magscot_gtdb_hmm_db
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
                ch_assembly_rrna,
                checkm2_db
            )
            ch_versions = ch_versions.mix(BIN_QC.out.versions)

            if(params.enable_taxonomy) {
                BIN_TAXONOMY(
                    ch_bins,
                    BIN_QC.out.checkm2_tsv,
                    gtdbtk_db,
                    gtdbtk_mash_db
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
                    | ifEmpty([[],[]])

                ch_checkm2_collated = BIN_QC.out.checkm2_tsv
                    | map { meta, tsv -> [ meta.subMap('id'), tsv ] }
                    | groupTuple(by: 0)
                    | ifEmpty([[],[]])

                ch_taxonomy_collated = ch_taxonomy_tsv
                    | map { meta, tsv -> [ meta.subMap('id'), tsv ] }
                    | groupTuple(by: 0)
                    | ifEmpty([[],[]])

                ch_trnascan_collated = BIN_QC.out.trnascan_summary
                    | map { meta, tsv -> [ meta.subMap('id'), tsv ] }
                    | groupTuple(by: 0)
                    | ifEmpty([[],[]])

                ch_rrna_collated = BIN_QC.out.rrna_summary
                    | map { meta, tsv -> [ meta.subMap('id'), tsv ] }
                    | groupTuple(by: 0)
                    | ifEmpty([[],[]])

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
    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name:  'sangertol_longreadmag_'  + 'pipeline_software_' +  'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        )//.set { ch_collated_versions }

    emit:
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
