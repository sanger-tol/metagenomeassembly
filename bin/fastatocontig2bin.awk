## Create a contig2bin file from a set of input
## FASTA files
##
## Author: Jim Downie

BEGIN { OFS = "\t" }
BEGINFILE {
    bin = FILENAME
    sub(".*/", "", bin)
    sub(/\\.[^\\.]+\$/, "", bin)
}
/^>/ {
    sub(/>/, "", \$1)
    print \$1, bin
}