process BIN_SUMMARY {
    tag "${meta.id}"
    label "process_low"

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'oras://community.wave.seqera.io/library/r-base_r-tidyverse_r-optparse:d348292153ed2a3e'
        : 'community.wave.seqera.io/library/r-base_r-tidyverse_r-optparse:fb0e94661e2bf4e0'}"

    input:
    tuple val(meta), path(stats)
    tuple val(meta2), path(coverage)
    tuple val(meta3), path(checkm2)
    tuple val(meta4), path(taxonomy)
    tuple val(meta5), path(trnascan)
    tuple val(meta6), path(rrna)

    output:
    path ("*.bin_summary.tsv"), emit: bin_summary
    path ("*.group_summary.tsv"), emit: group_summary
    tuple val("${task.process}"), val('R'), eval("R --version | sed '1!d; s/.*version //; s/ .*//'"), topic: versions, emit: versions_r
    tuple val("${task.process}"), val('metator'), eval('Rscript -e "cat(as.character(packageVersion(\'tidyverse\')))"'), topic: versions, emit: versions_tidyverse

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def stats_input = stats ? "--stats ${stats.join(",")}" : ""
    def coverage_input = stats ? "--coverage ${coverage.join(",")}" : ""
    def checkm_input = checkm2 ? "--checkm ${checkm2.join(",")}" : ""
    def tax_input = taxonomy ? "--taxonomy ${taxonomy.join(",")}" : ""
    def trna_input = trnascan ? "--trnas ${trnascan.join(",")}" : ""
    def rrna_input = rrna ? "--rrnas ${rrna.join(",")}" : ""
    """
    bin_summary.R \\
        -o ${prefix} \\
        ${stats_input} \\
        ${coverage_input} \\
        ${checkm_input} \\
        ${tax_input} \\
        ${trna_input} \\
        ${rrna_input} \\
        ${args}
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.bin_summary.tsv
    touch ${prefix}.group_summary.tsv
    """
}
