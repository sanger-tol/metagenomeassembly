process METATOR_PIPELINE {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'community.wave.seqera.io/library/metator:8499357cd4065779' :
        'oras://community.wave.seqera.io/library/metator:dc370f87fbdefd93' }"

    input:
    tuple val(meta), path(contigs)
    tuple val(meta2), path(hic_reads)

    output:
    tuple val(meta), path("bin_summary.txt")  , emit: bin_summary
    tuple val(meta), path("binning.txt")      , emit: contig2bin
    tuple val(meta), path("final_bin/*.fasta"), emit: bins
    path "versions.yml"                       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    metator pipeline \\
        -1 ${hic_reads[0]} \\
        -2 ${hic_reads[1]} \\
        -a ${contigs} \\
        -t ${task.cpus} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        metator: \$( metator -v )
    END_VERSIONS
    """

    stub:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch bin_summary.txt
    touch binning.txt
    mkdir final_bin

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        metator: \$( metator -v )
    END_VERSIONS
    """
}
