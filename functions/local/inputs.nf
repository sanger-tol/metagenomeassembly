include { samplesheetToList } from 'plugin/nf-schema'

/**
 * Count the number of unique sample IDs in a samplesheet.
 *
 * Parses a samplesheet (JSON or CSV) using the nf-schema plugin and counts
 * the number of unique sample IDs present.
 *
 * @param samples A samplesheet file path or JSON string to parse
 * @return The number of unique sample IDs in the samplesheet
 *
 */
def countSamples(samplesheet) {
    def samples = samplesheetToList(samplesheet, "${projectDir}/assets/schema_input.json")
    return samples.collect { meta, _reads, _assembly -> meta.id }.unique().size()
}
