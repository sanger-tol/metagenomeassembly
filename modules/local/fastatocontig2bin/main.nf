process FASTATOCONTIG2BIN {
    tag "${meta.id}"
    label "process_low"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gawk:5.3.0' :
        'biocontainers/gawk:5.3.0' }"

    input:
    tuple val(meta), path(bins)
    val(extension)

    output:
    tuple val(meta), path("*.tsv"), emit: contig2bin
    path("versions.yml")          , emit: versions

    script:
    def args              = task.ext.args   ?: ''
    def prefix            = task.ext.prefix ?: "${meta.id}"
    def compressed_bins   = bins.findAll { it.getExtension() == "gz" }
    def decompress_bins   = compressed_bins.size() > 0 ? "gunzip ${compressed_bins.join(" ")}" : ""
    def clean_bins        = bins.collect { it.toString() - ~/\.gz$/ }
    def remove_compressed = compressed_bins.size() > 0 ? "rm ${compressed_bins.collect { it.toString() - ~/\.gz$/ }.join(" ")}" : ""
    """
    ${decompress_bins}

    awk \\
        'BEGIN { OFS = "\t" }
        BEGINFILE {
            bin = FILENAME
            sub(".*/", "", bin)
            sub(/\\.[^\\.]+\$/, "", bin)
        }
        /^>/ {
            sub(/>/, "", \$1)
            print \$1, bin
        }' ${clean_bins.join(" ")} > ${prefix}.tsv

    ${remove_compressed}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gawk: \$(awk -Wversion | sed '1!d; s/.*Awk //; s/,.*//')
    END_VERSIONS
    """

    stub:
    def prefix      = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gawk: \$(awk -Wversion | sed '1!d; s/.*Awk //; s/,.*//')
    END_VERSIONS
    """
}
