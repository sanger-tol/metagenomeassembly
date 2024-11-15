include { GAWK as MAXBIN2_DEPTHS } from '../../modules/nf-core/gawk/main'
include { METABAT2_METABAT2      } from '../../modules/nf-core/metabat2/metabat2/main'
include { MAXBIN2                } from '../../modules/nf-core/maxbin2/main'
include { BIN3C_MKMAP            } from '../../modules/local/bin3c/mkmap/main.nf'
include { BIN3C_CLUSTER          } from '../../modules/local/bin3c/cluster/main.nf'

workflow BINNING {
    take:
    assemblies
    pacbio_depths
    hic_bam
    hic_enzymes

    main:
    ch_versions = Channel.empty()
    ch_bins     = Channel.empty()

    // join assembly and depths together
    if(params.enable_metabat2) {
        ch_metabat_input = assemblies
            | combine(pacbio_depths, by: 0)

        METABAT2_METABAT2(ch_metabat_input)
        ch_versions = ch_versions.mix(METABAT2_METABAT2.out.versions)

        ch_metabat2_bins =  METABAT2_METABAT2.out.fasta
            | map { meta, fasta ->
                def meta_new = meta + [binner: "METABAT2"]
                [meta_new, fasta]
            }
        ch_bins = ch_bins.mix(ch_metabat2_bins)
    }

    if(params.enable_maxbin2) {
        MAXBIN2_DEPTHS(pacbio_depths, [])

        ch_maxbin2_input = assemblies
            | combine(MAXBIN2_DEPTHS.out.output, by: 0)
            | map { meta, contigs, depths ->
                [meta, contigs, [], depths]
            }

        MAXBIN2(ch_maxbin2_input)

        ch_versions = ch_versions.mix(
            MAXBIN2_DEPTHS.out.versions,
            MAXBIN2.out.versions
        )

        ch_maxbin2_bins =  MAXBIN2.out.binned_fastas
            | map { meta, fasta ->
                def meta_new = meta + [binner: "MAXBIN2"]
                [meta_new, fasta]
            }
        ch_bins = ch_bins.mix(ch_maxbin2_bins)
    }

    if(params.enable_bin3c) {
        ch_bin3c_mkmap_input = assemblies
            | combine(hic_bam, by: 0)

        BIN3C_MKMAP(ch_bin3c_mkmap_input, hic_enzymes)

        ch_bin3c_cluster_input = assemblies
            | combine(BIN3C_MKMAP.out.map, by: 0)

        BIN3C_CLUSTER(ch_bin3c_cluster_input)

        ch_versions = ch_versions.mix(
            BIN3C_MKMAP.out.versions,
            BIN3C_CLUSTER.out.versions
        )

        ch_bin3c_bins =  BIN3C_CLUSTER.out.fasta
            | map { meta, fasta ->
                def meta_new = meta + [binner: "BIN3C"]
                [meta_new, fasta]
            }
        ch_bins = ch_bins.mix(ch_bin3c_bins)
    }

    emit:
    bins     = ch_bins
    versions = ch_versions
}
