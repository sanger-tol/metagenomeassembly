## Summarise information about tRNA and rRNA contents
## given by Prokka for a genome bin
##
## Author: Jim Downie, 2024

BEGIN {
    FS = "\t"
    OFS = FS
    print "bin", "total_trnas", "unique_trnas"
}
BEGINFILE {
    bin = FILENAME
    sub(".*/", "", bin)
    sub(/\.[^\.]+$/, "", bin)
    unique_trnas = 0
}
{
    trna_arr[$5] = 1
}
ENDFILE {
    for (i in trna_arr) { unique_trnas++ }
    delete trna_arr
    print bin, NR, unique_trnas
}
