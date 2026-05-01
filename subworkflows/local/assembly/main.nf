include { EXTRACT_CIRCLES } from '../../../modules/local/extract_circles/main'
include { GUNZIP          } from '../../../modules/nf-core/gunzip/main'
include { METAMDBG_ASM    } from '../../../modules/nf-core/metamdbg/asm/main'
include { MYLOASM         } from '../../../modules/nf-core/myloasm/main'

workflow ASSEMBLY {
    take:
    ch_hifi_reads
    ch_assemblies
    val_assembler
    val_minimum_circular_contig_length

    main:
    ch_assembly_input = ch_hifi_reads
        .combine(ch_assemblies.ifEmpty([[:], []]))
        .filter { _meta, _reads, _meta_asm, asm -> !asm }
        .map { meta, reads, _meta_asm, _asm -> [meta, reads] }

    ch_local_assemblies = channel.empty()
    if (val_assembler == "metamdbg") {
        //
        // Module: Assemble PacBio reads using metaMDBG
        //
        METAMDBG_ASM(ch_assembly_input, 'hifi')
        ch_local_assemblies = METAMDBG_ASM.out.contigs
    } else if (val_assembler == "myloasm") {
        //
        // Module: Assemble PacBio reads using myloasm
        //
        MYLOASM(ch_assembly_input)
        ch_local_assemblies = MYLOASM.out.contigs
    }
    ch_local_assemblies = ch_local_assemblies.map { meta, contigs ->
        def meta_new = meta + [assembler: val_assembler]
        [meta_new, contigs]
    }

    ch_assemblies_all = ch_assemblies.mix(ch_local_assemblies)

    //
    // Module: ungzip gzipped assemblies
    //
    ch_assemblies_split = ch_assemblies_all.branch { _meta, asm ->
        gzipped: asm.getExtension() == "gz"
        ungzipped: true
    }

    GUNZIP(ch_assemblies_split.gzipped)
    ch_assemblies_unzipped = ch_assemblies_split.ungzipped.mix(GUNZIP.out.gunzip)

    //
    // Module: Extract circular contigs
    //
    EXTRACT_CIRCLES(
        ch_assemblies_unzipped,
        val_minimum_circular_contig_length
    )

    emit:
    full_assemblies  = ch_assemblies_unzipped
    circular_contigs = EXTRACT_CIRCLES.out.circles
    linear_contigs   = EXTRACT_CIRCLES.out.linear
    circles_list     = EXTRACT_CIRCLES.out.circles_list
}
