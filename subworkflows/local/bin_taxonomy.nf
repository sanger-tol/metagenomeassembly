include { GTDBTK_CLASSIFYWF } from '../../modules/nf-core/gtdbtk/classifywf/main'

workflow BIN_TAXONOMY {
    take:
    bins
    // checkm2_summary

    main:
    ch_versions = Channel.empty()

    // ch_bin_scores = checkm2_summary
    //     | splitCsv(header: true, sep: '\t')
    //     | map { row ->
    //         def completeness  = Double.parseDouble(row.'Completeness')
    //         def contamination = Double.parseDouble(row.'Contamination')
    //         [row.'Bin Id' + ".fa", completeness, contamination]
    //     }

    if(params.enable_gtdbtk && params.gtdbtk_db) {
        GTDBTK_CLASSIFYWF(
            bins,
            ["GTDBTk", file(params.gtdbtk_db)],
            false,
            file(params.gtdbtb_mash_db)
        )
        ch_versions = ch_versions.mix(GTDBTK_CLASSIFYWF.out.versions)
    }

    emit:
    versions = ch_versions
}
