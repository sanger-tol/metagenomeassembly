/**
 * Determine the publish directory path based on sample count.
 *
 * Publish to a named sample directory if more than one sample used, otherwise
 * just publishes to the output directory.
 *
 * @param meta A map containing sample metadata, must include an 'id' field
 * @param n_samples The total number of unique samples in the analysis
 * @return A subdirectory path as a string (e.g., "sample1/") or empty string
 *
 */
def getOutdir(obj) {
    if (obj?.n_samples) {
        if(obj?.n_samples == 1) {
            return ""
        } else {
            return "${obj.id}/"
        }
    } else {
        return "${obj.id}/"
    }

}
