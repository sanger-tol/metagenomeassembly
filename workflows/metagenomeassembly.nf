/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_metagenomeassembly_pipeline'
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

workflow METAGENOMEASSEMBLY {
    take:
    pacbio_fasta        // channel: pacbio read in from yaml
    assembly            // channel: pre-built metagenome assembly, optional
    hic_cram            // channel: hic cram files from yaml, optional
    hic_enzymes         // channel: hic enzyme list from yaml, optional
    genomad_db          // channel: genomad db from params
    rfam_rrna_cm        // channel: rRNA cm file from params
    magscot_gtdb_hmm_db // channel: magscot hmm files from params
    checkm2_db          // channel: checkm2 db from params
    gtdbtk_db           // channel: gtdbtk db from params
    val_hic_binning           // boolean: hic binnning enabled
    val_hic_aligner           // string: which aligner to use for Hi-C mapping
    val_cram_chunk_size       // integer: how many hic cram slices to map in a single chunk
    val_reads_per_fasta_chunk // integer: how many long reads to map in a single chunk

    main:
    ch_versions = channel.empty()

    //
    // SUBWORKFLOW: Assemble PacBio hifi reads
    //
    ASSEMBLY(
        pacbio_fasta,
        assembly
    )
    ch_versions = ch_versions.mix(ASSEMBLY.out.versions)

    ch_assemblies = ASSEMBLY.out.assemblies

    //
    // SUBWORKFLOW: QC for assemblies - statistics, rRNA models,
    // check contig circularity and classify circular contigs
    //
    ASSEMBLY_QC(
        ch_assemblies,
        rfam_rrna_cm,
        genomad_db
    )
    ch_versions = ch_versions.mix(ASSEMBLY_QC.out.versions)

    ch_assembly_rrna = ASSEMBLY_QC.out.rrna
    ch_circles = ASSEMBLY_QC.out.circle_list

    if(params.enable_binning) {
        //
        // SUBWORKFLOW: Map PacBio Hifi reads and Illumina Hi-C
        // reads to the assembly and estimate per-contig coverages
        //
        READ_MAPPING(
            ch_assemblies,
            pacbio_fasta,
            hic_cram,
            val_hic_binning,
            val_hic_aligner,
            val_cram_chunk_size,
            val_reads_per_fasta_chunk
        )
        ch_versions = ch_versions.mix(READ_MAPPING.out.versions)

        //
        // SUBWORKFLOW: Bin the assembly using binning tools
        //
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
            //
            // SUBWORKFLOW: Refine bins using DAS_Tool and MAGScoT
            //
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
            //
            // SUBWORKFLOW: QC of bins - completeness/contamination using
            // CheckM2, statistics, tRNAs + ncRNAs
            //
            BIN_QC(
                ch_bins,
                ch_contig2bin,
                ch_circles,
                READ_MAPPING.out.pacbio_bam,
                ch_assembly_rrna,
                checkm2_db
            )
            ch_versions = ch_versions.mix(BIN_QC.out.versions)

            ch_taxonomy_tsv = Channel.empty()

            if(params.enable_taxonomy) {
                //
                // SUBWORKFLOW: Taxonomic classification of bins using
                // GTDB-Tk and conversion of classifications to NCBI taxonomy
                //
                BIN_TAXONOMY(
                    ch_bins,
                    BIN_QC.out.checkm2_tsv,
                    gtdbtk_db,
                )
                ch_versions = ch_versions.mix(BIN_TAXONOMY.out.versions)
                ch_taxonomy_tsv = BIN_TAXONOMY.out.gtdb_summary
            }

            ch_stats_collated = BIN_QC.out.stats
                | map { meta, tsv -> [ meta.subMap('id'), tsv ] }
                | groupTuple(by: 0)

            ch_coverage_collated = BIN_QC.out.coverage
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

            //
            // SUBWORKFLOW: Collate all bin information into tabular
            // output, and summarise across binners
            //
            BIN_SUMMARY(
                ch_stats_collated,
                ch_coverage_collated,
                ch_checkm2_collated,
                ch_taxonomy_collated,
                ch_trnascan_collated,
                ch_rrna_collated
            )
            ch_versions = ch_versions.mix(BIN_SUMMARY.out.versions)
        }
    }
    //
    // Collate and save software versions
    //
    def topic_versions = Channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name:  'metagenomeassembly_software_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { _ch_collated_versions }


    emit:
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
