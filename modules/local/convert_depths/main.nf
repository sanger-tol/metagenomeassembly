process CONVERT_DEPTHS {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/e1/e124c5011eb7ab8326d2ee69afd95807605fc7182989473100ebbcb946824a57/data'
        : 'community.wave.seqera.io/library/click_polars:3728b1a8c2814122'}"

    input:
    tuple val(meta), path(depths)
    val format

    output:
    tuple val(meta), path("*.tsv"), emit: depths
    tuple val("${task.process}"), val('convert_depths.py'), eval('convert_depths.py --version'), emit: versions_convert_depths, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    convert_depths.py \\
        --format ${format} \\
        --prefix ${prefix} \\
        ${depths} \\
        ${args}
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    if [ ${format} == 'maxbin2' ]; then
        touch ${prefix}.sample1.maxbin2.depth.tsv
        touch ${prefix}.sample2.maxbin2.depth.tsv
    elif [ ${format} == 'vamb' ]; then
        touch ${prefix}.vamb.depth.tsv
    fi
    """
}
