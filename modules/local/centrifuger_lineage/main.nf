process CENTRIFUGER_LINEAGE {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/27/27220cee0848b185c512b40779cb85738da0ad7eac58d65024f5d54495fab310/data':
        'community.wave.seqera.io/library/centrifuger_csvtk:4d755e9e2e1b3d33' }"

    input:
    tuple val(meta), path(classifications)
    tuple val(meta2), path(db)

    output:
    tuple val(meta), path("*.lineage.tsv"), emit: lineage_tsv
    tuple val("${task.process}"), val('centrifuger'), eval("centrifuger -v 2>&1 | sed 's/Centrifuger v//'"),emit: versions_centrifuger,  topic: versions
    tuple val("${task.process}"), val('csvtk'), eval("csvtk version | sed -e 's/csvtk v//g'"), emit: versions_csvtk, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    db_name=`find -L ${db} -name "*.1.cfr" -not -name "._*"  | sed 's/\\.1.cfr\$//'`

    centrifuger-quant \\
        -x \$db_name \\
        -c ${classifications} \\
        --output-format 2 |\\
        awk 'BEGIN {
                FS = OFS = "\t"
                print "taxID", "lineage"
            }
            NR > 1 {
                gsub(/\\|/, ";", \$3)
                print \$1, \$3
            }' \\
        > ${prefix}.quant.tsv

    csvtk join \\
        -Ltf '3;1' \\
        ${classifications} \\
        ${prefix}.quant.tsv |\\
        awk 'BEGIN {
                FS = OFS = "\t"
                print "contigs", "predictions"
            }
            NR > 1 {
                print \$1, \$9 ? \$9 : 0
            }' > ${prefix}.lineage.tsv
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.lineage.tsv
    """
}
