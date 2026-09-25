#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    sanger-tol/metagenomeassembly
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/sanger-tol/metagenomeassembly
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { METAGENOMEASSEMBLY      } from './workflows/metagenomeassembly'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_metagenomeassembly_pipeline'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_nfcore_metagenomeassembly_pipeline'

include { countSamples            } from './functions/local/inputs.nf'
include { getOutdir               } from './functions/local/outputs.nf'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {
    main:
    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION(
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.input,
        params.help,
        params.help_full,
        params.show_hidden,
        params.genomad_db,
        params.rfam_rrna_cm,
        params.centrifuger_db,
        params.checkm2_db,
        params.gtdbtk_db,
        params.gtdb_ar53_metadata,
        params.gtdb_bac120_metadata,
    )

    def n_samples = countSamples(params.input)

    def pipeline_stages = [
        enable_binning: params.enable_binning,
        enable_bin_refinement: params.enable_bin_refinement,
        enable_binqc: params.enable_binqc,
        enable_taxonomy: params.enable_taxonomy,
    ]

    def binners = [
        multisplit: params.enable_multisplit && (params.enable_semibin2 || params.enable_vamb) && (n_samples > 1),
        circular: params.extract_circular_contigs,
        metabat2: params.enable_metabat2,
        maxbin2: params.enable_maxbin2,
        comebin: params.enable_comebin,
        semibin2: params.enable_semibin2,
        vamb: params.enable_vamb,
        taxvamb: params.enable_taxvamb && params.centrifuger_db,
        metator: params.enable_metator,
    ]

    def bin_refiners = [
        binette: params.enable_binette && params.checkm2_db,
        dastool: params.enable_dastool,
    ]

    def optional_tools = [
        genomad: params.enable_genomad && params.genomad_db,
    ]

    def alignment_options = [
        hic_aligner: params.hic_aligner,
        hic_mapping_cram_slices_per_chunk: params.hic_mapping_cram_slices_per_chunk,
        long_read_mapping_reads_per_chunk: params.long_read_mapping_reads_per_chunk,
    ]

    //
    // WORKFLOW: Run main workflow
    //
    SANGERTOL_METAGENOMEASSEMBLY(
        PIPELINE_INITIALISATION.out.long_reads_assembly,
        PIPELINE_INITIALISATION.out.hic_reads,
        PIPELINE_INITIALISATION.out.genomad_db,
        PIPELINE_INITIALISATION.out.rfam_rrna_cm,
        PIPELINE_INITIALISATION.out.centrifuger_db,
        PIPELINE_INITIALISATION.out.checkm2_db,
        PIPELINE_INITIALISATION.out.gtdbtk_db,
        PIPELINE_INITIALISATION.out.gtdb_ar53_metadata,
        PIPELINE_INITIALISATION.out.gtdb_bac120_metadata,
        pipeline_stages,
        params.assembler,
        binners,
        bin_refiners,
        optional_tools,
        alignment_options,
        params.outdir,
    )

    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION(
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
    )

    publish:
    assemblies          = SANGERTOL_METAGENOMEASSEMBLY.out.assemblies.map { it -> it + [n_samples: n_samples] }
    assembly_analysis   = SANGERTOL_METAGENOMEASSEMBLY.out.assembly_analysis.map { it -> it + [n_samples: n_samples] }
    binning_preparation = SANGERTOL_METAGENOMEASSEMBLY.out.binning_preparation.map { it -> it + [n_samples: n_samples] }
    binning             = SANGERTOL_METAGENOMEASSEMBLY.out.binning.map { it -> it + [n_samples: n_samples] }
    centrifuger         = SANGERTOL_METAGENOMEASSEMBLY.out.centrifuger.map { it -> it + [n_samples: n_samples] }
}

output {
    assemblies {
        path { obj ->
            obj.assembly_files >> getOutdir(obj) + "assembly/"
        }
    }
    assembly_analysis {
        path { obj ->
            obj.stats >> getOutdir(obj) + "assembly/"
            obj.tiara >> getOutdir(obj) + "assembly/tiara/"
            obj.tiara_log >> getOutdir(obj) + "assembly/tiara/"
            obj.genomad >> getOutdir(obj) + "assembly/genomad/"
        }
    }
    binning_preparation {
        path { obj ->
            obj.bam >> (params.save_bams ? getOutdir(obj) + "assembly/mapping/" : null)
            obj.hic_bam >> (params.save_bams ? getOutdir(obj) + "assembly/mapping/" : null)
            obj.hic_pairs >> getOutdir(obj) + "assembly/mapping/"
            obj.depths >> getOutdir(obj) + "assembly/mapping/"
        }
    }
    binning {
        path { obj ->
            obj.bins >> getOutdir(obj) + "binning/${obj.binner}/fasta/"
            obj.extra_files >> getOutdir(obj) + "binning/${obj.binner}/"
        }
    }
    centrifuger {
        path { obj ->
            obj.out >> getOutdir(obj) + "assembly/centrifuger/"
        }
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main analysis pipeline depending on type of input
//
workflow SANGERTOL_METAGENOMEASSEMBLY {
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

    //
    // WORKFLOW: Run pipeline
    //
    METAGENOMEASSEMBLY(
        ch_long_reads_assembly,
        ch_hic_reads,
        ch_genomad_db,
        ch_rfam_rrna_cm,
        ch_centrifuger_db,
        ch_checkm2_db,
        ch_gtdbtk_db,
        ch_gtdb_ar53_metadata,
        ch_gtdb_bac120_metadata,
        val_pipeline_stages,
        val_assembler,
        val_binners,
        val_bin_refiners,
        val_tools,
        val_alignment_options,
        outdir,
    )

    emit:
    assemblies          = METAGENOMEASSEMBLY.out.assemblies
    assembly_analysis   = METAGENOMEASSEMBLY.out.assembly_analysis
    binning_preparation = METAGENOMEASSEMBLY.out.binning_preparation
    binning             = METAGENOMEASSEMBLY.out.binning
    centrifuger         = METAGENOMEASSEMBLY.out.centrifuger
}
