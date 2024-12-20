process BIN_SUMMARY {
    tag "${meta.id}"
    label "process_low"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/r-base_r-tidyverse_r-optparse:d348292153ed2a3e':
        'community.wave.seqera.io/library/r-base_r-tidyverse_r-optparse:fb0e94661e2bf4e0' }"

    input:
    tuple val(meta), path(stats)
    tuple val(meta), path(checkm2)
    tuple val(meta), path(taxonomy)
    tuple val(meta), path(prokka)

    output:
    tuple val(meta), path("*.bin_summary.tsv"), emit: summary
    path("versions.yml")                      , emit: versions

    script:
    def args         = task.ext.args   ?: ''
    def prefix       = task.ext.prefix ?: "${meta.id}"
    def stats_input  = stats    ? "--stats ${stats.join(",")}"       : ""
    def checkm_input = checkm2  ? "--checkm ${checkm2.join(",")}"    : ""
    def tax_input    = taxonomy ? "--taxonomy ${taxonomy.join(",")}" : ""
    def prokka_input = prokka   ? "--prokka ${prokka.join(",")}"     : ""
    """
    bin_summary.R \\
        -o ${prefix} \\
        ${stats_input} \\
        ${checkm_input} \\
        ${tax_input} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        R: \$(Rscript -e 'cat(paste0(R.Version()[c("major","minor")], collapse = "."))')
        tidyverse: \$(Rscript -e 'cat(packageVersion("tidyverse"))')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.bin_summary.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        R: \$(Rscript -e 'cat(paste0(R.Version()[c("major","minor")], collapse = "."))')
        tidyverse: \$(Rscript -e 'cat(packageVersion("tidyverse"))')
    END_VERSIONS
    """
}
