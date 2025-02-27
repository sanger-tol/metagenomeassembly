def readYAML(yamlfile) {
    return new org.yaml.snakeyaml.Yaml().load(yamlfile.text)
}

process READ_YAML {
    executor "local"

    input:
    val(yaml)

    output:
    tuple val(meta)    , val(pacbio)  , emit: pacbio_fasta
    tuple val(meta)    , val(hic_cram), emit: hic_cram
    tuple val(asm_meta), val(assembly), emit: assembly
    val(hic_enzymes)                  , emit: hic_enzymes

    exec:
    // Read input
    def input = readYAML(yaml)

    // Check input types
    if(!input.pacbio.fasta.find()) {
        error("ERROR: Pacbio reads not provided! Pipeline will not run as there is nothing to do.")
    }
    if(input.hic.cram.find() && !input.hic.enzymes.find()) {
        error("ERROR: Hi-C files provided but no enzymes!")
    }
    if(input.assembly.fasta.find() && !input.assembly.assembler.find()) {
        error("ERROR: Assembly FASTA provided but the assembler was not named!!")
    }

    // Generate meta map
    id          = input.id
    meta        = [id: id]

    // Process input files
    // Raw data
    pacbio      = input.pacbio.fasta.flatten()
    hic_cram    = input.hic.cram.find()    ? input.hic.cram.flatten()    : []
    hic_enzymes = input.hic.enzymes.find() ? input.hic.enzymes.flatten() : []

    // Assembly
    assembly    = input.assembly.fasta.find()     ? input.assembly.fasta                          : []
    asm_meta    = input.assembly.assembler.find() ? meta + [assembler: input.assembly.assembler]  : meta
}
