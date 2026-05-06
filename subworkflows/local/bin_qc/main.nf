include { BINSUMMARIES_RRNA                 } from '../../../modules/local/binsummaries/rrna/main'
include { BINSUMMARIES_TRNA                 } from '../../../modules/local/binsummaries/trna/main'
include { CHECKM2_PREDICT                   } from '../../../modules/nf-core/checkm2/predict/main'
include { COVERM_GENOME                     } from '../../../modules/nf-core/coverm/genome/main'
include { GENOME_STATS as GENOME_STATS_BINS } from '../../../modules/local/genome_stats/main'
include { GAWK as GAWK_TRNASCAN_SUMMARY     } from '../../../modules/nf-core/gawk/main'
include { INFERNAL_CMSEARCH                 } from '../../../modules/nf-core/infernal/cmsearch'
include { TRNASCANSE                        } from '../../../modules/nf-core/trnascanse'

workflow BIN_QC {
    take:
    ch_assemblies
    ch_bin_sets
    ch_contig2bin
    ch_circular_list
    ch_mapped_bam
    ch_checkm2_db
    val_enable_checkm2
    ch_rfam_rrna_cm
    val_rrna_prediction
    val_enable_trnascanse

    main:
    //
    // Module: Calculate bin statistics, including counts of circles
    //
    ch_genome_stats_input = ch_bin_sets
        .map { meta, bins ->
            def meta_join = meta.subMap(["id", "assembler"])
            [meta_join, meta, bins]
        }
        .combine(ch_circular_list, by: 0)
        .map { _meta_join, meta, bins, circles -> [meta, bins, circles] }

    GENOME_STATS_BINS(ch_genome_stats_input)

    //
    // Module: Calculate the coverage of bins using coverm genome
    //
    ch_coverm_genome_input = ch_bin_sets
        .map { meta, bins ->
            def meta_join = meta.subMap(["id", "assembler"])
            [meta_join, meta, bins]
        }
        .combine(ch_mapped_bam, by: 0)
        .multiMap { _meta_join, meta, bins, bam ->
            bam: [meta, bam]
            bins: [meta, bins]
        }

    COVERM_GENOME(
        ch_coverm_genome_input.bam,
        ch_coverm_genome_input.bins,
        true,
        false,
        "file",
        false
    )

    ch_checkm2_tsv = channel.empty()
    if (val_enable_checkm2) {
        //
        // Logic: Collate all bins together so CheckM2 operates in a single process.
        //
        ch_bins_for_checkm = ch_bin_sets
            .map { meta, bins ->
                [meta.subMap("id"), bins]
            }
            .transpose()
            .groupTuple(by: 0)

        //
        // Module: Estimate bin completeness/contamination using CheckM2
        //
        CHECKM2_PREDICT(ch_bins_for_checkm, ch_checkm2_db)
        ch_checkm2_tsv = CHECKM2_PREDICT.out.checkm2_tsv
    }

    //
    // Module: Predict tRNAs using tRNAScan-SE
    //
    if(val_enable_trnascanse) {
        //
        // Module: Predict tRNAs across a whole assembly
        //
        TRNASCANSE(
            ch_assemblies,
        )

        //
        // Module: Summarise tRNA results for each bin
        //
        ch_trnascan_summary_input = ch_contig2bin
            .map { meta, c2b ->
                def meta_join = meta.subMap(["id", "assembler"])
                [meta_join, meta, c2b]
            }
            .combine(ch_assembly_trnascanse_tbl, by: 0)
            .map { _meta_join, meta, c2b, trna -> [meta, c2b, trna] }

        BINSUMMARIES_TRNA(ch_trnascan_summary_input)
    }

    if (val_rrna_prediction) {
        //
        // Module: Identify rRNA genes in the assembly using Infernal
        //
        ch_infernal_input = ch_assemblies
            .combine(ch_rfam_rrna_cm)
            .map { meta, assembly, cm -> [meta, cm, assembly] }

        INFERNAL_CMSEARCH(
            ch_infernal_input,
            false,
            true,
        )

        //
        // Module: Summarise rRNA results for each bin
        //
        ch_rrna_summary_input = ch_contig2bin
            .map { meta, c2b ->
                def meta_join = meta.subMap(["id", "assembler"])
                [meta_join, meta, c2b]
            }
            .combine(ch_assembly_rrna_tbl, by: 0)
            .map { _meta_join, meta, c2b, rrna -> [meta, c2b, rrna] }

        BINSUMMARIES_RRNA(ch_rrna_summary_input)
    }

    emit:
    stats            = GENOME_STATS_BINS.out.stats
    coverage         = COVERM_GENOME.out.coverage
    checkm2_tsv      = ch_checkm2_tsv
    trnascan_summary = BINSUMMARIES_TRNA.out.tsv
    rrna_summary     = BINSUMMARIES_RRNA.out.tsv
}
