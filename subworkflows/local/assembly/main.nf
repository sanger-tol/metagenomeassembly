include { METAMDBG_ASM               } from '../../../modules/nf-core/metamdbg/asm/main'
include { GZIP_GET_DECOMPRESSED_SIZE } from '../../../modules/local/gzip_get_decompressed_size/main'

workflow ASSEMBLY {
    take:
    hifi_reads
    assembly

    main:
    ch_versions   = Channel.empty()
    ch_assemblies = Channel.empty()
        | mix(assembly)

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

    //
    // MODULE: To aid in setting resource requirements, get the decompressed
    // size of the assembly using gzip -l, and add it to the meta map as
    // meta.decompressed size
    //
    GZIP_GET_DECOMPRESSED_SIZE(ch_assemblies)
    ch_assemblies_extrameta = GZIP_GET_DECOMPRESSED_SIZE.out.fasta_with_size
        | map { meta, fasta, unc_size ->
            [ meta + [decompressed_size: unc_size.toInteger()], fasta ]
        }
    ch_versions = ch_versions.mix(GZIP_GET_DECOMPRESSED_SIZE.out.versions)

    emit:
    assemblies = ch_assemblies_extrameta
    versions   = ch_versions
}
