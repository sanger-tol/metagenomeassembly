process FIND_CIRCLES {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/seqkit:2.9.0--h9ee0642_0':
        'biocontainers/seqkit:2.9.0--h9ee0642_0' }"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*.circular.list")   , emit: circles_list
    tuple val(meta), path("*.circles.fasta.gz"), emit: circles_fasta
    path "versions.yml"                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix      = task.ext.prefix ?: "${meta.id}"
    def clean_input = input.toString() - ~/\.gz$/
    def unzip       = input.getExtension() == "gz" ? "zcat ${fasta} | \\" : "cat ${fasta} | \\"
    def regex       = "&& /\$-/" // This regex will never match anything
    if(meta.assembler == "metamdbg") {
        regex = "&& /circular=yes/"
    }
    """
    ${unzip}
    awk \\
        '/^>/ ${regex} {
            sub(/>/, "", \$1)
            print \$1
        }' - > ${prefix}.circular.list

    seqkit grep -f ${prefix}.circular.list ${fasta} |\
        bgzip -@${task.cpus} > ${prefix}.circles.fasta.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gawk: \$(awk -Wversion | sed '1!d; s/.*Awk //; s/,.*//')
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.circular.list
    touch ${prefix}.circular.stats

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gawk: \$(awk -Wversion | sed '1!d; s/.*Awk //; s/,.*//')
    END_VERSIONS
    """
}
