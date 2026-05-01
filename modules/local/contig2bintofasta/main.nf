process CONTIG2BINTOFASTA {
    tag "${meta.id}"
    label "process_low"

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/seqkit:2.9.0--h9ee0642_0'
        : 'biocontainers/seqkit:2.9.0--h9ee0642_0'}"

    input:
    tuple val(meta), path(contigs), path(contig2bin)

    output:
    tuple val(meta), path("*.fa.gz"), emit: bins
    tuple val("${task.process}"), val('seqkit'), eval('seqkit version | sed "s/seqkit v//"'), emit: versions_seqkit, topic: versions

    script:
    """
    awk '{print \$2}' ${contig2bin} | sort -u | while read bin
    do
        grep -w \${bin} ${contig2bin} | awk '{ print \$1 }' > \${bin}.ctglst
        seqkit grep -f \${bin}.ctglst ${contigs} | gzip > \${bin}.fa.gz
    done
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}.bin1.fa.gz
    """
}
