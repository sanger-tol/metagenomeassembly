process FIND_CIRCLES {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/8c/8c107a3a3017f6606e46111881ba8555185d1be20713f50b7f7f4ea0128f1a05/data':
        'community.wave.seqera.io/library/samtools_seqkit_gawk:5f1679612f236815' }"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*.circular.tsv")    , emit: circles_tsv
    tuple val(meta), path("*.circular.list")   , emit: circles_list
    tuple val(meta), path("*.circles.fasta.gz"), emit: circles_fasta, optional: true
    path "versions.yml"                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix      = task.ext.prefix ?: "${meta.id}"
    def regex       = "/\$-/" // This regex will never match anything
    if(meta.assembler == "metamdbg") {
        regex = "/circular=yes/"
    }
    """
    seqkit fx2tab --length --gc --name ${fasta} |\\
    awk \\
        'BEGIN {
            FS = OFS = "\\t"
        }
        {
            circular = "False"
            if(\$1 ~ ${regex}) {
                circular = "True"
            }
            split(\$1, x, /\s+/)
            print x[1], \$2, \$3, circular
        }' - > ${prefix}.circular.tsv

    awk '\$4 == "True" {print \$1}' ${prefix}.circular.tsv > ${prefix}.circular.list

    if [ -s ${prefix}.circular.list ]; then
        seqkit grep -f ${prefix}.circular.list ${fasta} | \
            bgzip -@${task.cpus} > ${prefix}.circles.fasta.gz
    fi

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
