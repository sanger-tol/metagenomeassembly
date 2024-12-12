process BIN_SUMMARY {
    label "process_low"

    conda "${moduleDir}/environment.yml"
    container "docker.io/rocker/tidyverse:4.4"

    input:
    tuple val(meta), path(stats), path(checkm2), path(taxonomy)

    output:
    tuple val(meta), path("bin_summary.tsv")

    script:
    """
    echo test > bin_summary.tsv
    """
}
