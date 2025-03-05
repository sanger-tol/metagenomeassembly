include { GTDBTK_CLASSIFYWF               } from '../../../modules/nf-core/gtdbtk/classifywf/main'
include { GAWK as GAWK_EXTRACT_NCBI_NAMES } from '../../../modules/nf-core/gawk/main'
include { TAXONKIT_NAME2TAXID             } from '../../../modules/nf-core/taxonkit/name2taxid/main'

workflow BIN_TAXONOMY {
    take:
    bin_sets
    checkm2_summary
    gtdbtk_db
    gtdbtk_mash_db

    main:
    ch_versions     = Channel.empty()
    ch_gtdb_summary = Channel.empty()
    ch_gtdb_ncbi    = Channel.empty()

    // GTDB-Tk is memory-intensive and loads a large database.
    // Collate all bins together so it operates in a single process.
    ch_bins = bin_sets
        | map { meta, bins ->
            [ meta.subMap("id"), bins]
        }
        | transpose

    //
    // LOGIC: GTDB-Tk classifications are only accurate for bins with high
    //        completeness and low contamination as it needs a good number
    //        of single-copy genes for accurate placement - filter input
    //        bins using the checkm2 summary scores.
    //
    //        This code is adapted from nf-core/mag
    if(checkm2_summary) {
        ch_bin_scores = checkm2_summary
            | splitCsv(header: true, sep: '\t')
            | map { _meta, row ->
                def completeness  = Double.parseDouble(row.'Completeness')
                def contamination = Double.parseDouble(row.'Contamination')
                [row.'Name', completeness, contamination]
            }

        ch_filtered_bins = ch_bins
            | map { meta, bin -> [bin.getSimpleName(), bin, meta]}
            | join(ch_bin_scores, failOnDuplicate: true)
            | filter { // it[3] = completeness, it[4] = contamination
                it[3] >= params.gtdbtk_min_completeness && it[4] <= params.gtdbtk_max_contamination
            }
            | map { [ it[2], it[1] ] } // [meta, bin]
            | groupTuple(by: 0)
    } else {
        ch_filtered_bins = ch_bins
            | groupTuple(by: 0)
    }

    if(params.enable_gtdbtk && params.gtdbtk_db) {
        //
        // MODULE: Classify bins using GTDB-Tk
        //
        GTDBTK_CLASSIFYWF(
            ch_filtered_bins,
            gtdbtk_db,
            false,
            gtdbtk_mash_db,
            file(params.gtdb_bac120_metadata),
            file(params.gtdb_ar53_metadata)
        )
        ch_versions      = ch_versions.mix(GTDBTK_CLASSIFYWF.out.versions)
        ch_gtdb_summary  = ch_gtdb_summary.mix(GTDBTK_CLASSIFYWF.out.summary)

        if(params.ncbi_taxonomy_dir){
            //
            // MODULE: Extract the NCBI names from the GTDB-Tk summary file
            //
            GAWK_EXTRACT_NCBI_NAMES(GTDBTK_CLASSIFYWF.out.ncbi, file("${baseDir}/bin/extract_ncbi_name.awk"), false)
            ch_versions = ch_versions.mix(GAWK_EXTRACT_NCBI_NAMES.out.versions)

            ch_gtdb_ncbi_for_taxonkit = GAWK_EXTRACT_NCBI_NAMES.out.output
                | map { meta, tsv -> [ meta, [], tsv ] }

            //
            // MODULE: Get taxids for these names
            //
            TAXONKIT_NAME2TAXID(
                ch_gtdb_ncbi_for_taxonkit,
                file(params.ncbi_taxonomy_dir)
            )
            ch_versions = ch_versions.mix(TAXONKIT_NAME2TAXID.out.versions)

            ch_gtdb_ncbi = ch_gtdb_ncbi.mix(TAXONKIT_NAME2TAXID.out.tsv)
        } else {
            ch_gtdb_ncbi = ch_gtdb_ncbi.mix(GTDBTK_CLASSIFYWF.out.ncbi)
        }
    }

    emit:
    gtdb_summary = ch_gtdb_summary
    gtdb_ncbi    = ch_gtdb_ncbi
    versions     = ch_versions
}
