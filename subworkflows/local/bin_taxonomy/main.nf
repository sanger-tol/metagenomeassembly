include { CSVTK_CONCAT                  } from '../../../modules/nf-core/csvtk/concat/main'
include { CSVTK_JOIN                    } from '../../../modules/nf-core/csvtk/join/main'
include { GTDBTK_CLASSIFYWF             } from '../../../modules/nf-core/gtdbtk/classifywf/main'
include { GTDBTK_GTDBTONCBIMAJORITYVOTE } from '../../../modules/nf-core/gtdbtk/gtdbtoncbimajorityvote/main'

workflow BIN_TAXONOMY {
    take:
    bin_sets
    checkm2_summary
    gtdbtk_db

    main:
    ch_versions = channel.empty()
    ch_gtdb_merged_summary = channel.empty()

    // GTDB-Tk is memory-intensive and loads a large database.
    // Collate all bins together so it operates in a single process.
    ch_bins = bin_sets
        .map { meta, bins ->
            [meta.subMap("id"), bins]
        }
        .transpose()

    //
    // LOGIC: GTDB-Tk classifications are only accurate for bins with high
    //        completeness and low contamination as it needs a good number
    //        of single-copy genes for accurate placement - filter input
    //        bins using the checkm2 summary scores.
    //
    //        This code is adapted from nf-core/mag
    if (checkm2_summary) {
        ch_bin_scores = checkm2_summary
            .splitCsv(header: true, sep: '\t')
            .map { _meta, row ->
                def completeness = Double.parseDouble(row.'Completeness')
                def contamination = Double.parseDouble(row.'Contamination')
                [row.'Name', completeness, contamination]
            }

        ch_filtered_bins = ch_bins
            .map { meta, bin ->
                // Need to explicitly remove fasta extension as getSimpleName() drops parts
                // of bin names where they contain .s
                def bin_name = bin.getName() - ~/\.fn?a(sta)?\.gz$/
                [bin_name, bin, meta]
            }
            .join(ch_bin_scores, failOnDuplicate: true)
            .filter { _bin_name, _bin, _meta, completeness, contamination ->
                completeness >= params.gtdbtk_min_completeness && contamination <= params.gtdbtk_max_contamination
            }
            .map { _bin_name, bin, meta, _completeness, _contamination ->
                [meta, bin]
            }
            .groupTuple(by: 0)
    }
    else {
        ch_filtered_bins = ch_bins.groupTuple(by: 0)
    }

    if (params.enable_gtdbtk && params.gtdbtk_db) {
        //
        // MODULE: Classify bins using GTDB-Tk
        //
        GTDBTK_CLASSIFYWF(
            ch_filtered_bins,
            gtdbtk_db,
            false,
        )
        ch_gtdb_summary = GTDBTK_CLASSIFYWF.out.summary

        ch_gtdb_majorityvote_input = GTDBTK_CLASSIFYWF.out.gtdb_outdir.map { meta, outdir -> [meta, outdir, meta.id] }

        GTDBTK_GTDBTONCBIMAJORITYVOTE(
            ch_gtdb_majorityvote_input,
            [[id: "ar53"], file(params.gtdb_ar53_metadata)],
            [[id: "bac120"], file(params.gtdb_bac120_metadata)],
        )
        ch_versions = ch_versions.mix(GTDBTK_GTDBTONCBIMAJORITYVOTE.out.versions)

        //
        // MODULE: GTDB-Tk outputs separate summary files for archaea and bacteria - we need
        // to concatenate them
        //
        CSVTK_CONCAT(ch_gtdb_summary, "tsv", "tsv")
        ch_versions = ch_versions.mix(CSVTK_CONCAT.out.versions)

        //
        // MODULE: Join NCBI taxonomy tsv to GTDB-Tk taxonomy TSV
        //
        ch_csvtk_join_input = CSVTK_CONCAT.out.csv
            .join(GTDBTK_GTDBTONCBIMAJORITYVOTE.out.tsv)
            .map { meta, gtdb, ncbi -> [meta, [gtdb, ncbi]] }

        CSVTK_JOIN(ch_csvtk_join_input)
        ch_versions = ch_versions.mix(CSVTK_JOIN.out.versions)

        ch_gtdb_merged_summary = CSVTK_JOIN.out.csv
    }

    emit:
    gtdb_summary = ch_gtdb_merged_summary
    versions     = ch_versions
}
