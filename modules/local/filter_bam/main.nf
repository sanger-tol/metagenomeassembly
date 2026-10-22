process FILTER_BAM {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/8c/8c107a3a3017f6606e46111881ba8555185d1be20713f50b7f7f4ea0128f1a05/data'
        : 'community.wave.seqera.io/library/samtools_seqkit_gawk:5f1679612f236815'}"

    input:
    tuple val(meta), path(bam), path(filter_list)

    output:
    tuple val(meta), path("*.filtered.bam"), emit: bam
    tuple val("${task.process}"), val('samtools'), eval("samtools version | sed '1!d;s/.* //'"), emit: versions_samtools, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    samtools view -@${task.cpus} -h ${bam} |\\
        grep -vwf ${filter_list} |\\
        samtools view -h -@${task.cpus} -o ${prefix}.filtered.bam
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.filtered.bam
    """
}
