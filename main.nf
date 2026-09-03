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
    ch_pacbio_fasta // channel: pacbio fasta read in from --input
    ch_assembly // channel: pre-existing assembly read in from --input
    ch_hic_cram // channel: hic cram read in from --input
    val_assembler // string: assembler to use
    val_minimum_contig_size // integer: minimum contig size
    val_maximum_contig_size // integer: maximum contig size
    val_minimum_circular_contig_length // integer: minimum circular contig length
    val_enable_tiara // boolean: enable tiara?
    val_tiara_exclude_classifications // string: tiara exclude classifications
    val_enable_genomad // boolean: enable genomad?
    ch_genomad_db // channel: genomad db from params.genomad_db
    val_enable_binning // boolean: enable binning?
    val_extract_circular_contigs // boolean: extract circular contigs?
    val_enable_metabat2 // boolean: enable metabat2?
    val_enable_maxbin2 // boolean: enable maxbin2?
    val_enable_comebin // boolean: enable comebin?
    val_enable_semibin2 // boolean: enable semibin?
    val_enable_vamb // boolean: enable vamb?
    val_enable_taxvamb // boolean: enable taxvamb?
    ch_centrifuger_db // channel: centrifuger db from params.centrifuger_db
    val_enable_metator // boolean: enable metator?
    val_hic_aligner // string: which aligner to use for Hi-C mapping
    val_cram_chunk_size // integer: how many hic cram slices to map in a single chunk
    val_reads_per_fasta_chunk // integer: how many long reads to map in a single chunk
    val_enable_bin_refinement // boolean: enable bin refinement?
    val_enable_dastool // boolean: enable dastool?
    val_enable_binette // boolean: enable magscot?
    val_enable_binqc // boolean: enable binqc?
    val_enable_checkm2 // boolean: enable checkm2?
    ch_checkm2_db // channel: checkm2 db from --params.checkm2_db
    val_enable_rrna_prediction // boolean: enable rrna prediction
    val_rfam_rrna_cm // channel: rrna cm file from params.rfam_rrna_cm
    val_enable_trnascanse // boolean: enable trnascan se?
    val_enable_taxonomy // boolean: enable taxonomy?
    val_enable_gtdbtk // boolean: enable gtdbtk?
    ch_gtdbtk_db // channel: gtdbtk db from --params.gtdbtk_db
    val_ar53_metadata // path: gtdbtk ar53 metadata
    val_bac120_metadata // path: gtdbtk bac120 metadata
    outdir

    main:

    //
    // WORKFLOW: Run pipeline
    //
    METAGENOMEASSEMBLY(
        ch_pacbio_fasta,
        ch_assembly,
        ch_hic_cram,
        val_assembler,
        val_minimum_contig_size,
        val_maximum_contig_size,
        val_minimum_circular_contig_length,
        val_enable_tiara,
        val_tiara_exclude_classifications,
        val_enable_genomad,
        ch_genomad_db,
        val_enable_binning,
        val_extract_circular_contigs,
        val_enable_metabat2,
        val_enable_maxbin2,
        val_enable_comebin,
        val_enable_semibin2,
        val_enable_vamb,
        val_enable_taxvamb,
        ch_centrifuger_db,
        val_enable_metator,
        val_hic_aligner,
        val_cram_chunk_size,
        val_reads_per_fasta_chunk,
        val_enable_bin_refinement,
        val_enable_dastool,
        val_enable_binette,
        val_enable_binqc,
        val_enable_checkm2,
        ch_checkm2_db,
        val_enable_rrna_prediction,
        val_rfam_rrna_cm,
        val_enable_trnascanse,
        val_enable_taxonomy,
        val_enable_gtdbtk,
        ch_gtdbtk_db,
        val_ar53_metadata,
        val_bac120_metadata,
        outdir
    )
}
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {
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
        params.checkm2_db,
        params.gtdbtk_db,
        params.centrifuger_db
    )

    //
    // WORKFLOW: Run main workflow
    //
    SANGERTOL_METAGENOMEASSEMBLY(
        PIPELINE_INITIALISATION.out.pacbio_fasta,
        PIPELINE_INITIALISATION.out.assembly,
        PIPELINE_INITIALISATION.out.hic_cram,
        params.assembler,
        params.minimum_contig_size,
        params.maximum_contig_size,
        params.minimum_circular_contig_length,
        params.enable_tiara,
        params.tiara_exclude_classifications,
        params.enable_genomad && params.genomad_db,
        PIPELINE_INITIALISATION.out.genomad_db,
        params.enable_binning,
        params.extract_circular_contigs,
        params.enable_metabat2,
        params.enable_maxbin2,
        params.enable_comebin,
        params.enable_semibin2,
        params.enable_vamb,
        params.enable_taxvamb && params.centrifuger_db,
        PIPELINE_INITIALISATION.out.centrifuger_db,
        params.enable_metator,
        params.hic_aligner,
        params.hic_mapping_cram_bin_size,
        params.long_read_mapping_reads_per_chunk,
        params.enable_bin_refinement,
        params.enable_dastool,
        params.enable_binette,
        params.enable_binqc,
        params.enable_checkm2 && params.checkm2_db,
        PIPELINE_INITIALISATION.out.checkm2_db,
        params.enable_rrna_prediction,
        PIPELINE_INITIALISATION.out.rfam_rrna_cm,
        params.enable_trnascanse,
        params.enable_taxonomy,
        params.enable_gtdbtk && params.gtdbtk_db,
        PIPELINE_INITIALISATION.out.gtdbtk_db,
        params.gtdb_ar53_metadata,
        params.gtdb_bac120_metadata,
        params.outdir
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
}
