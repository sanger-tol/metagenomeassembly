include { GTDBTK_CLASSIFYWF } from '../../modules/nf-core/gtdbtk/classifywf/main'

workflow BIN_TAXONOMY {
    take:
    bins
    checkm2_summary

    main:
    ch_versions     = Channel.empty()
    ch_gtdb_summary = Channel.empty()
    ch_gtdb_ncbi    = Channel.empty()

    // this code modified from nf-core/mag
    if(checkm2_summary) {
        ch_bin_scores = checkm2_summary
            | splitCsv(header: true, sep: '\t')
            | map { meta, row ->
                def completeness  = Double.parseDouble(row.'Completeness')
                def contamination = Double.parseDouble(row.'Contamination')
                [row.'Name' + ".fa", completeness, contamination]
            }

        ch_filtered_bins = bins
            | transpose()
            | map { meta, bin -> [bin.getName(), bin, meta]}
            | join(ch_bin_scores, failOnDuplicate: true)
            | filter { // it[3] = completeness, it[4] = contamination
                it[3] >= params.gtdbtk_min_completeness && it[4] <= params.gtdbtk_max_contamination
            }
            | map { [ it[2], it[1] ] } // [meta, bin]
            | groupTuple(by: 0)
    } else {
        ch_filtered_bins = bins
    }

    if(params.enable_gtdbtk && params.gtdbtk_db) {
        ch_gtdbtk_db = Channel.of(file(params.gtdbtk_db, checkIfExists: true).listFiles())
            | collect | map { ["gtdb", it] }
        ch_gtdb_bac120_metadata = params.gtdb_bac120_metadata ? Channel.of(file(params.gtdb_bac120_metadata)) : []
        ch_gtdb_ar53_metadata = params.gtdb_ar53_metadata ? Channel.of(file(params.gtdb_ar53_metadata)) : []

        GTDBTK_CLASSIFYWF(
            ch_filtered_bins,
            ch_gtdbtk_db,
            false,
            [],
            ch_gtdb_bac120_metadata,
            ch_gtdb_ar53_metadata
        )
        ch_versions     = ch_versions.mix(GTDBTK_CLASSIFYWF.out.versions)
        ch_gtdb_summary = ch_gtdb_summary.mix(GTDBTK_CLASSIFYWF.out.summary)
        ch_gtdb_ncbi    = ch_gtdb_ncbi.mix(GTDBTK_CLASSIFYWF.out.ncbi)
    }

    emit:
    gtdb_summary = ch_gtdb_summary
    gtdb_ncbi    = ch_gtdb_ncbi
    versions     = ch_versions
}
