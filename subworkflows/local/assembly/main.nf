include { METAMDBG_ASM } from '../../../modules/nf-core/metamdbg/asm/main'

workflow ASSEMBLY {
    take:
    hifi_reads

    main:
    ch_versions   = Channel.empty()
    ch_assemblies = Channel.empty()

    if(params.enable_metamdbg) {
        //
        // MODULE: Assemble PacBio reads using metaMDBG
        //
        METAMDBG_ASM(hifi_reads, 'hifi')
        ch_versions = ch_versions.mix(METAMDBG_ASM.out.versions)

        ch_metamdbg_assemblies = METAMDBG_ASM.out.contigs
            | map { meta, contigs ->
                def meta_new = meta + [assembler: "metamdbg"]
                [ meta_new, contigs ]
            }
        ch_assemblies = ch_assemblies.mix(ch_metamdbg_assemblies)
    }

    emit:
    assemblies = ch_assemblies
    versions   = ch_versions
}
