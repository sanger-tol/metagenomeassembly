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

from pathlib import Path

import click
import pyfastx


def get_stem(path):
    stem = Path(path).stem
    return Path(stem).stem if path.endswith(".gz") else stem


@click.command()
@click.version_option(version="1.0.0", message="%(version)s")
@click.option("--fasta", type=click.Path(exists=True), multiple=True, required=True)
@click.option("--id", type=str, multiple=True)
@click.option("--separator", default=":", type=str)
def concatenate_fasta(fasta, id, separator):
    if id and (len(fasta) != len(id)):
        raise ValueError("Number of fasta files and ids must be the same")

    if len(id) != len(set(id)):
        raise ValueError("All ids must be unique")

    ids = list(id) if id else [get_stem(f) for f in fasta]

    for file, name in zip(fasta, ids):
        try:
            f = pyfastx.Fastx(file, comment=True)
            for seqid, seq, desc in f:
                if separator in desc:
                    raise ValueError(
                        f"Separator '{separator}' found in description: {desc}"
                    )
                click.echo(f">{name}{separator}{seqid} {desc}")
                click.echo(seq)
        except Exception as e:
            raise click.ClickException(f"Error processing {file}: {e}")


if __name__ == "__main__":
    concatenate_fasta()
