#!/usr/bin/env nextflow

/*
========================================================================================
    mmseqs-gfa-nf
========================================================================================
    Pipeline to run MMseqs2 searches on GFA-derived node sequences
    
    Usage:
    nextflow run main.nf --nodes <nodes_fasta> --query <query_fasta> [options]
    
    Options:
      --nodes           Path to the nodes FASTA file (e.g., from GFA)
      --query           Path to the query FASTA file
      --outdir          Output directory (default: 'results')
      --search_type     MMseqs2 search type (default: 3)
      --sensitivity     MMseqs2 sensitivity parameter (default: 7.5)
      --format_mode     Format mode for convertalis (default: 0)
      --format_output   Format output string for convertalis (optional)
*/

include { MMSEQS_CREATEDB as MMSEQS_CREATEDB_NODES } from './modules/nf-core/mmseqs/createdb/main.nf'
include { MMSEQS_CREATEDB as MMSEQS_CREATEDB_QUERY } from './modules/nf-core/mmseqs/createdb/main.nf'
include { MMSEQS_CREATEINDEX }   from './modules/nf-core/mmseqs/createindex/main.nf'
include { MMSEQS_SEARCH }   from './modules/nf-core/mmseqs/search/main.nf'
include { MMSEQS_EASYSEARCH }   from './modules/nf-core/mmseqs/easysearch/main.nf'
include { MMSEQS_CONVERTALIS }   from './modules/local/mmseqs/convertalis/main.nf'

// Print help message
def helpMessage() {
    log.info"""
    =========================================
      mmseqs-gfa-nf v${workflow.manifest.version}
    =========================================
    
    Usage:
    nextflow run main.nf --nodes <nodes_fasta> --query <query_fasta> [options]
    
    Required arguments:
      --nodes           Path to the nodes FASTA file (e.g., from GFA)
      --query           Path to the query FASTA file
    
    Optional arguments:
      --outdir          Output directory (default: '${params.outdir}')
      --search_type     MMseqs2 search type (default: ${params.search_type})
      --sensitivity     MMseqs2 sensitivity parameter (default: ${params.sensitivity})
      --format_mode     Format mode for convertalis (default: ${params.format_mode})
      --format_output   Format output string for convertalis (optional)
    """.stripIndent()
}

// Show help message
if (params.help || params.nodes == null || params.query == null) {
    helpMessage()
    exit params.help ? 0 : 1
}

// Validate inputs
if (params.nodes == null) {
    exit 1, "Nodes FASTA file not specified!"
}

if (params.query == null) {
    exit 1, "Query FASTA file not specified!"
}

log.info """
=======================================================
mmseqs-gfa-nf v${workflow.manifest.version}
=======================================================
Nodes FASTA        : ${params.nodes}
Query FASTA        : ${params.query}
Output directory   : ${params.outdir}
Work directory     : ${workflow.workDir}
Search type        : ${params.search_type}
Sensitivity        : ${params.sensitivity}
Format mode        : ${params.format_mode}
Format output      : ${params.format_output ?: 'Default'}
=======================================================
"""

// Run the workflow
workflow {
    // Create input channels
    ch_nodes = Channel
        .fromPath(params.nodes, checkIfExists: true)
        .map { file -> [ [id: file.simpleName], file ] }

    ch_query = Channel
        .fromPath(params.query, checkIfExists: true)
        .map { file -> [ [id: file.simpleName], file ] }

    // Create MMseqs2 database for the nodes
    MMSEQS_CREATEDB_NODES(
        ch_nodes
    )

    // Create index for the nodes database
    MMSEQS_CREATEINDEX(
        MMSEQS_CREATEDB_NODES.out.db
    )

    // Create MMseqs2 database for the query
    MMSEQS_CREATEDB_QUERY(
        ch_query
    )

    // Perform the search
    MMSEQS_SEARCH(
        MMSEQS_CREATEDB_QUERY.out.db,  		// Query database
        MMSEQS_CREATEINDEX.out.db_indexed  	// Target database (indexed)
    )

    // Convert the alignment database to output format
    MMSEQS_CONVERTALIS(
        MMSEQS_CREATEDB_QUERY.out.db,     	// Query database
        MMSEQS_CREATEINDEX.out.db_indexed, 	// Target database
        MMSEQS_SEARCH.out.db_search       	// Alignment database
    )
}