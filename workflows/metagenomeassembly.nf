/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { paramsSummaryMap             } from 'plugin/nf-schema'
include { paramsSummaryMultiqc         } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML       } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText       } from '../subworkflows/local/utils_nfcore_metagenomeassembly_pipeline'
include { ASSEMBLY                     } from '../subworkflows/local/assembly'
include { ASSEMBLY_ANALYSIS            } from '../subworkflows/local/assembly_analysis'
include { BINNING                      } from '../subworkflows/local/binning'
include { BIN_QC                       } from '../subworkflows/local/bin_qc'
include { BIN_TAXONOMY                 } from '../subworkflows/local/bin_taxonomy'
include { BINNING_PREPARATION          } from '../subworkflows/local/binning_preparation'
include { BIN_REFINEMENT               } from '../subworkflows/local/bin_refinement'

include { METABINTOOLS_MERGEANNOTATE   } from '../modules/local/metabintools/mergeannotate'
include { METABINTOOLS_SUMMARISEBINS   } from '../modules/local/metabintools/summarisebins'
include { METABINTOOLS_SUMMARISEGROUPS } from '../modules/local/metabintools/summarisegroups'

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

    //
    // Subworkflow: Map PacBio Hifi reads and Illumina Hi-C
    // reads to the assembly and estimate per-contig coverages
    //
    BINNING_PREPARATION(
        ASSEMBLY.out.assemblies.filter { val_pipeline_stages.enable_binning },
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
        BINNING_PREPARATION.out.filtered_assembly.filter { val_pipeline_stages.enable_binning },
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

    //
    // Subworkflow: Refine bins using DAS_Tool and MAGScoT
    //
    BIN_REFINEMENT(
        BINNING_PREPARATION.out.filtered_assembly.filter { val_pipeline_stages.enable_bin_refinement },
        ASSEMBLY.out.assembly_binsfile.filter { val_pipeline_stages.enable_bin_refinement },
        ch_bins_binsfile.filter { meta, _c2b -> meta.binner != "circular" && val_pipeline_stages.enable_bin_refinement },
        ch_checkm2_db,
        val_bin_refiners.dastool,
        val_bin_refiners.binette,
    )
    ch_bins_fasta = ch_bins_fasta.mix(BIN_REFINEMENT.out.refined_bins_fasta)
    ch_bins_binsfile = ch_bins_binsfile.mix(BIN_REFINEMENT.out.refined_bins_binsfile)

    //
    // Subworkflow: QC of bins - completeness/contamination using
    // CheckM2, statistics, tRNAs + ncRNAs
    //
    BIN_QC(
        ch_bins_fasta.filter { val_pipeline_stages.enable_binqc },
        BINNING_PREPARATION.out.full_bam,
        ch_checkm2_db,
    )

    //
    // Subworkflow: Taxonomic classification of bins using
    // GTDB-Tk and conversion of classifications to NCBI taxonomy
    //
    BIN_TAXONOMY(
        ch_bins_fasta.filter { val_pipeline_stages.enable_taxonomy },
        BIN_QC.out.checkm2_tsv,
        ch_gtdbtk_db,
        ch_gtdb_ar53_metadata,
        ch_gtdb_bac120_metadata,
    )

    //
    // Module: Merge all binfiles together and annotate bins and contigs
    //
    ch_metabintools_input = ch_bins_binsfile
        .map { meta, binsfiles -> [meta - meta.subMap("binner"), binsfiles] }
        .groupTuple(sort: { f -> f.getName() })
        .join(ASSEMBLY_ANALYSIS.out.trna_gff, by: 0)
        .join(ASSEMBLY_ANALYSIS.out.rrna_gff, by: 0)
        .join(BINNING_PREPARATION.out.sample_contig_depths, by: 0)
        .join(BIN_QC.out.checkm2_tsv, by: 0, remainder: true)
        .join(BIN_TAXONOMY.out.gtdb_ncbi_tsv, by: 0, remainder: true)
        .map { meta, binsfiles, trna, rrna, depths, checkm2, tax ->
            [meta, binsfiles, trna, rrna, depths, checkm2 ?: [], tax ?: []]
        }

    METABINTOOLS_MERGEANNOTATE(
        ch_metabintools_input,
        "gtdbtk_ncbi",
        "checkm2",
    )

    METABINTOOLS_SUMMARISEBINS(METABINTOOLS_MERGEANNOTATE.out.binsfile)
    METABINTOOLS_SUMMARISEGROUPS(METABINTOOLS_MERGEANNOTATE.out.binsfile)

    ch_binfiles_publish = METABINTOOLS_MERGEANNOTATE.out.binsfile
        .join(METABINTOOLS_SUMMARISEBINS.out.tsv, by: 0)
        .join(METABINTOOLS_SUMMARISEGROUPS.out.tsv, by: 0)
        .map { meta, binsfile, bin_summary, group_summary ->
            meta + [binsfile: binsfile, bin_summary: bin_summary, group_summary: group_summary]
        }

    ch_assembly_publish = ASSEMBLY.out.assembly_output
        .join(ASSEMBLY_ANALYSIS.out.assembly_statistics, by: 0)
        .join(ASSEMBLY_ANALYSIS.out.tiara_classifications, by: 0)
        .join(ASSEMBLY_ANALYSIS.out.tiara_log, by: 0)
        .join(ASSEMBLY_ANALYSIS.out.genomad_results, by: 0, remainder: true)
        .join(ASSEMBLY_ANALYSIS.out.trna_tsv, by: 0)
        .join(ASSEMBLY_ANALYSIS.out.trna_stats, by: 0)
        .join(ASSEMBLY_ANALYSIS.out.trna_gff, by: 0)
        .join(ASSEMBLY_ANALYSIS.out.trna_log, by: 0)
        .join(ASSEMBLY_ANALYSIS.out.rrna_gff, by: 0)
        .join(BIN_REFINEMENT.out.annotations, by: 0, remainder: true)
        .map { meta, asm, asm_files, stats, tiara, tiara_log, genomad, trna_tsv, trna_stats, trna_gff, trna_log, rrna_gff, pyrodigal_annotations ->
            meta + [
                assembly: asm.toUriString() =~ "${workflow.workDir}/[0-9a-z]{2}/[0-9a-z]{30}" ? asm : null,
                assembly_files: asm_files,
                stats: stats,
                tiara: tiara,
                tiara_log: tiara_log,
                genomad: genomad ? genomad.listDirectory() : null,
                trna_tsv: trna_tsv,
                trna_stats: trna_stats,
                trna_gff: trna_gff,
                trna_log: trna_log,
                rrna_gff: rrna_gff,
                pyrodigal_annotations: pyrodigal_annotations,
            ]
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
    assemblies      = ch_assembly_publish
    mapping         = ch_binning_preparation_out
    binning         = BINNING.out.binning_publish.mix(BIN_REFINEMENT.out.bin_refinement_publish)
    bin_qc          = BIN_QC.out.binqc_publish
    bin_taxonomy    = BIN_TAXONOMY.out.bin_taxonomy_publish
    binning_summary = ch_binfiles_publish
    versions        = ch_versions // channel: [ path(versions.yml) ]
}
