process PAIRTOOLS_PARSESORTFILTER {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/5a/5a257231a31e4220c79e33cad2039919b2c555e0ad8cb13a3be0f3a50d7e1201/data' :
        'community.wave.seqera.io/library/htslib_pairtools_samtools:883b7c46ee9d2f22' }"

    input:
    tuple val(meta), path(bam), path(chromsizes), path(filter_list)

    output:
    tuple val(meta), path("*.pairsam.gz")  , emit: pairsam
    tuple val(meta), path("*.pairsam.stat"), emit: stat
    tuple val("${task.process}"), val('samtools'), eval("samtools version | sed '1!d;s/.* //'"), topic: versions, emit: versions_samtools
    tuple val("${task.process}"), val('pairtools'), eval("pairtools --version | sed 's/.*pairtools.*version //'") , emit: versions_pairtools, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def filter_cmd = filter_list ? "grep -vf ${filter_list} |" : ""
    """
    samtools view -h ${args} ${bam} |\\
    pairtools \\
        parse \\
        -c ${chromsizes} \\
        ${args2} |\\
        pairtools sort ${args3} |\\
        ${filter_cmd} bgzip -@4 > ${prefix}.pairsam.gz
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}.pairsam.gz
    """
}
