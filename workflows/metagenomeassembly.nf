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
    ch_long_reads // channel: pacbio read in from yaml
    ch_provided_assembly // channel: pre-built metagenome assembly, optional
    ch_hic_cram // channel: hic cram files from yaml, optional
    val_assembler // string: assembler to use
    ch_genomad_db // file: genomad db from params
    val_enable_rrna_prediction // boolean: enable rrna prediction
    ch_rfam_rrna_cm // channel: rRNA cm file from params
    val_minimum_circular_contig_length // integer: minimum circular contig length
    val_enable_genomad // boolean: enable genomad?
    val_rrna_prediction // boolean: enable rrna prediction
    val_enable_trnascanse // boolean: enable trnascan se?
    val_enable_binning // boolean: enable binning?
    val_extract_circular_contigs // boolean: extract circular contigs?
    val_enable_metabat2 // boolean: enable metabat2?
    val_enable_maxbin2 // boolean: enable maxbin2?
    val_enable_comebin // boolean: enable comebin?
    val_enable_semibin // boolean: enable semibin?
    val_enable_vamb // boolean: enable vamb?
    val_enable_metator // boolean: enable metator?
    val_hic_aligner // string: which aligner to use for Hi-C mapping
    val_cram_chunk_size // integer: how many hic cram slices to map in a single chunk
    val_reads_per_fasta_chunk // integer: how many long reads to map in a single chunk
    val_enable_bin_refinement // boolean: enable bin refinement?
    ch_magscot_gtdb_hmm_db // channel: magscot hmm files from params
    val_enable_dastool // boolean: enable dastool?
    val_enable_magscot // boolean: enable magscot?
    val_enable_binqc // boolean: enable binqc?
    val_enable_checkm2 // boolean: enable checkm2?
    ch_checkm2_db // file: checkm2 db from params
    val_enable_taxonomy // boolean: enable taxonomy?
    val_enable_gtdbtk // boolean: enable gtdbtk?
    ch_gtdbtk_db // channel: gtdbtk db from params
    val_ar53_metadata // path: ar53 metadata file
    val_bac120_metadata // path: bac120 metadata file
    outdir

    main:
    ch_versions = channel.empty()

    //
    // SUBWORKFLOW: Assemble PacBio hifi reads
    //
    ASSEMBLY(
        ch_long_reads,
        ch_provided_assembly,
        val_assembler,
        val_minimum_circular_contig_length
    )

    //
    // SUBWORKFLOW: QC for assemblies - statistics, rRNA models,
    // check contig circularity and classify circular contigs
    //
    ASSEMBLY_QC(
        ASSEMBLY.out.full_assemblies,
        ASSEMBLY.out.circles_list,
        val_enable_genomad,
        ch_genomad_db,
        val_enable_rrna_prediction,
        ch_rfam_rrna_cm,
        val_enable_trnascanse
    )

    if (val_enable_binning) {
        if (val_extract_circular_contigs) {
            ch_assemblies_to_bin = ASSEMBLY.out.linear_contigs
        } else {
            ch_assemblies_to_bin = ASSEMBLY.out.full_assemblies
        }

        //
        // Subworkflow: Map PacBio Hifi reads and Illumina Hi-C
        // reads to the assembly and estimate per-contig coverages
        //
        READ_MAPPING(
            ASSEMBLY.out.full_assemblies,
            ASSEMBLY.out.circles_list,
            ch_long_reads,
            ch_hic_cram,
            val_enable_metator,
            val_hic_aligner,
            val_cram_chunk_size,
            val_reads_per_fasta_chunk,
            val_extract_circular_contigs,
        )

        //
        // Subworkflow: Bin the assembly using binning tools
        //
        BINNING(
            ch_assemblies_to_bin,
            ASSEMBLY.out.circular_contigs,
            READ_MAPPING.out.depths,
            READ_MAPPING.out.filtered_bam,
            READ_MAPPING.out.hic_pairs,
            val_extract_circular_contigs,
            val_enable_metabat2,
            val_enable_maxbin2,
            val_enable_comebin,
            val_enable_semibin,
            val_enable_vamb,
            val_enable_metator,
        )
        ch_versions = ch_versions.mix(BINNING.out.versions)
        ch_bins = BINNING.out.bins
        ch_contig2bin = BINNING.out.contig2bin

        if (val_enable_bin_refinement) {
            //
            // Subworkflow: Refine bins using DAS_Tool and MAGScoT
            //
            BIN_REFINEMENT(
                ch_assemblies_to_bin,
                BINNING.out.contig2bin.filter { meta, c2b -> meta.binner != "circular" },
                ch_magscot_gtdb_hmm_db,
                val_enable_dastool,
                val_enable_magscot
            )
            ch_versions = ch_versions.mix(BIN_REFINEMENT.out.versions)
            ch_bins = ch_bins.mix(BIN_REFINEMENT.out.refined_bins)
            ch_contig2bin = ch_contig2bin.mix(BIN_REFINEMENT.out.contig2bin)
        }

        if (val_enable_binqc) {
            //
            // Subworkflow: QC of bins - completeness/contamination using
            // CheckM2, statistics, tRNAs + ncRNAs
            //
            BIN_QC(
                ch_bins,
                ch_contig2bin,
                ASSEMBLY.out.circles_list,
                READ_MAPPING.out.full_bam,
                ch_checkm2_db,
                ASSEMBLY_QC.out.trna_summary,
                ASSEMBLY_QC.out.rrna_summary,
                val_enable_checkm2
            )

            ch_taxonomy_tsv = channel.empty()
            if (val_enable_taxonomy) {
                //
                // Subworkflow: Taxonomic classification of bins using
                // GTDB-Tk and conversion of classifications to NCBI taxonomy
                //
                BIN_TAXONOMY(
                    ch_bins,
                    BIN_QC.out.checkm2_tsv,
                    ch_gtdbtk_db,
                    val_enable_gtdbtk,
                    val_ar53_metadata,
                    val_bac120_metadata
                )
                ch_taxonomy_tsv = BIN_TAXONOMY.out.gtdb_summary
            }

            ch_stats_collated = BIN_QC.out.stats
                .map { meta, tsv -> [meta.subMap('id'), tsv] }
                .groupTuple(by: 0)

            ch_coverage_collated = BIN_QC.out.coverage
                .map { meta, tsv -> [meta.subMap('id'), tsv] }
                .groupTuple(by: 0)
                .ifEmpty([[], []])

            ch_checkm2_collated = BIN_QC.out.checkm2_tsv
                .map { meta, tsv -> [meta.subMap('id'), tsv] }
                .groupTuple(by: 0)
                .ifEmpty([[], []])

            ch_taxonomy_collated = ch_taxonomy_tsv
                .map { meta, tsv -> [meta.subMap('id'), tsv] }
                .groupTuple(by: 0)
                .ifEmpty([[], []])

            ch_trnascan_collated = BIN_QC.out.trnascan_summary
                .map { meta, tsv -> [meta.subMap('id'), tsv] }
                .groupTuple(by: 0)
                .ifEmpty([[], []])

            ch_rrna_collated = BIN_QC.out.rrna_summary
                .map { meta, tsv -> [meta.subMap('id'), tsv] }
                .groupTuple(by: 0)
                .ifEmpty([[], []])

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
                ch_rrna_collated,
            )
        }
    }
    //
    // Collate and save software versions
    //
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [process[process.lastIndexOf(':') + 1..-1], "  ${tool}: ${version}"]
        }
        .groupTuple(by: 0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name:  'metagenomeassembly_software_'  + 'versions.yml',
            sort: true,
            newLine: true
        )
    emit:
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}
