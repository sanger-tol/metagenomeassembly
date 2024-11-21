include { BIN3C_MKMAP                      } from '../../modules/local/bin3c/mkmap/main.nf'
include { BIN3C_CLUSTER                    } from '../../modules/local/bin3c/cluster/main.nf'
include { MAXBIN2                          } from '../../modules/nf-core/maxbin2/main'
include { GAWK as MAXBIN2_DEPTHS           } from '../../modules/nf-core/gawk/main'
include { METABAT2_METABAT2                } from '../../modules/nf-core/metabat2/metabat2/main'
include { METATOR_PIPELINE                 } from '../../modules/local/metator/pipeline/main'

workflow BINNING {
    take:
    assemblies      // channel: [[meta], contigs]
    pacbio_depths   // channel: [[meta], depths_file]
    hic_reads       // channel: [[meta], [r1, r2]]
    hic_bam         // channel: [[meta], bam]
    hic_enzymes     // channel: [enz1, enz2], value

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
            | map { meta, fasta -> [meta + [binner: "MetaBat2"], fasta] }
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
            | map { meta, fasta -> [meta + [binner: "MaxBin2"], fasta] }
        ch_bins = ch_bins.mix(ch_maxbin2_bins)
    }

    // Bin3C is not available in conda - only run if we are not running with the conda profile
    if(params.enable_bin3c && !(workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1)) {
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
            | map { meta, fasta -> [meta + [binner: "Bin3C"], fasta] }
        ch_bins = ch_bins.mix(ch_bin3c_bins)
    }

    if(params.enable_metator) {
        ch_assemblies_combine = assemblies
            | map {meta, contigs -> [ meta.subMap('id'), meta, contigs ]}

        ch_metator_input = ch_assemblies_combine
            | combine(hic_reads, by: 0)
            | map { meta_join, meta_assembly, contigs, hic -> [meta_assembly, contigs, hic]}
            | combine(pacbio_depths, by: 0)

        METATOR_PIPELINE(ch_metator_input, hic_enzymes)

        ch_versions = ch_versions.mix(
            METATOR_PIPELINE.out.versions
        )

        ch_metator_bins =  METATOR_PIPELINE.out.bins
            | map { meta, fasta -> [meta + [binner: "Metator"], fasta] }
        ch_bins = ch_bins.mix(ch_metator_bins)

    }

    emit:
    bins     = ch_bins
    versions = ch_versions
}
