include { GENOMAD_ENDTOEND                        } from '../../../modules/nf-core/genomad/endtoend'
include { GENOME_STATS as GENOME_STATS_ASSEMBLIES } from '../../../modules/local/genome_stats'
include { INFERNAL_CMSEARCH                       } from '../../../modules/nf-core/infernal/cmsearch'
include { TRNASCANSE                              } from '../../../modules/nf-core/trnascanse'

workflow ASSEMBLY_QC {
    take:
    ch_assemblies // [meta, assembly.fa.gz]
    ch_circular_list
    val_enable_genomad
    ch_genomad_db
    val_rrna_prediction
    ch_rfam_rrna_cm
    val_enable_trnascanse

    main:
    //
    // Module: Calculate assembly statistics, including counts of circles
    //
    GENOME_STATS_ASSEMBLIES(ch_assemblies.combine(ch_circular_list, by: 0))

    //
    // Module: Classify circular contigs using genomad
    //
    GENOMAD_ENDTOEND(
        ch_assemblies.filter { val_enable_genomad },
        ch_genomad_db,
    )

    //
    // Module: Identify rRNA genes in the assembly using Infernal
    //
    ch_infernal_input = ch_assemblies
        .combine(ch_rfam_rrna_cm)
        .map { meta, assembly, cm -> [meta, cm, assembly] }

    INFERNAL_CMSEARCH(
        ch_infernal_input.filter { val_rrna_prediction },
        false,
        true,
    )

    //
    // Module: Predict tRNAs using tRNAScan-SE
    //
    TRNASCANSE(
        ch_assemblies.filter { val_enable_trnascanse },
    )

    emit:
    stats                   = GENOME_STATS_ASSEMBLIES.out.stats
    genomad_plasmid_summary = GENOMAD_ENDTOEND.out.plasmid_summary
    rrna_summary            = INFERNAL_CMSEARCH.out.target_summary
    trna_summary            = TRNASCANSE.out.tsv
}
