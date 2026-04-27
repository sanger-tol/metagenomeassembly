include { BIN3C_MKMAP                    } from '../../../modules/local/bin3c/mkmap/main'
include { BIN3C_CLUSTER                  } from '../../../modules/local/bin3c/cluster/main'
include { MAXBIN2                        } from '../../../modules/nf-core/maxbin2/main'
include { GAWK as GAWK_FASTATOCONTIG2BIN } from '../../../modules/nf-core/gawk/main'
include { GAWK as GAWK_MAXBIN2_DEPTHS    } from '../../../modules/nf-core/gawk/main'
include { METABAT2_METABAT2              } from '../../../modules/nf-core/metabat2/metabat2/main'
include { METATOR_PIPELINE               } from '../../../modules/local/metator/pipeline/main'
include { METATOR_PROCESS_INPUT_BAM      } from '../../../modules/local/metator/process_input_bam/main'
include { SEQKIT_SPLIT2 as SPLIT_CIRCLES } from '../../../modules/nf-core/seqkit/split2/main'

workflow BINNING {
    take:
    ch_assemblies // channel: [[meta], contigs]
    ch_circular_contigs // channel: [meta, circular_contigs]
    ch_depths // channel: [[meta], depths_file]
    ch_hic_bam // channel: [[meta], bam]
    ch_hic_enzymes // channel: [enz1, enz2], value
    val_extract_circular_contigs
    val_enable_metabat2
    val_enable_maxbin2
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
        GAWK_MAXBIN2_DEPTHS(ch_depths, "${projectDir}/bin/convert_depths_maxbin2.awk", true)

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

    if (val_enable_metator) {
        //
        // Module: Metator expects us to have aligned forward and reverse reads
        // independently of one another - munge the bam file
        // to filter out forward and reverse reads and remove mate information
        // from SAM flags: bitwise and(flag, 3860)
        //
        ch_directions = channel.of('fwd', 'rev')
        ch_hic_bam_to_process = ch_hic_bam.combine(ch_directions)

        METATOR_PROCESS_INPUT_BAM(ch_hic_bam_to_process)

        ch_metator_input = METATOR_PROCESS_INPUT_BAM.out.filtered_bam
            .groupTuple(by: 0, size: 2)
            .combine(ch_assemblies, by: 0)
            .map { meta, bams, contigs ->
                [meta, contigs, bams.sort(), []]
            }

        //
        // Module: Bin assembly using Metator
        //
        METATOR_PIPELINE(ch_metator_input, ch_hic_enzymes)

        ch_metator_bins = METATOR_PIPELINE.out.bins.map { meta, fasta -> [meta + [binner: "metator"], fasta] }

        ch_bins = ch_bins.mix(ch_metator_bins)
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
