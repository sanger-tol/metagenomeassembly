include { CSVTK_CONCAT                  } from '../../../modules/nf-core/csvtk/concat/main'
include { CSVTK_JOIN                    } from '../../../modules/nf-core/csvtk/join/main'
include { GTDBTK_CLASSIFYWF             } from '../../../modules/nf-core/gtdbtk/classifywf/main'
include { GTDBTK_GTDBTONCBIMAJORITYVOTE } from '../../../modules/nf-core/gtdbtk/gtdbtoncbimajorityvote/main'

workflow BIN_TAXONOMY {
    take:
    bin_sets
    checkm2_summary
    gtdbtk_db
    val_enable_gtdbtk
    val_gtdbtk_ar53_metadata
    val_gtdbtk_bac120_metadata

    main:
    ch_gtdb_merged_summary = channel.empty()

    //
    // Logic: GTDB-Tk is memory-intensive and loads a large database.
    // Collate all bins together so it operates in a single process.
    //
    ch_bins = bin_sets
        .map { meta, bins ->
            [meta.subMap("id"), bins]
        }
        .transpose()

    //
    // Logic: GTDB-Tk classifications are only accurate for bins with high
    // completeness and low contamination as it needs a good number
    // of single-copy genes for accurate placement - filter input
    // bins using the checkm2 summary scores.
    //
    // This code is adapted from nf-core/mag
    //
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

    if (val_enable_gtdbtk) {
        //
        // Module: Classify bins using GTDB-Tk
        //
        GTDBTK_CLASSIFYWF(
            ch_filtered_bins,
            gtdbtk_db,
            false,
        )
        ch_gtdb_majorityvote_input = GTDBTK_CLASSIFYWF.out.gtdb_outdir.map { meta, outdir -> [meta, outdir, meta.id] }

        GTDBTK_GTDBTONCBIMAJORITYVOTE(
            ch_gtdb_majorityvote_input,
            [[id: "ar53"], file(val_gtdbtk_ar53_metadata)],
            [[id: "bac120"], file(val_gtdbtk_bac120_metadata)],
        )

        //
        // Module: GTDB-Tk outputs separate summary files for archaea and bacteria - we need
        // to concatenate them
        //
        CSVTK_CONCAT(GTDBTK_CLASSIFYWF.out.summary, "tsv", "tsv")

        //
        // Module: Join NCBI taxonomy tsv to GTDB-Tk taxonomy TSV
        //
        ch_csvtk_join_input = CSVTK_CONCAT.out.csv
            .join(GTDBTK_GTDBTONCBIMAJORITYVOTE.out.tsv)
            .map { meta, gtdb, ncbi -> [meta, [gtdb, ncbi]] }

        CSVTK_JOIN(ch_csvtk_join_input)

        ch_gtdb_merged_summary = CSVTK_JOIN.out.csv
    }

    emit:
    gtdb_summary = ch_gtdb_merged_summary
}
