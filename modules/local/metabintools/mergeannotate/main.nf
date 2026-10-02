process METABINTOOLS_MERGEANNOTATE {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/e3/e3a2adb7abed4237d28f2a25fdb019acacef6b5d918ad1f1e96c862644809bdc/data'
        : 'community.wave.seqera.io/library/metabintools:0.4.0--e849d6679cb24725' }"

    input:
    tuple val(meta), path(binsfiles), path(trna_gff), path(rrna_gff), path(coverage_tsv), path(quality_tsv), path(taxonomy_tsv)
    val taxonomy_tool
    val quality_tool

    output:
    tuple val(meta), path("*.bins.zstd"), emit: binsfile
    tuple val("${task.process}"), val('metabintools'), eval('metabintools --version | sed "s/metabintools, version //"'), emit: versions_metabintools, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ""
    def args2 = task.ext.args2 ?: ""
    def args3 = task.ext.args3 ?: ""
    def args4 = task.ext.args4 ?: ""
    def args5 = task.ext.args5 ?: ""
    def args6 = task.ext.args6 ?: ""
    def merge_cmd = "metabintools merge ${args} ${binsfiles}"
    def trna_gff_cmd = trna_gff ? "metabintools import annotation ${args2} --gff ${trna_gff}" : ""
    def rrna_gff_cmd = rrna_gff ? "metabintools import annotation ${args3} --gff ${rrna_gff}" : ""
    def depths_cmd = rrna_gff ? "metabintools import coverage ${args4} --coverage ${coverage_tsv}" : ""
    def quality_cmd = quality_tsv ? "metabintools import quality ${args5} --tool ${quality_tool} --quality ${quality_tsv}" : ""
    def taxonomy_cmd = taxonomy_tsv ? "metabintools import taxonomy ${args6} --tool ${taxonomy_tool} --taxonomy ${taxonomy_tsv}" : ""
    def all_cmds = [trna_gff_cmd, rrna_gff_cmd, depths_cmd, quality_cmd, taxonomy_cmd].findAll()
    def cmd_chain = merge_cmd + (all_cmds.size() >= 1 ? " |\\\n" + all_cmds.join(" - |\\\n") : "") + " -zo ${prefix}.bins.zstd"
    """
    ${cmd_chain}
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.bins.zstd
    """
}
