/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { paramsSummaryMap           } from 'plugin/nf-schema'
include { paramsSummaryMultiqc       } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML     } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText     } from '../subworkflows/local/utils_nfcore_metagenomeassembly_pipeline'
include { ASSEMBLY                   } from '../subworkflows/local/assembly'
include { ASSEMBLY_ANALYSIS          } from '../subworkflows/local/assembly_analysis'
include { BINNING                    } from '../subworkflows/local/binning'
include { BIN_QC                     } from '../subworkflows/local/bin_qc'
include { BIN_TAXONOMY               } from '../subworkflows/local/bin_taxonomy'
include { BINNING_PREPARATION        } from '../subworkflows/local/binning_preparation'
include { BIN_REFINEMENT             } from '../subworkflows/local/bin_refinement'

include { METABINTOOLS_MERGEANNOTATE } from '../modules/local/metabintools/mergeannotate'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow METAGENOMEASSEMBLY {
    take:
    ch_long_reads_assembly
    ch_hic_reads
    ch_genomad_db
    ch_rfam_rrna_cm
    ch_centrifuger_db
    ch_checkm2_db
    ch_gtdbtk_db
    ch_gtdb_ar53_metadata
    ch_gtdb_bac120_metadata
    val_pipeline_stages
    val_assembler
    val_binners
    val_bin_refiners
    val_tools
    val_alignment_options
    outdir

    main:
    ch_versions = channel.empty()

    ch_long_reads = ch_long_reads_assembly.map { meta, reads, _assembly ->
        [meta - meta.subMap("assembler"), reads]
    }

    //
    // Subworkflow: Assemble PacBio hifi reads
    //
    ASSEMBLY(
        ch_long_reads_assembly,
        val_assembler,
        val_binners,
    )

    ASSEMBLY_ANALYSIS(
        ASSEMBLY.out.assemblies.filter { meta, _asm -> !meta?.collated },
        ch_genomad_db,
        val_tools.genomad,
        ch_rfam_rrna_cm,
    )

    ch_binning_preparation_out = channel.empty()
    ch_binning_out = channel.empty()
    ch_centrifuger = channel.empty()
    if (val_pipeline_stages.enable_binning) {
        //
        // Subworkflow: Map PacBio Hifi reads and Illumina Hi-C
        // reads to the assembly and estimate per-contig coverages
        //
        BINNING_PREPARATION(
            ASSEMBLY.out.assemblies,
            ASSEMBLY.out.concatenated_assembly,
            ch_long_reads,
            ch_hic_reads,
            ASSEMBLY_ANALYSIS.out.tiara_classifications,
            val_binners,
            val_alignment_options,
        )
        ch_binning_preparation_out = BINNING_PREPARATION.out.binning_preparation_output

        //
        // Subworkflow: Bin the assembly using binning tools
        //
        BINNING(
            BINNING_PREPARATION.out.filtered_assembly,
            ASSEMBLY.out.assembly_binsfile,
            BINNING_PREPARATION.out.circles_fasta,
            BINNING_PREPARATION.out.filtered_contig_depths,
            BINNING_PREPARATION.out.filtered_bam,
            BINNING_PREPARATION.out.hic_pairs,
            ch_centrifuger_db,
            val_binners,
        )
        ch_bins_fasta = BINNING.out.bins_fasta
        ch_bins_binsfile = BINNING.out.bins_binsfile

        if (val_pipeline_stages.enable_bin_refinement) {
            //
            // Subworkflow: Refine bins using DAS_Tool and MAGScoT
            //
            BIN_REFINEMENT(
                BINNING_PREPARATION.out.filtered_assembly,
                ASSEMBLY.out.assembly_binsfile,
                ch_bins_binsfile.filter { meta, _c2b -> meta.binner != "circular" },
                ch_checkm2_db,
                val_bin_refiners.dastool,
                val_bin_refiners.binette
            )
            ch_bins_fasta = ch_bins_fasta.mix(BIN_REFINEMENT.out.refined_bins_fasta)
            ch_bins_binsfile = ch_bins_binsfile.mix(BIN_REFINEMENT.out.refined_bins_binsfile)
        }

        ch_taxonomy_tsv = channel.empty()
        if (val_pipeline_stages.enable_binqc) {
            //
            // Subworkflow: QC of bins - completeness/contamination using
            // CheckM2, statistics, tRNAs + ncRNAs
            //
            BIN_QC(
                ch_bins_fasta,
                BINNING_PREPARATION.out.full_bam,
                ch_checkm2_db,
            )


            if (val_pipeline_stages.enable_taxonomy) {
                //
                // Subworkflow: Taxonomic classification of bins using
                // GTDB-Tk and conversion of classifications to NCBI taxonomy
                //
                BIN_TAXONOMY(
                    ch_bins_fasta,
                    BIN_QC.out.checkm2_tsv,
                    ch_gtdbtk_db,
                    ch_gtdb_ar53_metadata,
                    ch_gtdb_bac120_metadata
                )
                ch_taxonomy_tsv = BIN_TAXONOMY.out.gtdb_summary
            }
        }

        //
        // Module: Merge all binfiles together and annotate bins and contigs
        //
        ch_metabintools_input = ch_bins_binsfile
            .map { meta, binsfiles -> [meta - meta.subMap("binner"), binsfiles] }
            .groupTuple()
            .join(ASSEMBLY_ANALYSIS.out.trna_gff, by: 0)
            .join(ASSEMBLY_ANALYSIS.out.rrna_gff, by: 0)
            .join(BINNING_PREPARATION.out.sample_contig_depths, by: 0)
            .join(BIN_QC.out.checkm2_tsv, by: 0)
            .join(BIN_TAXONOMY.out.gtdb_ncbi_tsv, by: 0)

        METABINTOOLS_MERGEANNOTATE(
            ch_metabintools_input,
            "gtdbtk",
            "checkm2"
        )
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

    def _ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name: 'metagenomeassembly_software_' + 'versions.yml',
            sort: true,
            newLine: true,
        )

    emit:
    assemblies          = ASSEMBLY.out.assembly_output
    assembly_analysis   = ASSEMBLY_ANALYSIS.out.assembly_analysis_output
    binning_preparation = ch_binning_preparation_out
    binning             = ch_binning_out
    bins                = ch_bins_fasta
    centrifuger         = ch_centrifuger
    versions            = ch_versions // channel: [ path(versions.yml) ]
}
