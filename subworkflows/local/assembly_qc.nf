include { SEQKIT_STATS as SEQKIT_STATS_ASSEMBLIES } from '../../modules/nf-core/seqkit/stats/main'
include { INFERNAL_CMSEARCH                       } from '../../modules/local/infernal/cmsearch/main'

workflow ASSEMBLY_QC {
    take:
    assemblies // [meta, assembly.fa.gz]

    main:
    ch_versions = Channel.empty()

    SEQKIT_STATS_ASSEMBLIES(assemblies)
    ch_versions = ch_versions.mix(SEQKIT_STATS_ASSEMBLIES.out.versions)

    if(params.enable_rrna_prediction) {
        ch_infernal_input = assemblies
            | map { meta, contigs ->
                def cmfile = file("${baseDir}/assets/rRNA.cm")
                [ meta, cmfile, contigs, false, true ]
            }

        INFERNAL_CMSEARCH(ch_infernal_input)
        ch_rrna_preds = INFERNAL_CMSEARCH.out.target_summary
    } else {
        ch_rrna_preds = Channel.empty()
    }

    emit:
    stats    = SEQKIT_STATS_ASSEMBLIES.out.stats
    rrna     = ch_rrna_preds
    versions = ch_versions
}
