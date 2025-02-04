process METATOR_PROCESS_INPUT_BAM {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/htslib_samtools_bioawk:3ff2c81f84424e4c' :
        'community.wave.seqera.io/library/htslib_samtools_bioawk:420f5543dfc64992' }"

    input:
    tuple val(meta), path(bam), val(direction)

    output:
    tuple val(meta), path("*.bam"), emit: filtered_bam
    path "versions.yml"           , emit: versions

    script:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    if(direction == "fwd") {
        flag = "0x40"
    } else if (direction == "rev") {
        flag = "0x80"
    } else {
        error("ERROR: METATOR_PROCESS_INPUT_BAM direction was not 'fwd' or 'rev'!")
    }
    """
    samtools view --threads ${task.cpus-1} -f ${flag} -o temp.bam ${bam}
    samtools view -H --threads ${task.cpus-1} temp.bam > temp_header

    samtools view --threads ${task.cpus-1} temp.bam |\\
        bioawk -c sam '{ \$flag = and(\$flag , 3860 ) ; print \$0 }' |\\
        cat temp_header - |\\
        samtools sort --threads ${task.cpus-1} -n -o ${prefix}.${direction}.bam

    rm temp.bam temp_header

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
        bioawk: 1.0
    END_VERSIONS
    """

    stub:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    if(direction == "fwd") {
        flag = "0x40"
    } else if (direction == "rev") {
        flag = "0x80"
    } else {
        error("ERROR: METATOR_PROCESS_INPUT_BAM direction was not 'fwd' or 'rev'!")
    }
    """
    touch ${prefix}.${direction}.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
        bioawk: 1.0
    END_VERSIONS
    """
}
