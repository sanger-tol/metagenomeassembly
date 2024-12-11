include { DASTOOL_DASTOOL                         } from '../../modules/nf-core/dastool/dastool/main'
include { DASTOOL_FASTATOCONTIG2BIN               } from '../../modules/nf-core/dastool/fastatocontig2bin/main'
include { GAWK as GAWK_PROCESS_HMM_TBLOUT         } from '../../modules/nf-core/gawk/main'
include { GAWK as GAWK_MAGSCOT_PROCESS_CONTIG2BIN } from '../../modules/nf-core/gawk/main'
include { GAWK as GAWK_RENAME_DASTOOL_BINS        } from '../../modules/nf-core/gawk/main'
include { HMMER_HMMSEARCH                         } from '../../modules/nf-core/hmmer/hmmsearch/main'
include { CONTIG2BIN2FASTA as MAGSCOT_BINS        } from '../../modules/local/contig2bin2fasta/main'
include { CONTIG2BIN2FASTA as DASTOOL_BINS        } from '../../modules/local/contig2bin2fasta/main'
include { MAGSCOT_MAGSCOT                         } from '../../modules/local/magscot/magscot/main'

workflow BIN_REFINEMENT {
    take:
    assemblies
    proteins
    contig2bin

    main:
    ch_versions           = Channel.empty()
    ch_refined_bins       = Channel.empty()
    ch_refined_contig2bin = Channel.empty()

    if(params.enable_dastool) {
        ch_contig2bins_to_merge = contig2bin
            | map {meta, tsv -> [meta - meta.subMap(['binner']), tsv] }
            | groupTuple(by: 0)

        ch_dastool_input = assemblies
            | combine(ch_contig2bins_to_merge, by: 0)

        ch_proteins_for_dastool = proteins
            | map { it[1] } // pull out faa

        DASTOOL_DASTOOL(
            ch_dastool_input,
            ch_proteins_for_dastool,
            []
        )

        ch_versions = ch_versions.mix(DASTOOL_DASTOOL.out.versions)

        // if das_tool just puts out the original bin it keeps its name
        // this causes downstream input file collisions
        // rename all dastool bins in order
        RENAME_DASTOOL_BINS(DASTOOL_DASTOOL.out.contig2bin, [])

        ch_dastool_bin_input = assemblies
            | combine(RENAME_DASTOOL_BINS.out.output, by: 0)

        ch_refined_contig2bin = ch_refined_contig2bin
            | mix(RENAME_DASTOOL_BINS.out.output)

        // emit dastool bins as fasta
        DASTOOL_BINS(ch_dastool_bin_input, false)

        ch_dastool_bins = DASTOOL_BINS.out.bins
            | map { meta, fasta -> [ meta + [binner: "DASTool"], fasta ]}

        ch_refined_bins = ch_refined_bins.mix(ch_dastool_bins)
        ch_versions = ch_versions
            | mix(
                DASTOOL_DASTOOL.out.versions,
                DASTOOL_BINS.out.versions
            )
    }

    if(params.enable_magscot) {
        ch_magscot_gtdb_hmm_db = Channel.of(
            file(params.hmm_gtdb_pfam),
            file(params.hmm_gtdb_tigrfam)
        )

        ch_hmmsearch_gtdb_input = proteins
            | combine(ch_magscot_gtdb_hmm_db)
            | map { meta, faa, hmmfile ->
                [ meta, hmmfile, faa, false, true, false ]
            }

        HMMER_HMMSEARCH(ch_hmmsearch_gtdb_input)

        ch_hmm_output = HMMER_HMMSEARCH.out.target_summary
            | groupTuple(by: 0)

        PROCESS_HMM_TBLOUT(ch_hmm_output, [])

        // Magscot wants the contig2bin files in reverse order - bin2contig
        MAGSCOT_PROCESS_CONTIG2BIN(
            contig2bin,
            []
        )

        ch_magscot_contig2bin = MAGSCOT_PROCESS_CONTIG2BIN.out.output
            | map { meta, c2b -> [ meta - meta.subMap(['binner']), c2b ] }
            | groupTuple(by: 0)

        ch_magscot_input = PROCESS_HMM_TBLOUT.out.output
            | combine(ch_magscot_contig2bin, by: 0)

        MAGSCOT_MAGSCOT(ch_magscot_input)

        ch_refined_contig2bin = ch_refined_contig2bin
            | mix(MAGSCOT_MAGSCOT.out.contig2bin)

        ch_magscot_contig2bin2fasta_input = assemblies
            | combine(MAGSCOT_MAGSCOT.out.contig2bin, by: 0)

        MAGSCOT_BINS(ch_magscot_contig2bin2fasta_input, false)

        ch_magscot_bins = MAGSCOT_BINS.out.bins
            | map { meta, rbins -> [ meta + [binner: "magscot"], rbins] }

        ch_refined_bins = ch_refined_bins.mix(ch_magscot_bins)

        ch_versions = ch_versions
            | mix(
                HMMER_HMMSEARCH.out.versions,
                PROCESS_HMM_TBLOUT.out.versions,
                MAGSCOT_PROCESS_CONTIG2BIN.out.versions,
                MAGSCOT_MAGSCOT.out.versions,
                MAGSCOT_BINS.out.versions
            )
    }

    emit:
    refined_bins = ch_refined_bins
    contig2bin   = ch_refined_contig2bin
    versions     = ch_versions
}
