process FIND_CIRCLES {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gawk:5.3.0' :
        'biocontainers/gawk:5.3.0' }"

    input:
    tuple val(meta), path(input)

    output:
    tuple val(meta), path("*.circular.list"), emit: circles
    path "versions.yml"                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix      = task.ext.prefix ?: "${meta.id}"
    def clean_input = input.toString() - ~/\.gz$/
    def unzip       = input.getExtension() == "gz" ? "zcat ${input} | \\" : "cat ${input} | \\"
    switch("${meta.assembler}") {
        case "metamdbg": regex = "&& /circular=yes/"; break
        default:
            regex = "&& /\$-/" // This regex will never match anything
            log.warn("WARN: Assembler ${meta.assembler} is not supported for circle counting.")
            break
    }
    """
    ${unzip}
    awk \\
        '/^>/ ${regex} {
            sub(/>/, "", \$1)
            print \$1
        }' - > ${prefix}.circular.list

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
