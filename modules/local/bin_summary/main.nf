process BIN_SUMMARY {
    label "process_low"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/r-base_r-tidyverse_r-optparse:d348292153ed2a3e':
        'community.wave.seqera.io/library/r-base_r-tidyverse_r-optparse:fb0e94661e2bf4e0' }"

    input:
    tuple val(meta), path(stats), path(checkm2), path(taxonomy)

    output:
    tuple val(meta), path("*.bin_summary.tsv"), emit: summary
    path("versions.yml")                      , emit: versions

    script:
    def args         = task.ext.args   ?: ''
    def prefix       = task.ext.prefix ?: "${meta.id}"
    def stats_input  = stats    ? "--stats ${stats.join(",")}"       : ""
    def checkm_input = checkm2  ? "--checkm ${checkm2.join(",")}"    : ""
    def tax_input    = taxonomy ? "--taxonomy ${taxonomy.join(",")}" : ""
    """
    bin_summary.R \\
        ${stats_input} \\
        ${checkm_input} \\
        ${tax_input} \\
        ${args}
    """
}
