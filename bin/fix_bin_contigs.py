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

import gzip
import re
from pathlib import Path
from typing import Pattern

import click
import pyfastx


def get_extension(file: Path) -> str:
    if file.suffix == ".gz":
        return "".join(file.suffixes[-2:])
    return file.suffix


def get_basename(file: Path) -> str:
    if file.suffix == ".gz":
        return file.name.rsplit(".", 2)[0]
    else:
        return file.name.rsplit(".", 1)[0]


def extract_match(regex: Pattern[str], x: str) -> str:
    res = regex.search(x)

    if res:
        return res.group(1)
    else:
        raise ValueError(f"No match found for regex '{regex}' in '{x}'")


@click.command()
@click.version_option(version="1.0.0")
@click.argument("bindir", type=click.Path(exists=True))
@click.option("--regex", type=str, help="Regex pattern to extract from contig header")
@click.option("--outdir", type=click.Path(), help="Output directory for fixed contigs")
def main(bindir, regex, outdir):
    """Drop FASTA comments for each genome bin. Optionally extract a regex group from the contig header."""
    if not Path(outdir).exists():
        Path(outdir).mkdir(parents=True, exist_ok=True)

    if regex:
        r: Pattern[str] = re.compile(regex)
        if r.groups != 1:
            raise click.ClickException("Regex pattern must have exactly one group!")

    binfiles = list(
        p
        for p in Path(bindir).glob("*")
        if get_extension(p)
        in {".fa", ".fna", ".fasta", ".fa.gz", ".fna.gz", ".fasta.gz"}
    )

    if not binfiles:
        raise click.ClickException(f"No FASTA files found in '{bindir}'")

    for bin in binfiles:
        bin_name = get_basename(bin)
        bin_ext = get_extension(bin)

        try:
            if regex:
                f = pyfastx.Fasta(bin, key_func=lambda x: extract_match(r, x))
            else:
                f = pyfastx.Fasta(bin)

            if bin.suffix == ".gz":
                opener = gzip.open
            else:
                opener = open

            with opener(Path(outdir) / f"{bin_name}.fixed{bin_ext}", "wt") as out:
                for seq in f:
                    out.write(f">{seq.name}\n{seq.seq}\n")
        except ValueError:
            raise click.ClickException(f"Failed to process {bin.name}")
