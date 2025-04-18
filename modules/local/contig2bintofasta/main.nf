process CONTIG2BINTOFASTA {
    tag "${meta.id}"
    label "process_low"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/seqkit:2.9.0--h9ee0642_0':
        'biocontainers/seqkit:2.9.0--h9ee0642_0' }"

    input:
    tuple val(meta), path(contigs), path(contig2bin)

    output:
    tuple val(meta), path("*.fa.gz"), emit: bins
    path("versions.yml")            , emit: versions

    script:
    def args        = task.ext.args   ?: ''
    def prefix      = task.ext.prefix ?: "${meta.id}"
    """
    awk '{print \$2}' ${contig2bin} | sort -u | while read bin
    do
        grep -w \${bin} ${contig2bin} | awk '{ print \$1 }' > \${bin}.ctglst
        seqkit grep -f \${bin}.ctglst ${contigs} | gzip > \${bin}.fa.gz
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit: \$( seqkit version | sed 's/seqkit v//' )
    END_VERSIONS
    """

    stub:
    def prefix      = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}.bin1.fa.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit: \$( seqkit version | sed 's/seqkit v//' )
    END_VERSIONS
    """
}
