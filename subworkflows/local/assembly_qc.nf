include { FIND_CIRCLES                            } from '../../modules/local/find_circles/main'
include { GENOME_STATS as GENOME_STATS_ASSEMBLIES } from '../../modules/local/genome_stats/main'
include { INFERNAL_CMSEARCH                       } from '../../modules/local/infernal/cmsearch/main'

workflow ASSEMBLY_QC {
    take:
    assemblies // [meta, assembly.fa.gz]

    main:
    ch_versions = Channel.empty()

    FIND_CIRCLES(assemblies)
    ch_versions = ch_versions.mix(FIND_CIRCLES.out.versions)

    ch_genome_stats_input = assemblies
        | combine(FIND_CIRCLES.out.circles, by: 0)

    GENOME_STATS_ASSEMBLIES(ch_genome_stats_input)
    ch_versions = ch_versions.mix(GENOME_STATS_ASSEMBLIES.out.versions)

    if(params.enable_rrna_prediction) {
        ch_infernal_input = assemblies
            | map { meta, contigs ->
                def cmfile = file("${baseDir}/assets/rRNA.cm")
                [ meta, cmfile, contigs, false, true ]
            }

        INFERNAL_CMSEARCH(ch_infernal_input)
        ch_versions = ch_versions.mix(INFERNAL_CMSEARCH.out.versions)
        ch_rrna_preds = INFERNAL_CMSEARCH.out.target_summary
    } else {
        ch_rrna_preds = Channel.empty()
    }

    emit:
    stats        = GENOME_STATS_ASSEMBLIES.out.stats
    circle_list  = FIND_CIRCLES.out.circles
    rrna         = ch_rrna_preds
    versions     = ch_versions
}
