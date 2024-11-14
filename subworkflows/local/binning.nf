include { METABAT2_METABAT2 } from '../../modules/nf-core/metabat2/metabat2/main'

workflow BINNING {
    take:
    assemblies
    pacbio_depths
    hic_bam

    main:
    ch_versions = Channel.empty()

    // join assembly and depths together
    ch_metabat_input = assemblies
        | combine(pacbio_depths, by: 0)

    METABAT2_METABAT2(
        ch_metabat_input
    )

    emit:
    versions = ch_versions
}
