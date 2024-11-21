include { DASTOOL_FASTATOCONTIG2BIN } from '../../modules/nf-core/dastool/fastatocontig2bin/main'
include { DASTOOL_DASTOOL           } from '../../modules/nf-core/dastool/dastool/main'
include { PYRODIGAL                 } from '../../modules/nf-core/pyrodigal/main'

workflow BIN_REFINEMENT {
    take:
    assemblies
    bins

    main:
    ch_versions     = Channel.empty()
    ch_refined_bins = Channel.empty()

    if(params.enable_dastool) {
        DASTOOL_FASTATOCONTIG2BIN(bins, 'fa')

        ch_contig2bins_to_merge = DASTOOL_FASTATOCONTIG2BIN.out.fastatocontig2bin
            | map {meta, tsv -> [meta.subMap(['id', 'assembler']), tsv] }
            | groupTuple(by: 0)

        ch_dastool_input = assemblies
            | combine(ch_contig2bins_to_merge, by: 0)

        DASTOOL_DASTOOL(ch_dastool_input, [], [])

        ch_versions = ch_versions.mix(
            DASTOOL_FASTATOCONTIG2BIN.out.versions,
            DASTOOL_DASTOOL.out.versions
        )

        ch_dastool_bins = DASTOOL_DASTOOL.out.bins
            | map {meta, fasta -> [ meta + [binner: "DASTool"], fasta ]}

        ch_refined_bins = ch_refined_bins.mix(ch_dastool_bins)
    }

    if(params.enable_magscot) {
        PYRODIGAL(assemblies, 'gff')


    }

    emit:
    refined_bins = ch_refined_bins
    versions     = ch_versions
}
