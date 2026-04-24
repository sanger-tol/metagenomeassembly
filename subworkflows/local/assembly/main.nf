include { GUNZIP       } from '../../../modules/nf-core/gunzip/main'
include { METAMDBG_ASM } from '../../../modules/nf-core/metamdbg/asm/main'
include { MYLOASM      } from '../../../modules/nf-core/myloasm/main'

workflow ASSEMBLY {
    take:
    ch_hifi_reads
    ch_assemblies

    main:
    ch_versions = channel.empty()
    ch_assemblies_raw = channel.empty().mix(ch_assemblies)

    ch_assembly_input = ch_hifi_reads
        .combine(ch_assemblies_raw.ifEmpty([[:], []]))
        .filter { _meta, _reads, _meta_asm, asm -> !asm }
        .map { meta, reads, _meta_asm, _asm -> [meta, reads] }

    if (params.assembler == "metamdbg") {
        //
        // MODULE: Assemble PacBio reads using metaMDBG
        //
        METAMDBG_ASM(ch_assembly_input, 'hifi')

        ch_metamdbg_assemblies = METAMDBG_ASM.out.contigs.map { meta, contigs ->
            def meta_new = meta + [assembler: "metamdbg"]
            [meta_new, contigs]
        }
        ch_assemblies_raw = ch_assemblies_raw.mix(ch_metamdbg_assemblies)
    } else if (params.assembler == "myloasm") {
        //
        // MODULE: Assemble PacBio reads using myloasm
        //
        MYLOASM(ch_assembly_input)

        ch_myloasm_assemblies = MYLOASM.out.contigs.map { meta, contigs ->
            def meta_new = meta + [assembler: "myloasm"]
            [meta_new, contigs]
        }
        ch_assemblies_raw = ch_assemblies_raw.mix(ch_myloasm_assemblies)
    }

    //
    // Module: ungzip gzipped assemblies
    //
    ch_assemblies_split = ch_assemblies_raw.branch { _meta, asm ->
        gzipped: asm.getExtension() == "gz"
        ungzipped: true
    }

    GUNZIP(ch_assemblies_split.gzipped)

    ch_assemblies_unzipped = ch_assemblies_split.ungzipped.mix(GUNZIP.out.gunzip)

    emit:
    assemblies = ch_assemblies_unzipped
    versions   = ch_versions
}
