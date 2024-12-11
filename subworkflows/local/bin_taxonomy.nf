include { GTDBTK_CLASSIFYWF               } from '../../modules/nf-core/gtdbtk/classifywf/main'
include { GAWK as GAWK_EXTRACT_NCBI_NAMES } from '../../modules/nf-core/gawk/main'
include { TAXONKIT_NAME2TAXID             } from '../../modules/nf-core/taxonkit/name2taxid/main'

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
        ch_versions      = ch_versions.mix(GTDBTK_CLASSIFYWF.out.versions)
        ch_gtdb_summary  = ch_gtdb_summary.mix(GTDBTK_CLASSIFYWF.out.summary)

        if(params.ncbi_taxonomy_dir){
            GAWK_EXTRACT_NCBI_NAMES(ch_gtdb_ncbi, file("${baseDir}/assets/extract_ncbi_name.awk"))

            ch_gtdb_ncbi_for_taxonkit = GTDBTK_CLASSIFYWF.out.ncbi
                | map { meta, tsv -> [ meta, [], tsv ] }

            TAXONKIT_NAME2TAXID(
                ch_gtdb_ncbi_for_taxonkit,
                file(params.ncbi_taxonomy_dir)
            )

            ch_gtdb_ncbi = ch_gtdb_ncbi.mix(TAXONKIT_NAME2TAXID.out.tsv)

            ch_versions = ch_versions
                | mix(
                    GAWK_EXTRACT_NCBI_NAMES.out.versions,
                    TAXONKIT_NAME2TAXID.out.versions
                )
        } else {
            ch_gtdb_ncbi = ch_gtdb_ncbi.mix(GTDBTK_CLASSIFYWF.out.ncbi)
        }
    }

    emit:
    gtdb_summary = ch_gtdb_summary
    gtdb_ncbi    = ch_gtdb_ncbi
    versions     = ch_versions
}
