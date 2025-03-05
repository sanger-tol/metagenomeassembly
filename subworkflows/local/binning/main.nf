include { BIN3C_MKMAP                 } from '../../../modules/local/bin3c/mkmap/main.nf'
include { BIN3C_CLUSTER               } from '../../../modules/local/bin3c/cluster/main.nf'
include { FASTATOCONTIG2BIN           } from '../../../modules/local/fastatocontig2bin/main.nf'
include { MAXBIN2                     } from '../../../modules/nf-core/maxbin2/main'
include { GAWK as GAWK_MAXBIN2_DEPTHS } from '../../../modules/nf-core/gawk/main'
include { METABAT2_METABAT2           } from '../../../modules/nf-core/metabat2/metabat2/main'
include { METATOR_PIPELINE            } from '../../../modules/local/metator/pipeline/main'
include { METATOR_PROCESS_INPUT_BAM   } from '../../../modules/local/metator/process_input_bam/main'

workflow BINNING {
    take:
    assemblies      // channel: [[meta], contigs]
    pacbio_depths   // channel: [[meta], depths_file]
    hic_bam         // channel: [[meta], bam]
    hic_enzymes     // channel: [enz1, enz2], value

    main:
    ch_versions   = Channel.empty()
    ch_bins       = Channel.empty()
    ch_contig2bin = Channel.empty()

    if(params.enable_metabat2) {
        ch_metabat_input = assemblies
            | combine(pacbio_depths, by: 0)

        //
        // MODULE: Bin assembly using Metabat2
        //
        METABAT2_METABAT2(ch_metabat_input)
        ch_versions = ch_versions.mix(METABAT2_METABAT2.out.versions)

        ch_metabat2_bins =  METABAT2_METABAT2.out.fasta
            | map { meta, fasta -> [meta + [binner: "metabat2"], fasta] }
        ch_bins = ch_bins.mix(ch_metabat2_bins)
    }

    if(params.enable_maxbin2) {
        //
        // MODULE: Convert depth to correct format for MaxBin2
        //
        GAWK_MAXBIN2_DEPTHS(pacbio_depths, "${projectDir}/bin/convert_depths_maxbin2.awk", true)
        ch_versions = ch_versions.mix(GAWK_MAXBIN2_DEPTHS.out.versions)

        ch_maxbin2_input = assemblies
            | combine(GAWK_MAXBIN2_DEPTHS.out.output, by: 0)
            | map { meta, contigs, depths ->
                [meta, contigs, [], depths]
            }

        //
        // MODULE: Bin assembly using MaxBin2
        //
        MAXBIN2(ch_maxbin2_input)
        ch_versions = ch_versions.mix(MAXBIN2.out.versions)

        ch_maxbin2_bins =  MAXBIN2.out.binned_fastas
            | map { meta, fasta -> [meta + [binner: "maxbin2"], fasta] }
        ch_bins = ch_bins.mix(ch_maxbin2_bins)
    }

    if(params.enable_bin3c) {
        ch_bin3c_mkmap_input = assemblies
            | combine(hic_bam, by: 0)

        //
        // MODULE: Create Hi-C contact map for Bin3C
        //
        BIN3C_MKMAP(ch_bin3c_mkmap_input, hic_enzymes)
        ch_versions = ch_versions.mix(BIN3C_MKMAP.out.versions)

        ch_bin3c_cluster_input = assemblies
            | combine(BIN3C_MKMAP.out.map, by: 0)

        //
        // MODULE: Cluster Bin3C contact map and write bins
        //
        BIN3C_CLUSTER(ch_bin3c_cluster_input)
        ch_versions = ch_versions.mix(BIN3C_CLUSTER.out.versions)

        ch_bin3c_bins =  BIN3C_CLUSTER.out.fasta
            | map { meta, fasta -> [meta + [binner: "bin3c"], fasta] }
        ch_bins = ch_bins.mix(ch_bin3c_bins)
    }

    if(params.enable_metator) {
        ch_directions = Channel.of("fwd", "rev")
        ch_hic_bam_to_process = hic_bam
            | combine(ch_directions)

        //
        // MODULE: Metator expects us to have aligned forward and reverse reads
        // independently of one another - munge the bam file
        // to filter out forward and reverse reads and remove mate information
        // from SAM flags: bitwise and(flag, 3860)
        //
        METATOR_PROCESS_INPUT_BAM(ch_hic_bam_to_process)
        ch_versions = ch_versions.mix(METATOR_PROCESS_INPUT_BAM.out.versions)

        ch_metator_input = METATOR_PROCESS_INPUT_BAM.out.filtered_bam
            | groupTuple(by: 0, size: 2)
            | combine(assemblies, by: 0)
            | map { meta, bams, contigs ->
                [ meta, contigs, bams.sort(), [] ]
            }
        //
        // MODULE: Bin assembly using Metator
        //
        METATOR_PIPELINE(ch_metator_input, hic_enzymes)
        ch_versions = ch_versions.mix(METATOR_PIPELINE.out.versions)

        ch_metator_bins =  METATOR_PIPELINE.out.bins
            | map { meta, fasta -> [meta + [binner: "metator"], fasta] }
        ch_bins = ch_bins.mix(ch_metator_bins)
    }

    //
    // MODULE: Create contig2bin maps for all output bins
    //
    FASTATOCONTIG2BIN(ch_bins, 'fa')
    ch_contig2bin = ch_contig2bin.mix(FASTATOCONTIG2BIN.out.contig2bin)
    ch_versions = ch_versions.mix(FASTATOCONTIG2BIN.out.versions)

    emit:
    bins       = ch_bins
    contig2bin = ch_contig2bin
    versions   = ch_versions
}
