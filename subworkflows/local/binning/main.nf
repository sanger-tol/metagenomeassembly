include { COMEBIN_RUNCOMEBIN                 } from '../../../modules/nf-core/comebin/runcomebin'
include { MAXBIN2                            } from '../../../modules/nf-core/maxbin2'
include { GAWK as GAWK_FASTATOCONTIG2BIN     } from '../../../modules/nf-core/gawk'
include { GAWK as GAWK_MAXBIN2_DEPTHS        } from '../../../modules/nf-core/gawk'
include { METABAT2_METABAT2                  } from '../../../modules/nf-core/metabat2/metabat2'
include { METATOR_PIPELINE                   } from '../../../modules/nf-core/metator/pipeline'
include { SEMIBIN_SINGLEEASYBIN              } from '../../../modules/nf-core/semibin/singleeasybin'
include { SEQKIT_REPLACE as FIX_METATOR_BINS } from '../../../modules/nf-core/seqkit/replace'
include { SEQKIT_SPLIT2 as SPLIT_CIRCLES     } from '../../../modules/nf-core/seqkit/split2'

include { BINNING_VAMB                       } from '../../../subworkflows/local/binning_vamb'
include { BINNING_VAMB as BINNING_TAXVAMB    } from '../../../subworkflows/local/binning_vamb'

workflow BINNING {
    take:
    ch_assemblies // channel: [[meta], contigs]
    ch_circular_contigs // channel: [meta, circular_contigs]
    ch_depths // channel: [[meta], depths_file]
    ch_bam // channel: [[meta], bam]
    ch_hic_pairs // channel: [[meta], bam]
    val_extract_circular_contigs
    val_enable_metabat2
    val_enable_maxbin2
    val_enable_comebin
    val_enable_semibin2
    val_enable_vamb
    val_enable_taxvamb
    ch_centrifuger_db
    val_enable_metator

    main:
    ch_bins = channel.empty()

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

    if (val_enable_semibin2) {
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
        //
        // Subworkflow: Bin assembly with VAMB in standard mode
        //
        BINNING_VAMB(
            ch_assemblies,
            ch_depths,
            false,
            channel.empty()
        )

        ch_bins = ch_bins.mix(
            BINNING_VAMB.out.bins.map { meta, fasta -> [meta + [binner: "vamb"], fasta] }
        )
    }

    if (val_enable_taxvamb) {
        //
        // Subworkflow: Bin assembly with VAMB with taxonomy
        //
        BINNING_TAXVAMB(
            ch_assemblies,
            ch_depths,
            true,
            ch_centrifuger_db
        )

        ch_bins = ch_bins.mix(
            BINNING_TAXVAMB.out.bins.map { meta, fasta -> [meta + [binner: "taxvamb"], fasta] }
        )
    }

    if (val_enable_metator) {
        //
        // Module: Bin assembly using Metator
        //
        ch_metator_inputs = ch_assemblies
            .combine(ch_hic_pairs, by: 0)
            .map { meta, asm, pairs ->
                [meta, asm, pairs, []]
            }

        METATOR_PIPELINE(ch_metator_inputs)

        //
        // Module: Metator keeps the contig descriptions whereas all other binners drop them
        // This causes problems downstream.
        //
        FIX_METATOR_BINS(METATOR_PIPELINE.out.bins.transpose())

        ch_bins = ch_bins.mix(
            FIX_METATOR_BINS.out.fastx.groupTuple(by: 0).map { meta, fasta -> [meta + [binner: "metator"], fasta] }
        )
    }

    //
    // Module: Create contig2bin maps for all output bins
    //
    GAWK_FASTATOCONTIG2BIN(ch_bins, file("${projectDir}/bin/fastatocontig2bin.awk"), false)

    emit:
    bins       = ch_bins
    contig2bin = GAWK_FASTATOCONTIG2BIN.out.output
}
