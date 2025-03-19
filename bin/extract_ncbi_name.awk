## Extact the highest level NCBI rank converted by the
## gtdb_to_ncbi_majority_vote.py script and save it to
## a new column to parse with taxonkit.
##
## Author: Jim Downie, December 2024

BEGIN {
    FS = "\t"
    OFS = FS
}
NR == 1 { print $1, $2, $3, "name", "taxid" }
NR > 1 {
    if($0 ~ /Unclassified/) {
        print $1, $2, $3, $3
        next
    }
    n_elem = split($3, names, /;?[[:alpha:]]__/)
    for(i = n_elem; i > 1; i--) {
        if(names[i] != "") {
            if(i == 7)  {
                name_addendum = ""
            } else if(i == 6) {
                name_addendum = " sp."
            }
            else {
                name_addendum = " bacterium"
            }

            print $1, $2, $3, names[i] name_addendum
            break
        }
    }
}
