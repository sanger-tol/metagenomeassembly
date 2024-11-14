include { PYRODIGAL } from '../../modules/nf-core/pyrodigal/main'

workflow GENE_PREDICTION {
    take:
    assemblies

    main:
    ch_versions = Channel.empty()

    PYRODIGAL(assemblies)

    emit:
    versions = ch_versions
}