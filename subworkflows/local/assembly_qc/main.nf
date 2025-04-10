include { FIND_CIRCLES                            } from '../../../modules/local/find_circles/main'
include { GENOMAD_DOWNLOAD                        } from '../../../modules/nf-core/genomad/download'
include { GENOMAD_ENDTOEND                        } from '../../../modules/nf-core/genomad/endtoend'
include { GENOME_STATS as GENOME_STATS_ASSEMBLIES } from '../../../modules/local/genome_stats/main'
include { GZIP_GET_DECOMPRESSED_SIZE              } from '../../../modules/local/gzip_get_decompressed_size/main'
include { INFERNAL_CMSEARCH                       } from '../../../modules/local/infernal/cmsearch/main'

workflow ASSEMBLY_QC {
    take:
    assemblies // [meta, assembly.fa.gz]
    rfam_rrna_cm
    genomad_db

    main:
    ch_versions = Channel.empty()

    //
    // MODULE: Identify which contigs are circular
    //
    FIND_CIRCLES(assemblies)
    ch_versions = ch_versions.mix(FIND_CIRCLES.out.versions)

    ch_genome_stats_input = assemblies
        | combine(FIND_CIRCLES.out.circles_list, by: 0)

    //
    // MODULE: Classify circular contigs using genomad
    //

    if(params.enable_genomad) {
        if(!params.genomad_db){
            GENOMAD_DOWNLOAD()
            ch_versions = ch_versions.mix(GENOMAD_DOWNLOAD.versions)

            ch_genomad_db = GENOMAD_DOWNLOAD.out.genomad_db
        } else {
            ch_genomad_db = genomad_db
        }

        GENOMAD_ENDTOEND(
            FIND_CIRCLES.out.circles_fasta,
            ch_genomad_db
        )
        ch_versions = ch_versions.mix(GENOMAD_ENDTOEND.versions)
    }

    //
    // MODULE: Calculate assembly statistics, including counts of circles
    //
    GENOME_STATS_ASSEMBLIES(ch_genome_stats_input)
    ch_versions = ch_versions.mix(GENOME_STATS_ASSEMBLIES.out.versions)

    if(params.enable_rrna_prediction) {
        ch_infernal_input = assemblies
            | combine(rfam_rrna_cm)
            | map { meta, contigs, cmfile ->
                [ meta, cmfile, contigs, false, true ]
            }

        //
        // MODULE: Identify rRNA genes in the assembly using Infernal
        //
        INFERNAL_CMSEARCH(ch_infernal_input)
        ch_versions = ch_versions.mix(INFERNAL_CMSEARCH.out.versions)
        ch_rrna_preds = INFERNAL_CMSEARCH.out.target_summary
    } else {
        ch_rrna_preds = Channel.empty()
    }

    //
    // MODULE: To aid in setting resource requirements, get the decompressed
    // size of the assembly using gzip -l, and add it to the meta map as
    // meta.decompressed size
    //
    GZIP_GET_DECOMPRESSED_SIZE(assemblies)
    ch_versions = ch_versions.mix(GZIP_GET_DECOMPRESSED_SIZE.out.versions)

    //
    // LOGIC: Attach decompresed filesize and assembly length to meta object
    //
    ch_stats = GENOME_STATS_ASSEMBLIES.out.stats
        | splitCsv(header: true, sep: '\t')
        | map { meta, row ->
            [ meta, row.sum_len, row.N50 ]
        }

    ch_assemblies = assemblies
        | combine(ch_stats, by: 0)
        | combine(GZIP_GET_DECOMPRESSED_SIZE.out.fasta_with_size, by: 0)
        | map { meta, assembly, len, n50, size ->
            def meta_new = meta + [ length: len.toLong(), n50: n50.toLong(), size: size.toLong() ]
            [ meta_new, assembly ]
        }

    emit:
    assemblies   = ch_assemblies
    stats        = GENOME_STATS_ASSEMBLIES.out.stats
    circle_list  = FIND_CIRCLES.out.circles
    rrna         = ch_rrna_preds
    versions     = ch_versions
}
