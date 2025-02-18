process SAMTOOLS_CATSORT {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.21--h50ea8bc_0' :
        'biocontainers/samtools:1.21--h50ea8bc_0' }"

    input:
    tuple val(meta), path(bams, stageAs:  "?/*")

    output:
    tuple val(meta), path("*.bam"), emit: bam
    path  "versions.yml"          , emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    // We assume each input bam has a name: "original.cram.sample_assembler.chunk.bam"
    // Group the original list of input bams by the original cram names
    // Then sort them by numerically by chunk
    def bam_groups = bams.groupBy{ bam -> (bam.getName() =~ /\d+\/(.*\.cram)/)[0][1] }
        .collect { _cram, files -> [_cram, files.sort(false) { bam -> (bam.getName() =~ /\.(\d+)\.bam/)[0][1].toInteger() } ]}
    // and for each cram file concatenate them to a temp bam file
    def cat_bams = bam_groups.collect { cram, files -> "samtools cat -o ${cram}.temp.bam ${files.join(" ")}" }.join("\n")
    """
    if [ -f bams_to_sort.tsv ]; then
        rm bams_to_sort.tsv
    fi

    ${cat_bams}

    bams=*.temp.bam
    for bam in \${bams}; do
        firstreadid=\$(samtools view \${bam} | head -n 1 | cut -f1 || test \$? -eq 141)
        echo -e "\${bam}\\t\${firstreadid}" >> bams_to_sort.tsv
    done

    sort -k1,1 bams_to_sort.tsv | cut -f1 | xargs samtools cat -o ${prefix}.bam

    rm *.temp.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """
}
