process CONTIG2BIN2FASTA {
    tag "${meta.id}"
    label "process_low"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/seqkit:2.8.1--h9ee0642_0':
        'biocontainers/seqkit:2.8.1--h9ee0642_0' }"

    input:
    tuple val(meta), path(contigs), path(contig2bin)
    val bincol
    val contigcol

    output:
    tuple val(meta), path("*.fa"), emit: bins
    path("versions.yml")         , emit: versions

    script:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    grep -v "binnew" ${contig2bin} | awk '{print \$${bincol}}' | sort -u | while read bin
    do
        binno=\${bin//[^0-9]/}
        grep -w \${bin} ${contig2bin} | awk '{print \$${contigcol}}' > ${prefix}_\${binno}.ctglst
        seqkit grep -f ${prefix}_\${binno}.ctglst ${contigs} > ${prefix}_\${binno}.fa
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit: \$( seqkit version | sed 's/seqkit v//' )
    END_VERSIONS
    """
}
