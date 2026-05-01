include { COMEBIN_RUNCOMEBIN                 } from '../../../modules/nf-core/comebin/runcomebin/main'
include { MAXBIN2                            } from '../../../modules/nf-core/maxbin2/main'
include { GAWK as GAWK_FASTATOCONTIG2BIN     } from '../../../modules/nf-core/gawk/main'
include { GAWK as GAWK_MAXBIN2_DEPTHS        } from '../../../modules/nf-core/gawk/main'
include { GAWK as GAWK_VAMB_DEPTHS           } from '../../../modules/nf-core/gawk/main'
include { METABAT2_METABAT2                  } from '../../../modules/nf-core/metabat2/metabat2/main'
include { METATOR_PIPELINE                   } from '../../../modules/nf-core/metator/pipeline/main'
include { SEMIBIN_SINGLEEASYBIN              } from '../../../modules/nf-core/semibin/singleeasybin/main'
include { SEQKIT_REPLACE as FIX_METATOR_BINS } from '../../../modules/nf-core/seqkit/replace/main'
include { SEQKIT_SPLIT2 as SPLIT_CIRCLES     } from '../../../modules/nf-core/seqkit/split2/main'
include { VAMB_BIN                           } from '../../../modules/nf-core/vamb/bin/main'

workflow BINNING {
    take:
    ch_assemblies // channel: [[meta], contigs]
    ch_circular_contigs // channel: [meta, circular_contigs]
    ch_depths // channel: [[meta], depths_file]
    ch_bam // channel: [[meta], bam]
    ch_hic_pairs // channel: [[meta], bam]
    ch_hic_enzymes // channel: [enz1, enz2], value
    val_extract_circular_contigs
    val_enable_metabat2
    val_enable_maxbin2
    val_enable_comebin
    val_enable_semibin
    val_enable_vamb
    val_enable_metator

    main:
    ch_versions = channel.empty()
    ch_bins = channel.empty()
    ch_contig2bin = channel.empty()

    //
    // Module: Split circular contigs into separate bin files
    //
    if (val_extract_circular_contigs) {
        SPLIT_CIRCLES(ch_circular_contigs.map { meta, contigs -> [meta + [single_end: true], contigs] })

        ch_bins = ch_bins.mix(
            SPLIT_CIRCLES.out.reads.map { meta, fasta ->
                [meta - meta.subMap("single_end") + [binner: "circular"], fasta]
            }
        )
    }

    //
    // Module: Bin assembly using Metabat2
    //
    if (val_enable_metabat2) {
        METABAT2_METABAT2(
            ch_assemblies.combine(ch_depths, by: 0)
        )

        ch_bins = ch_bins.mix(
            METABAT2_METABAT2.out.fasta.map { meta, fasta -> [meta + [binner: "metabat2"], fasta] }
        )
    }

    //
    // Logic: Bin assembly with MaxBin2
    //
    if (val_enable_maxbin2) {
        GAWK_MAXBIN2_DEPTHS(ch_depths, file("${projectDir}/bin/convert_depths_maxbin2.awk"), true)

        ch_maxbin2_input = ch_assemblies
            .combine(GAWK_MAXBIN2_DEPTHS.out.output, by: 0)
            .map { meta, contigs, depths ->
                [meta, contigs, [], depths]
            }

        //
        // Module: Bin assembly using MaxBin2
        //
        MAXBIN2(ch_maxbin2_input)
        ch_versions = ch_versions.mix(MAXBIN2.out.versions)

        ch_bins = ch_bins.mix(
            MAXBIN2.out.binned_fastas.map { meta, fasta -> [meta + [binner: "maxbin2"], fasta] }
        )
    }

    if (val_enable_comebin) {
        //
        // Module: Bin assembly using Comebin
        //
        ch_comebin_input = ch_assemblies
            .combine(ch_bam, by: 0)
            .map { meta, asm, bam -> [meta, asm, bam] }

        COMEBIN_RUNCOMEBIN(ch_comebin_input)

        ch_bins = ch_bins.mix(
            COMEBIN_RUNCOMEBIN.out.bins.map { meta, fasta -> [meta + [binner: "comebin"], fasta] }
        )
    }

    if (val_enable_semibin) {
        //
        // Module: Bin assembly using Semibin
        //
        ch_semibin_input = ch_assemblies
            .combine(ch_bam, by: 0)
            .map { meta, asm, bam -> [meta, asm, bam] }

        SEMIBIN_SINGLEEASYBIN(ch_semibin_input)

        ch_bins = ch_bins.mix(
            SEMIBIN_SINGLEEASYBIN.out.output_fasta.map { meta, fasta -> [meta + [binner: "semibin"], fasta] }
        )
    }

    if (val_enable_vamb) {
        GAWK_VAMB_DEPTHS(ch_depths, file("${projectDir}/bin/convert_depths_vamb.awk"), false)

        ch_vamb_input = ch_assemblies
            .combine(GAWK_VAMB_DEPTHS.out.output, by: 0)
            .map { meta, contigs, depths ->
                [meta, contigs, depths, [], []]
            }

        VAMB_BIN(ch_vamb_input)
        ch_versions = ch_versions.mix(VAMB_BIN.out.versions)

        ch_bins = ch_bins.mix(
            VAMB_BIN.out.bins.map { meta, fasta -> [meta + [binner: "vamb"], fasta] }
        )
    }

    if (val_enable_metator) {
        //
        // Module: Bin assembly using Metator
        //
        ch_metator_inputs = ch_assemblies
            .combine(ch_hic_pairs, by: 0)
            .combine(ch_hic_enzymes, by: 0)
            .map { meta, asm, pairs, enzymes ->
                def meta_new = meta + [enzymes: enzymes]
                [meta_new, asm, pairs, []]
            }

        METATOR_PIPELINE(ch_metator_inputs)

        FIX_METATOR_BINS(METATOR_PIPELINE.out.bins.transpose())

        ch_bins = ch_bins.mix(
            FIX_METATOR_BINS.out.fastx.groupTuple(by: 0).map { meta, fasta ->
                [meta  - meta.subMap("enzymes") + [binner: "metator"], fasta]
            }
        )
    }

    //
    // Module: Create contig2bin maps for all output bins
    //
    GAWK_FASTATOCONTIG2BIN(ch_bins, file("${projectDir}/bin/fastatocontig2bin.awk"), false)

    emit:
    bins       = ch_bins
    contig2bin = GAWK_FASTATOCONTIG2BIN.out.output
    versions   = ch_versions
}
