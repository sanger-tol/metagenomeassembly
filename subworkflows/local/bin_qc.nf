include { CHECKM2_DATABASEDOWNLOAD } from '../../modules/nf-core/checkm2/databasedownload/main'
include { CHECKM2_PREDICT          } from '../../modules/nf-core/checkm2/predict/main'
include { SEQKIT_STATS             } from '../../modules/nf-core/seqkit/stats/main'

workflow BIN_QC {
    take:
    bins
    aa_bins

    main:
    ch_versions = Channel.empty()

    if(params.enable_checkm2) {
        if(!params.checkm2_local_db) {
            CHECKM2_DATABASEDOWNLOAD(params.checkm2_db_version)
            ch_checkm2_db = CHECKM2_DATABASEDOWNLOAD.out.database
        } else {
            ch_checkm2_db = Channel.of(
                [ [id: "CheckM2"], file(params.checkm2_local_db) ]
            )
        }

        CHECKM2_PREDICT(aa_bins, ch_checkm2_db)

        ch_versions = ch_versions
            | mix(
                CHECKM2_DATABASEDOWNLOAD.out.versions,
                CHECKM2_PREDICT.out.versions
            )

        ch_checkm2_tsv = CHECKM2_PREDICT.out.checkm2_tsv
    } else {
        ch_checkm2_tsv = Channel.empty()
    }

    SEQKIT_STATS(bins)
    ch_versions = ch_versions.mix(SEQKIT_STATS.out.versions)

    emit:
    checkm2_tsv = ch_checkm2_tsv
    stats       = SEQKIT_STATS.out.stats
    versions    = ch_versions
}
