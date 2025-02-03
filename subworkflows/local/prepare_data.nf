include { SAMTOOLS_INDEX } from '../../modules/nf-core/samtools/index/main'

workflow PREPARE_DATA {
    take:
    hic_cram

    main:
    ch_versions = Channel.empty()

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

    SAMTOOLS_INDEX(ch_hic_cram_raw.no_index)
    ch_versions = SAMTOOLS_INDEX.out.versions

    ch_hic_cram = ch_hic_cram_raw.have_index
        | mix(SAMTOOLS_INDEX.out.crai)

    emit:
    hic_cram = ch_hic_cram
    versions = ch_versions
}
