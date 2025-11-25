include { GUNZIP        } from '../../../modules/nf-core/gunzip/main'
include { METAMDBG_ASM  } from '../../../modules/nf-core/metamdbg/asm/main'

workflow ASSEMBLY {
    take:
    ch_hifi_reads
    ch_assemblies

    main:
    ch_versions       = Channel.empty()
    ch_assemblies_raw = Channel.empty()
        | mix(ch_assemblies)

    if(params.enable_metamdbg) {
        //
        // MODULE: Assemble PacBio reads using metaMDBG
        //
        ch_metamdbg_input = ch_hifi_reads
            | combine(ch_assemblies_raw.ifEmpty([[:],[]]))
            | filter { _meta, _reads, _meta_asm, asm -> !asm }
            | map { meta, reads, _meta_asm, _asm -> [ meta, reads ] }

        METAMDBG_ASM(ch_metamdbg_input, 'hifi')
        ch_versions = ch_versions.mix(METAMDBG_ASM.out.versions)

        ch_metamdbg_assemblies = METAMDBG_ASM.out.contigs
            | map { meta, contigs ->
                def meta_new = meta + [assembler: "metamdbg"]
                [ meta_new, contigs ]
            }
        ch_assemblies_raw = ch_assemblies_raw.mix(ch_metamdbg_assemblies)
    }

    //
    // Module: ungzip gzipped assemblies
    //
    ch_assemblies_split = ch_assemblies_raw
        | branch { meta, asm ->
            gzipped: asm.getExtension() == "gz"
            ungzipped: true
        }

    GUNZIP(ch_assemblies_split.gzipped)
    ch_versions = ch_versions.mix(GUNZIP.out.versions)

    ch_assemblies_unzipped = ch_assemblies_split.ungzipped
        | mix(GUNZIP.out.gunzip)

    emit:
    assemblies = ch_assemblies_unzipped
    versions   = ch_versions
}
