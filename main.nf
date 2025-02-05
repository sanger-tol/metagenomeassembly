#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    sanger-tol/longreadmag
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/sanger-tol/longreadmag
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { LONGREADMAG             } from './workflows/longreadmag'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_longreadmag_pipeline'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_nfcore_longreadmag_pipeline'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main analysis pipeline depending on type of input
//
workflow SANGERTOL_LONGREADMAG {

    take:
    pacbio_fasta // channel: pacbio fasta read in from --input
    hic_cram     // channel: hic cram read in from --input
    hic_enzymes  // channel: hic enzymes read in from --input
    rfam_rrna_cm // channel: rrna cm file from params.rfam_rrna_cm
    magscot_gtdb_hmm_db // channel: hmms for magscot
    checkm2_db   // channel: checkm2 db from --params.checkm2_db
    gtdbtk_db    // channel: gtdbtk db from --params.gtdbtk_db
    gtdbtk_mash_db  // channel: gtdbtk mash db from --params.gtdbtk_mash_db

    main:

    //
    // WORKFLOW: Run pipeline
    //
    LONGREADMAG (
        pacbio_fasta,
        hic_cram,
        hic_enzymes,
        rfam_rrna_cm,
        magscot_gtdb_hmm_db,
        checkm2_db,
        gtdbtk_db,
        gtdbtk_mash_db
    )
    // emit:
    // multiqc_report = LONGREADMAG.out.multiqc_report // channel: /path/to/multiqc_report.html
}
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
    PIPELINE_INITIALISATION (
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.input
    )

    //
    // WORKFLOW: Run main workflow
    //
    SANGERTOL_LONGREADMAG (
        PIPELINE_INITIALISATION.out.pacbio_fasta,
        PIPELINE_INITIALISATION.out.hic_cram,
        PIPELINE_INITIALISATION.out.hic_enzymes,
        PIPELINE_INITIALISATION.out.rfam_rrna_cm,
        PIPELINE_INITIALISATION.out.magscot_gtdb_hmm_db,
        PIPELINE_INITIALISATION.out.checkm2_db,
        PIPELINE_INITIALISATION.out.gtdbtk_db,
        PIPELINE_INITIALISATION.out.gtdbtk_mash_db
    )
    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION (
        params.outdir,
        params.monochrome_logs,
        []
    )

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
