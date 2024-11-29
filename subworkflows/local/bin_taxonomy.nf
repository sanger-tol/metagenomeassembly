include { GTDBTK_CLASSIFYWF } from '../../modules/nf-core/gtdbtk/classifywf/main'

workflow BIN_TAXONOMY {
    take:
    bins
    checkm2_summary

    main:
    ch_versions = Channel.empty()

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
        gtdbtk_db = Channel.of(file(params.gtdbtk_db, checkIfExists: true).listFiles())
            | collect | map { ["gtdb" ,it] }
        gtdbtk_mash = params.gtdbtk_mash_db ? file(params.gtdbtk_mash_db, checkIfExists: true) : []

        GTDBTK_CLASSIFYWF(
            ch_filtered_bins,
            gtdbtk_db,
            false,
            gtdbtk_mash
        )
        ch_versions = ch_versions.mix(GTDBTK_CLASSIFYWF.out.versions)
    }

    emit:
    versions = ch_versions
}
