process METATOR_PIPELINE {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "sanger-tol/metator:1.3.2-c1"

    input:
    tuple val(meta), path(contigs), path(hic_input), path(depths)
    val hic_enzymes

    output:
    tuple val(meta), path("bin_summary.txt")          , emit: bin_summary
    tuple val(meta), path("binning.txt")              , emit: contig2bin
    tuple val(meta), path("bins/*.fa"), emit: bins
    path "versions.yml"                               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args           = task.ext.args   ?: ''
    def prefix         = task.ext.prefix ?: "${meta.id}"
    def enzyme_input   = hic_enzymes ? "-e ${hic_enzymes.join(",")}" : ""
    def depth_input    = depths ? "--depth ${depths}" : ""
    def assembly_input = contigs =~ /\.gz$/ ? "${contigs.getBaseName()}" : contigs
    def gunzip         = contigs =~ /\.gz$/ ? "gunzip -c ${contigs} > ${assembly_input}" : ""
    """
    $gunzip

    metator pipeline \\
        --forward ${hic_input[0]} \\
        --reverse ${hic_input[1]} \\
        --assembly ${assembly_input} \\
        ${enzyme_input} \\
        ${depth_input} \\
        -t ${task.cpus} \\
        --prefix ${prefix} \\
        ${args}

    # metator includes the contig descriptions in the bins
    # these need to go
    mkdir bins
    for bin in final_bin_unscaffold/*.fa; do
        binname=`basename \$bin`
        awk -F" " '{if(\$1~">"){ print \$1 } else { print \$0 } }' \$bin > bins/\${binname}
    done

    rm -r final_bin_unscaffold

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
