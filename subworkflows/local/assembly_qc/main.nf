include { FIND_CIRCLES                            } from '../../../modules/local/find_circles/main'
include { GENOMAD_ENDTOEND                        } from '../../../modules/nf-core/genomad/endtoend'
include { GENOME_STATS as GENOME_STATS_ASSEMBLIES } from '../../../modules/local/genome_stats/main'
include { INFERNAL_CMSEARCH                       } from '../../../modules/nf-core/infernal/cmsearch/main'

workflow ASSEMBLY_QC {
    take:
    ch_assemblies // [meta, assembly.fa.gz]
    val_rfam_rrna_cm
    val_genomad_db

    main:
    ch_versions = Channel.empty()

    //
    // MODULE: Identify which contigs are circular
    //
    FIND_CIRCLES(ch_assemblies)
    ch_versions = ch_versions.mix(FIND_CIRCLES.out.versions)

    ch_genome_stats_input = ch_assemblies
        | combine(FIND_CIRCLES.out.circles_list, by: 0)

    //
    // MODULE: Classify circular contigs using genomad
    //
    if(params.enable_genomad) {
        GENOMAD_ENDTOEND(
            FIND_CIRCLES.out.circles_fasta,
            val_genomad_db
        )
        ch_versions = ch_versions.mix(GENOMAD_ENDTOEND.out.versions)
    }

    //
    // MODULE: Calculate assembly statistics, including counts of circles
    //
    GENOME_STATS_ASSEMBLIES(ch_genome_stats_input)
    ch_versions = ch_versions.mix(GENOME_STATS_ASSEMBLIES.out.versions)

    if(params.enable_rrna_prediction) {
        ch_infernal_input = ch_assemblies
            | combine(val_rfam_rrna_cm)
            | map { meta, assembly, cmfile -> [ meta, cmfile, assembly ] }

        //
        // MODULE: Identify rRNA genes in the assembly using Infernal
        //
        INFERNAL_CMSEARCH(
            ch_infernal_input,
            false, // write align
            true   // write target
        )
        ch_versions = ch_versions.mix(INFERNAL_CMSEARCH.out.versions)

        ch_rrna_preds = INFERNAL_CMSEARCH.out.target_summary
    } else {
        ch_rrna_preds = Channel.empty()
    }

    emit:
    stats        = GENOME_STATS_ASSEMBLIES.out.stats
    circle_list  = FIND_CIRCLES.out.circles_list
    rrna         = ch_rrna_preds
    versions     = ch_versions
}
