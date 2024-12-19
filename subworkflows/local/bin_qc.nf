include { CHECKM2_DATABASEDOWNLOAD    } from '../../modules/nf-core/checkm2/databasedownload/main'
include { CHECKM2_PREDICT             } from '../../modules/nf-core/checkm2/predict/main'
include { SEQKIT_STATS                } from '../../modules/nf-core/seqkit/stats/main'
include { PROKKA                      } from '../../modules/nf-core/prokka/main'
include { GAWK as GAWK_PROKKA_SUMMARY } from '../../modules/nf-core/gawk/main'

workflow BIN_QC {
    take:
    bin_sets
    bins

    main:
    ch_versions = Channel.empty()

    SEQKIT_STATS(bin_sets)
    ch_versions = ch_versions.mix(SEQKIT_STATS.out.versions)

    if(params.enable_checkm2) {
        if(!params.checkm2_local_db) {
            CHECKM2_DATABASEDOWNLOAD(params.checkm2_db_version)
            ch_checkm2_db = CHECKM2_DATABASEDOWNLOAD.out.database
        } else {
            ch_checkm2_db = Channel.of(
                [ [id: "CheckM2"], file(params.checkm2_local_db) ]
            )
        }

        CHECKM2_PREDICT(bin_sets, ch_checkm2_db)

        ch_versions = ch_versions
            | mix(
                CHECKM2_DATABASEDOWNLOAD.out.versions,
                CHECKM2_PREDICT.out.versions
            )

        ch_checkm2_tsv = CHECKM2_PREDICT.out.checkm2_tsv
    } else {
        ch_checkm2_tsv = Channel.empty()
    }

    if(params.enable_prokka) {
        PROKKA(bins, [], [])
        ch_versions = ch_versions.mix(PROKKA.out.versions)

        ch_prokka_tsvs = PROKKA.out.tsv
            | map { meta, tsv ->
                def group = ["id", "assembler", "binner"]
                meta_new = params.collate_bins ? [id: meta.id, assembler: "all", binner: "all"] : meta.subMap(group)
                [ meta_new, tsv ]
            }
            | groupTuple(by: 0)

        GAWK_PROKKA_SUMMARY(ch_prokka_tsvs, file("${baseDir}/bin/prokka_summary.awk"))
        ch_versions = ch_versions.mix(GAWK_PROKKA_SUMMARY.out.versions)

        ch_prokka_summary = GAWK_PROKKA_SUMMARY.out.output
    } else {
        ch_prokka_summary = Channel.empty()
    }

    emit:
    stats          = SEQKIT_STATS.out.stats
    checkm2_tsv    = ch_checkm2_tsv
    prokka_summary = ch_prokka_summary
    versions       = ch_versions
}
