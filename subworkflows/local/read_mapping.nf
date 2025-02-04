include { BWAMEM2_INDEX                             } from '../../modules/nf-core/bwamem2/index/main'
include { COVERM_CONTIG                             } from '../../modules/nf-core/coverm/contig/main'
include { CRAM_FILTER_ALIGN_BWAMEM2_FIXMATE_SORT    } from '../../modules/local/cram_filter_bwamem2_align_fixmate_sort/main'
include { MINIMAP2_ALIGN                            } from '../../modules/nf-core/minimap2/align/main'
include { SAMTOOLS_INDEX as SAMTOOLS_INDEX_HIC_CRAM } from '../../modules/nf-core/samtools/index/main'
include { SAMTOOLS_MERGE as SAMTOOLS_MERGE_HIC_BAM  } from '../../modules/nf-core/samtools/merge/main'

workflow READ_MAPPING {
    take:
    assemblies
    pacbio
    hic_cram

    main:
    ch_versions = Channel.empty()

    if(params.enable_metator || params.enable_bin3c) {
        // Check if CRAM files are accompanied by an index
        // Get indexes, and index those that aren't
        ch_hic_cram_raw = hic_cram
            | transpose()
            | branch { meta, cram ->
                def cram_file = file(cram, checkIfExists: true)
                def index = cram_file.getParent() + "/" + cram_file.getBaseName() + ".crai"
                have_index: file(index).exists()
                    return [ meta, cram_file, file(index, checkIfExists: true) ]
                no_index: true
                    return [ meta, cram_file ]
            }

        SAMTOOLS_INDEX_HIC_CRAM(ch_hic_cram_raw.no_index)
        ch_versions = SAMTOOLS_INDEX_HIC_CRAM.out.versions

        ch_hic_cram = ch_hic_cram_raw.have_index
            | mix(SAMTOOLS_INDEX_HIC_CRAM.out.crai)

        BWAMEM2_INDEX(assemblies)
        ch_versions = ch_versions.mix(BWAMEM2_INDEX.out.versions)

        ch_cram_chunks = ch_hic_cram
            | map { meta, cram, crai ->
                def n_slices = crai.countLines(decompress: true) - 1
                def size = params.hic_mapping_cram_bin_size
                def n_bins = n_slices.intdiv(size)
                def slices = []
                for (chunk in 0..n_bins) {
                    def lower = chunk == 0 ? 0 : (chunk * size) + 1
                    def upper = chunk == n_bins ? n_slices : (chunk + 1) * size
                    slices << [ lower, upper ]
                }
                [ meta, cram, crai, slices ]
            }
            | transpose()

        CRAM_FILTER_ALIGN_BWAMEM2_FIXMATE_SORT(
            ch_cram_chunks,
            BWAMEM2_INDEX.out.index,
            assemblies
        )
        ch_versions = ch_versions.mix(CRAM_FILTER_ALIGN_BWAMEM2_FIXMATE_SORT.out.versions)

        ch_bam_to_merge = CRAM_FILTER_ALIGN_BWAMEM2_FIXMATE_SORT.out.bam
            | groupTuple(by: 0)
            | branch { meta, bam ->
                merge: bam.size() > 1
                asis: true
            }

        SAMTOOLS_MERGE_HIC_BAM(ch_bam_to_merge.merge, [], [])
        ch_versions = ch_versions.mix(SAMTOOLS_MERGE_HIC_BAM.out.versions)

        ch_hic_bam = SAMTOOLS_MERGE_HIC_BAM.out.bam
            | mix(ch_bam_to_merge.asis)

    } else {
        ch_hic_bam   = Channel.empty()
    }

    MINIMAP2_ALIGN(
        pacbio,
        assemblies,
        true,  // bam_format
        "csi", // bam_index_extension
        false, // cigar_paf_format
        false  // cigar_bam
    )
    ch_versions = ch_versions.mix(MINIMAP2_ALIGN.out.versions)

    COVERM_CONTIG(
        MINIMAP2_ALIGN.out.bam,
        [[],[]], // reference
        true,    // bam_input
        false    // interleaved
    )

    ch_versions = ch_versions.mix(COVERM_CONTIG.out.versions)

    emit:
    pacbio_bam = MINIMAP2_ALIGN.out.bam
    hic_bam    = ch_hic_bam
    depths     = COVERM_CONTIG.out.coverage
    versions   = ch_versions
}
