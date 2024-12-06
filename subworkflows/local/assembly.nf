include { METAMDBG_ASM } from '../../modules/nf-core/metamdbg/asm/main'
include { PYRODIGAL    } from '../../modules/nf-core/pyrodigal/main'

workflow ASSEMBLY {
    take:
    hifi_reads

    main:
    ch_versions   = Channel.empty()
    ch_assemblies = Channel.empty()
    ch_proteins   = Channel.empty()

    if(hifi_reads) {
        if(params.enable_metamdbg) {
            METAMDBG_ASM(hifi_reads, 'hifi')

            ch_metamdbg_assemblies = METAMDBG_ASM.out.contigs
                | map { meta, contigs ->
                    def meta_new = meta + [assembler: "metamdbg"]
                    [meta_new, contigs]
                }
            ch_assemblies = ch_assemblies.mix(ch_metamdbg_assemblies)
        }

        PYRODIGAL(ch_assemblies, 'gff')
        ch_proteins = ch_proteins.mix(PYRODIGAL.out.faa)
        ch_versions = ch_versions.mix(PYRODIGAL.out.versions)
    }

    emit:
    assemblies = ch_assemblies
    proteins   = ch_proteins
    versions   = ch_versions
}
