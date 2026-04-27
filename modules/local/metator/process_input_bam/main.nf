process METATOR_PROCESS_INPUT_BAM {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'oras://community.wave.seqera.io/library/htslib_samtools_bioawk:3ff2c81f84424e4c'
        : 'community.wave.seqera.io/library/htslib_samtools_bioawk:420f5543dfc64992'}"

    input:
    tuple val(meta), path(bam), val(direction)

    output:
    tuple val(meta), path("*.bam"), emit: filtered_bam
    tuple val("${task.process}"), val('samtools'), eval("samtools version | sed '1!d;s/.* //'"), topic: versions, emit: versions_samtools
    tuple val("${task.process}"), val('bioawk'), val("1.0"), emit: versions_bioawk, topic: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    if (direction == "fwd") {
        flag = "0x40"
    }
    else if (direction == "rev") {
        flag = "0x80"
    }
    else {
        error("ERROR: METATOR_PROCESS_INPUT_BAM direction was not 'fwd' or 'rev'!")
    }
    """
    samtools view -h --threads ${task.cpus - 1} -f ${flag} ${bam} |\\
        bioawk -Hc sam '{ \$flag = and(\$flag , 3860 ) ; print \$0 }' |\\
        samtools sort --threads ${task.cpus - 1} -n -o ${prefix}.${direction}.bam
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    if (direction == "fwd") {
        flag = "0x40"
    }
    else if (direction == "rev") {
        flag = "0x80"
    }
    else {
        error("ERROR: METATOR_PROCESS_INPUT_BAM direction was not 'fwd' or 'rev'!")
    }
    """
    touch ${prefix}.${direction}.bam
    """
}
