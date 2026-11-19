#!/usr/bin/env python3
#
#    Copyright (C) 2026 Genome Research Ltd.
#
#    Author: Jim Downie <jd42@sanger.ac.uk>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

import csv
import gzip
import re
from pathlib import Path

import click
import pyfastx

CIRCULAR_REGEX = re.compile(r"circular=yes|circular-yes|circular-possibly")


def get_tiara_exclusions(
    tiara_classifications: Path,
    exclude_domains: list[str],
    id: str | None = None,
    separator: str = ":",
) -> set:
    """Parse a Tiara classifications file and return a set of excluded contigs."""
    excluded_contigs = set()
    exclude_domains_set = set(exclude_domains)  # O(1) lookup

    with open(tiara_classifications) as f:
        reader = csv.DictReader(f, delimiter="\t")
        for row in reader:
            if row["class_fst_stage"] in exclude_domains_set:
                if id:
                    excluded_contigs.add(f"{id}{separator}{row['sequence_id']}")
                else:
                    excluded_contigs.add(row["sequence_id"])

    return excluded_contigs


def check_circular(header: str) -> bool:
    """Check if a contig is circular based on the assembler and header."""
    return bool(CIRCULAR_REGEX.search(header))


@click.command()
@click.version_option(version="1.0.0", message="%(version)s")
@click.argument("assembly", type=click.Path(exists=True))
@click.option("--extract-circles/--no-extract-circles", is_flag=True)
@click.option("--minimum-contig-size", type=int, default=0)
@click.option("--maximum-contig-size", type=int)
@click.option("--minimum-circular-contig-length", type=int, default=0)
@click.option("--tiara", type=click.Path(exists=True), multiple=True)
@click.option("--exclude-domain", type=str, multiple=True)
@click.option("--tiara-id", type=str, multiple=True)
@click.option("--separator", type=str, default=":")
@click.option("--prefix", type=str)
def main(
    assembly: str,
    extract_circles: bool,
    minimum_contig_size: int,
    maximum_contig_size: int,
    minimum_circular_contig_length: int,
    tiara: str,
    exclude_domain: str,
    tiara_id: str,
    separator: str,
    prefix: str,
):
    """
    Filter a metagenome assembly based on circularity, contig size and tiara classifications. Writes
    a filtered contigs file, and optionally a file of circular contigs and a list of excluded contigs
    if they have content.
    """
    excluded_contigs = set()
    included_contigs = set()
    circular_contigs = []

    # Validate that tiara_id length matches tiara_classifications or is empty
    if len(tiara_id) not in (0, len(tiara)):
        raise ValueError(
            f"tiara_id should either be skipped or provided once for each tiara_classifications file ({len(tiara)} times)."
        )

    tiara_exclude_contigs = set()
    if tiara and exclude_domain:
        tiara_ids = tiara_id if tiara_id else [None] * len(tiara)
        for classif, id in zip(tiara, tiara_ids):
            tiara_exclude_contigs.update(
                get_tiara_exclusions(Path(classif), list(exclude_domain), id, separator)
            )

    with open(f"{prefix}_filtered.fasta", "w") as contig_out:
        fasta = pyfastx.Fastx(assembly, comment=True)
        for seq_id, seq, comment in fasta:
            seq_len = len(seq)
            header = f"{seq_id} {comment}"

            if seq_len < minimum_contig_size:
                excluded_contigs.add(seq_id)
                continue

            if maximum_contig_size and seq_len > maximum_contig_size:
                excluded_contigs.add(seq_id)
                continue

            if seq_id in tiara_exclude_contigs:
                excluded_contigs.add(seq_id)
                continue

            if (
                extract_circles
                and check_circular(header)
                and seq_len > minimum_circular_contig_length
            ):
                excluded_contigs.add(seq_id)
                circular_contigs.append((header, seq))
                continue

            included_contigs.add(seq_id)
            contig_out.write(f">{header}\n{seq}\n")

    # Write circles file only if there are circular contigs
    if circular_contigs:
        with (
            gzip.open(f"{prefix}.circles.fasta.gz", "wt") as circular_fasta_out,
            open(f"{prefix}.circles.list", "w") as circular_list_out,
        ):
            for header, seq in circular_contigs:
                circular_fasta_out.write(f">{header}\n{seq}\n")
                circular_list_out.write(f"{header.split()[0]}\n")

    with open(f"{prefix}.exclude.list", "w") as exclude_out:
        for seq_id in excluded_contigs:
            exclude_out.write(f"{seq_id}\n")

    with open(f"{prefix}.include.list", "w") as include_out:
        for seq_id in included_contigs:
            include_out.write(f"{seq_id}\n")


if __name__ == "__main__":
    main()
