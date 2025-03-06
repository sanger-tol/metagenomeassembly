def readYAML(yamlfile) {
    return new org.yaml.snakeyaml.Yaml().load(yamlfile.text)
}

process READ_YAML {
    executor "local"

    input:
    val(yaml)
    val(enable_assembly)

    output:
    tuple val(meta)    , val(pacbio)  , emit: pacbio_fasta
    tuple val(meta)    , val(hic_cram), emit: hic_cram
    tuple val(asm_meta), val(assembly), emit: assembly
    val(hic_enzymes)                  , emit: hic_enzymes

    exec:
    // Read input
    def input = readYAML(yaml)

    // Generate meta map
    id          = input.id
    meta        = [id: id]

    // Process input files
    // Raw data
    pacbio      = input.pacbio.fasta.flatten()
    hic_cram    = input?.hic?.cram    ? input.hic.cram.flatten()    : []
    hic_enzymes = input?.hic?.enzymes ? input.hic.enzymes.flatten() : []

    // Assembly
    assembly    = input?.assembly?.fasta     ? input.assembly.fasta                          : []
    asm_meta    = input?.assembly?.assembler ? meta + [assembler: input.assembly.assembler]  : meta
}
