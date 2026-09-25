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

import logging
from pathlib import Path

import click
import pyfastx

logger = logging.getLogger(__name__)


def get_extension(file: Path) -> str:
    if file.suffix == ".gz":
        return "".join(file.suffixes[-2:])
    return file.suffix


def get_basename(file: Path) -> str:
    if file.suffix == ".gz":
        return file.name.rsplit(".", 2)[0]
    else:
        return file.name.rsplit(".", 1)[0]


@click.command()
@click.version_option(version="1.0.0")
@click.option("--circular-list", type=click.Path(exists=True))
@click.option("--prefix", type=str)
@click.argument("bindir", type=click.Path(exists=True))
def count_circles(circular_list, bindir, prefix):
    binfiles = list(
        p
        for p in Path(bindir).glob("*")
        if get_extension(p)
        in {".fa", ".fna", ".fasta", ".fa.gz", ".fna.gz", ".fasta.gz"}
    )
    logger.info(f"Found {len(binfiles)} FASTA files")

    circular_contigs = []
    with open(circular_list, "r") as f:
        for line in f:
            circular_contigs.append(line.strip())

    with open(f"{prefix}.circles.tsv", "w") as f:
        f.write("bin\tn_circular\n")
        for bin in binfiles:
            basename = get_basename(bin)
            fasta = pyfastx.Fastx(bin)
            n_circular = 0
            for id, _seq in fasta:
                if id in circular_contigs:
                    n_circular += 1
            f.write(f"{basename}\t{n_circular}\n")


if __name__ == "__main__":
    count_circles()
