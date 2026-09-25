process FILTER_ASSEMBLY {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/74/747d2092b8ec4907620889a7303084bd544d476436ce14297e1d8372cde3e43a/data'
        : 'community.wave.seqera.io/library/pyfastx_click:044745d38b4e55c4' }"

    input:
    tuple val(meta), path(fasta)
    tuple val(meta2), path(tiara_classifications), val(tiara_ids)

    output:
    tuple val(meta), path("*.circles.fasta.gz"), emit: circles_fasta, optional: true
    tuple val(meta), path("*.circles.list")    , emit: circles_list, optional: true
    tuple val(meta), path("*_filtered.fasta")  , emit: filtered
    tuple val(meta), path("*.exclude.list")    , emit: exclude_list
    tuple val(meta), path("*.include.list")    , emit: include_list
    tuple val("${task.process}"), val('filter_assembly.py'), eval('filter_assembly.py --version'), emit: versions_filter_assembly, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ""
    def prefix = task.ext.prefix ?: "${meta.id}"
    def tiara_input = tiara_classifications ? tiara_classifications.collect { c -> "--tiara ${c}" }.join(" ") : ""
    def tiara_id_input = tiara_ids ? tiara_ids.collect { id -> "--tiara-id ${id}" }.join(" ") : ""
    """
    filter_assembly.py \\
        ${args} \\
        --prefix ${prefix} \\
        ${tiara_input} \\
        ${tiara_id_input} \\
        ${fasta}
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.filtered.fasta
    echo "" | gzip > ${prefix}.circles.fasta.gz
    touch ${prefix}.circles.list
    touch ${prefix}.exclude.list
    touch ${prefix}.include.list
    """
}
