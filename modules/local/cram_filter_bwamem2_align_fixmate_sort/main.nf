process CRAM_FILTER_ALIGN_BWAMEM2_FIXMATE_SORT {
    tag "$meta.id"
    label "process_high"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-1a6fe65bd6674daba65066aa796ed8f5e8b4687b:688e175eb0db54de17822ba7810cc9e20fa06dd5-0' :
        'biocontainers/mulled-v2-1a6fe65bd6674daba65066aa796ed8f5e8b4687b:688e175eb0db54de17822ba7810cc9e20fa06dd5-0' }"

    input:
    tuple val(meta), path(cramfile), path(cramindex), val(range)
    tuple val(meta2), path(index)
    tuple val(meta3), path(reference)

    output:
    tuple val(meta3), path("*.bam"), emit: bam
    path "versions.yml"            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def args1 = task.ext.args1 ?: ''
    def args2 = task.ext.args2 ?: ''
    def args3 = task.ext.args3 ?: ''
    def args4 = task.ext.args4 ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    // Please be aware one of the tools here required mem = 28 * reference size!!!
    """
    INDEX=`find -L ./ -name "*.amb" | sed 's/\\.amb\$//'`

    cram_filter ${args} -n ${range[0]}-${range[1]} ${cramfile} - | \\
        samtools fastq ${args1} | \\
        bwa-mem2 mem ${args2} -t ${task.cpus} \${INDEX} - | \\
        samtools fixmate ${args3} - - | \\
        samtools sort ${args4} -@${task.cpus} -T ${prefix}_tmp -o ${prefix}.bam -

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        staden_io_lib: \$(io_lib-config --version 2>&1)
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//' )
        bwa-mem2: \$(bwa-mem2 --version | sed 's/bwa-mem2 //g')
    END_VERSIONS
    """

    stub:
    def prefix  = task.ext.prefix ?: "${meta.id}"
    def base    = "45022_3#2"
    def chunkid = "1"
    """
    touch ${prefix}_${base}_${chunkid}_mem.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        staden_io_lib: \$(io_lib-config --version 2>&1)
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//' )
        bwamem2: \$(echo \$(bwa-mem2 version 2>&1) | sed 's/.* //')
    END_VERSIONS
    """
}
