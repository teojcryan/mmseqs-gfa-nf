# mmseqs-gfa-nf

A Nextflow pipeline designed to run MMseqs2 searches on node sequences derived from GFA (Graphical Fragment Assembly) files. This workflow enables efficient sequence searching against genome assembly graphs.

## Overview

Graph-based genome representations offer advantages over traditional linear assemblies by preserving complex genomic relationships. This pipeline facilitates searching query sequences against node sequences extracted from genome graphs, leveraging the high-performance capabilities of MMseqs2 for sensitive and rapid sequence searching. This is especially useful for large-scale, fragmented graphs with many nodes, such as those generated from shotgun metagenomic sequencing reads.

The workflow extracts unique target and query entries from a samplesheet, creates `MMseqs2` databases, builds search indices, performs similarity searches, and converts the alignment results to a user-friendly format.

## Dependencies

- [Nextflow](https://www.nextflow.io/) >= 22.10.0
- [MMseqs2](https://github.com/soedinglab/MMseqs2) >= 17.b804f
- Container engines (optional): Docker, Singularity, Podman, or Charliecloud

## Installation

```bash
# Clone the repository
git clone https://github.com/ryant/mmseqs-gfa-nf.git
cd mmseqs-gfa-nf
```

## Usage

The pipeline requires a samplesheet in CSV format specifying target and query sequences:

```bash
nextflow run main.nf --samplesheet path/to/samplesheet.csv [options]
```

### Samplesheet Format

The samplesheet must be a CSV file with the following columns:
- `target`: Identifier for the target database (optional, derived from `target_fasta` filename if missing)
- `target_fasta`: Path to the target FASTA file (typically node sequences from a GFA)
- `query`: Identifier to the query database (optional, derived from `query_fasta` filename if mising)
- `query_fasta`: Path to the query FASTA file

Example samplesheet:
```csv
target,target_fasta,query,query_fasta
target1,/path/to/target1.fasta,query1,path/to/query1.fasta
target1,/path/to/target1.fasta,query2,path/to/query2.fasta
```

### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `--samplesheet` | Path to samplesheet CSV file | Required |
| `--outdir` | Output directory for results | `results` |
| `--search_type` | MMseqs2 search type (0: auto 1: amino acid, 2: translated, 3: nucleotide) | `3` |
| `--sensitivity` | MMseqs2 sensitivity parameter | `7.5` |
| `--format_mode` | Format mode for convertalis | `0` |
| `--format_output` | Format output string for convertalis | None |

## Pipeline Structure

The workflow follows these main steps:

1. **Sample Processing**: Parses the samplesheet to extract target and query information
2. **Target Processing**: Creates `MMseqs2` databases from target FASTA files and builds search indices
3. **Query Processing**: Creates `MMseqs2` databases from query FASTA files
4. **Search**: Performs `MMseqs2` sequence searches of queries against targets
5. **Result Conversion**: Converts search results to user-friendly formats

## Output

Results are organized in the specified output directory:
- `alignments/`: Contains the alignment results in the requested format (M8/TSV)

The output format depends on the `format_mode` parameter:
- `0`: BLAST-TAB format (.m8)
- Other values: Tab-separated values (.tsv)

## Resource Configuration

Resource allocation can be modified in the `nextflow.config` file:

```groovy
process {
    withLabel:process_single  { cpus = 1;  memory = 6.GB;  time = 4.h }
    withLabel:process_low     { cpus = 2;  memory = 12.GB; time = 4.h }
    withLabel:process_medium  { cpus = 6;  memory = 36.GB; time = 8.h }
    withLabel:process_high    { cpus = 12; memory = 72.GB; time = 16.h }
}
```

Process-specific configurations can be adjusted as needed:

```groovy
withName: MMSEQS_SEARCH {
    ext.args = "--search-type ${params.search_type} -s ${params.sensitivity}"
    ext.prefix = "search_results"
}
```

## Advanced Usage

### Working with GFA Files

This pipeline is designed to work with sequences extracted from GFA files. You'll need to extract node sequences from your GFA file before using this pipeline:

```bash
# Example of extracting sequences from GFA using awk
awk '/^S/{print ">"$2"\n"$3}' assembly.gfa > nodes.fasta
```

### Adjusting Search Sensitivity

MMseqs2 sensitivity can be tuned based on your specific use case:
- Lower values (1-4): Faster but potentially less sensitive
- Higher values (5-9): More sensitive but slower
- Default (7.5): Balanced approach

```bash
nextflow run main.nf --samplesheet data.csv --sensitivity 9.0
```

## Use Cases

- **Metagenome Analysis**: Search reference genomes against metagenomic assembly graphs
- **Pan-Genome Studies**: Compare query sequences against a pan-genome graph
- **Variant Detection**: Identify strain-specific sequences in graph representations

## Citation

If you use this pipeline in your research, please cite:

```
MMseqs2: 
Steinegger M & Söding J. MMseqs2 enables sensitive protein sequence searching for the analysis of massive data sets. Nature Biotechnology, 35, 1026–1028 (2017)

Nextflow:
Di Tommaso P, et al. Nextflow enables reproducible computational workflows. Nature Biotechnology 35, 316-319 (2017)
```

## License

This pipeline is released under the MIT license.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Support

For questions or issues, please open an issue on the GitHub repository.