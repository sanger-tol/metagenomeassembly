include { CMSEARCH_TO_GFF        } from '../../../modules/local/cmsearch_to_gff'
include { GENOMAD_ENDTOEND       } from '../../../modules/nf-core/genomad/endtoend'
include { GFASTATS               } from '../../../modules/nf-core/gfastats'
include { INFERNAL_CMSEARCH      } from '../../../modules/nf-core/infernal/cmsearch'
include { TRNASCANSE             } from '../../../modules/nf-core/trnascanse'
include { TIARA_TIARA            } from '../../../modules/nf-core/tiara/tiara'

workflow ASSEMBLY_ANALYSIS {
    take:
    ch_assemblies
    ch_genomad_db
    val_enable_genomad
    ch_rfam_rrna_cm

    main:
    //
    // Module: Calculate basic assembly statistics
    //
    GFASTATS(ch_assemblies,
        "",
        "",
        "",
        [[],[]],
        [[],[]],
        [[],[]],
        [[],[]],
    )

    //
    // Module: Classify assembled contigs with tiara to domain level
    //
    TIARA_TIARA(ch_assemblies)

    //
    // Module: Run Genomad on the assembly
    //
    GENOMAD_ENDTOEND(
        ch_assemblies.filter { val_enable_genomad },
        ch_genomad_db,
    )

    //
    // Module: Predict tRNAs across a whole assembly
    //
    TRNASCANSE(
        ch_assemblies,
        true,
        false,
        true,
        false
    )

    //
    // Module: Identify rRNA genes in the assembly using Infernal
    //
    ch_infernal_input = ch_assemblies
        .combine(ch_rfam_rrna_cm)
        .map { meta, assembly, cm -> [meta, cm, assembly] }

    INFERNAL_CMSEARCH(
        ch_infernal_input,
        false,
        true,
    )

    CMSEARCH_TO_GFF(INFERNAL_CMSEARCH.out.target_summary.combine(ch_rfam_rrna_cm))

    emit:
    assembly_statistics      = GFASTATS.out.assembly_summary
    tiara_classifications    = TIARA_TIARA.out.classifications
    tiara_log                = TIARA_TIARA.out.log
    genomad_results          = GENOMAD_ENDTOEND.out.genomad_results
    trna_tsv                 = TRNASCANSE.out.tsv
    trna_gff                 = TRNASCANSE.out.gff
    trna_log                 = TRNASCANSE.out.log
    trna_stats               = TRNASCANSE.out.stats
    rrna_gff                 = CMSEARCH_TO_GFF.out.gff
}
