process BIN_RRNAS {
    tag "${meta.id}"
    label "process_low"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gawk:5.3.0' :
        'biocontainers/gawk:5.3.0' }"

    input:
    tuple val(meta), path(contig2bin), path(cm_tbl)

    output:
    tuple val(meta), path("*.tsv"), emit: tsv
    path("versions.yml")          , emit: versions

    script:
    def prefix  = task.ext.prefix ?: ""
    def tbl_in  = cm_tbl.toString() - ~/\.gz$/
    def gunzip  = cm_tbl.getExtension() == "gz" ? "gunzip -c ${cm_tbl} > ${tbl_in}" : ""
    def cleanup = cm_tbl.getExtension() == "gz" ? "rm ${tbl_in}" : ""
    """
    ${gunzip}

    echo -e "bin\tn_ssu\tn_lsu\tn_5s" > ${prefix}.rrna_summary.tsv
    awk '{print \$2}' ${contig2bin} | sort -u | while read bin
    do
        awk -v bin=\$bin '\$2 == bin {print \$1}' ${contig2bin} > ${bin}.pattern
        grep -f ${bin}.pattern ${tbl_in} | awk -v bin=\${bin} \\
        'BEGIN {
            OFS = "\t"
            n_5s  = 0
            n_ssu = 0
            n_lsu = 0
        }
        \$3 ~ /5S/  { n_5s++  }
        \$3 ~ /SSU/ { n_ssu++ }
        \$3 ~ /LSU/ { n_lsu++ }
        END { print bin, n_ssu, n_lsu, n_5s}
        ' - >> ${prefix}.rrna_summary.tsv
    done

    ${cleanup}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gawk: \$(awk -Wversion | sed '1!d; s/.*Awk //; s/,.*//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: ""
    """
    touch ${prefix}.rrna_summary.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gawk: \$(awk -Wversion | sed '1!d; s/.*Awk //; s/,.*//')
    END_VERSIONS
    """
}
