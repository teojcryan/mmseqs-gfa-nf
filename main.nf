/*
========================================================================================
    mmseqs-gfa-nf
========================================================================================
    Pipeline to run MMseqs2 searches on GFA-derived node sequences
    
    Usage:
    nextflow run main.nf --samplesheet <samplesheet.csv> [options]
    
    Options:
      --samplesheet      Path to samplesheet CSV file with query and target information
      --outdir           Output directory (default: 'results')
      --search_type      MMseqs2 search type (default: 3)
      --sensitivity      MMseqs2 sensitivity parameter (default: 7.5)
      --format_mode      Format mode for convertalis (default: 0)
      --format_output    Format output string for convertalis (optional)
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
    nextflow run main.nf --samplesheet <samplesheet.csv> [options]
    
    Required arguments:
      --samplesheet      Path to samplesheet CSV file specifying target and query information
                         Format: [optional: target],target_fasta,[optional: query],query_fasta
    
    Optional arguments:
      --outdir          Output directory (default: '${params.outdir}')
      --search_type     MMseqs2 search type (default: ${params.search_type})
      --sensitivity     MMseqs2 sensitivity parameter (default: ${params.sensitivity})
      --format_mode     Format mode for convertalis (default: ${params.format_mode})
      --format_output   Format output string for convertalis (optional)
    """.stripIndent()
}

// Show help message
if (params.help ) {
    helpMessage()
    exit params.help ? 0 : 1
}

log.info """
=======================================================
mmseqs-gfa-nf v${workflow.manifest.version}
=======================================================
Samplesheet        : ${params.samplesheet}
Output directory   : ${params.outdir}
Work directory     : ${workflow.workDir}
Search type        : ${params.search_type}
Sensitivity        : ${params.sensitivity}
Format mode        : ${params.format_mode}
Format output      : ${params.format_output ?: 'Default'}
=======================================================
"""

workflow {
    if (!params.samplesheet) {
        error "Please supply --samplesheet <path/to/sheet.csv>"
    }

	// Parse samplesheet
    Channel
        .fromPath(params.samplesheet, checkIfExists: true)
        .splitCsv(header: true)
        .set { samples_ch }

    // ========== TARGET PROCESSING ==========
    
	// Extract unique target entries
    targets_ch = samples_ch.map { row ->
        def fasta = file(row.target_fasta)
        def id = row.target ?: fasta.baseName.replaceAll(/\.(fa|fna|fasta)(\.gz)?$/, '')
        tuple([id: id], fasta)
    }.unique { it[0].id }

    // Create target database and index
    MMSEQS_CREATEDB_NODES(targets_ch)
    MMSEQS_CREATEINDEX(MMSEQS_CREATEDB_NODES.out.db)
    
	// ========== QUERY PROCESSING ==========

    // Extract query entries with their target association
    queries_ch = samples_ch.map { row ->
        def qfasta = file(row.query_fasta)
        def tfasta = file(row.target_fasta)
        def qid = row.query ?: qfasta.baseName.replaceAll(/\.(fa|fna|fasta)(\.gz)?$/, '')
        def tid = row.target ?: tfasta.baseName.replaceAll(/\.(fa|fna|fasta)(\.gz)?$/, '')
        tuple([id: qid, target_id: tid], qfasta)
    }.unique { it[0].id }

    // Create query databases
    MMSEQS_CREATEDB_QUERY(queries_ch)
    
    // ========== PAIR QUERIES WITH TARGETS ==========
    
    // Extract target ID from indexed target databases
    target_keys = MMSEQS_CREATEINDEX.out.db_indexed.map { meta, db ->
        [meta.id, [meta, db]]
    }
    
    // Extract target ID from query databases
    query_keys = MMSEQS_CREATEDB_QUERY.out.db.map { meta, db ->
        [meta.target_id, [meta, db]]
    }
    
    // Combine queries with their corresponding targets
    query_target_pairs = query_keys
        .combine(target_keys, by: 0)
        .map { target_id, query_tuple, target_tuple ->
            def (query_meta, query_db) = query_tuple
            def (target_meta, target_db) = target_tuple
            [query_meta, query_db, target_meta, target_db]
        }

    // ========== SEARCH ==========
    
    // Prepare input channels for search
    query_channel = query_target_pairs.map { q_meta, q_db, t_meta, t_db -> 
        tuple(q_meta, q_db) 
    }
    
    target_channel = query_target_pairs.map { q_meta, q_db, t_meta, t_db -> 
        tuple(t_meta, t_db) 
    }
    
    // Run MMseqs2 search
    MMSEQS_SEARCH(query_channel, target_channel)

    // ========== ALIGNMENT CONVERSION ==========
    
    // Add query ID key to original pairs for joining
    keyed_pairs = query_target_pairs.map { q_meta, q_db, t_meta, t_db ->
        [q_meta.id, [q_meta, q_db, t_meta, t_db]]
    }
    
    // Add query ID key to search results for joining
    keyed_results = MMSEQS_SEARCH.out.db_search.map { meta, db ->
        [meta.id, db]
    }
    
    // Join original pairs with search results
    convertalis_inputs = keyed_pairs
        .join(keyed_results)
        .map { query_id, pair_data, search_db ->
            def (q_meta, q_db, t_meta, t_db) = pair_data
            [q_meta, q_db, t_meta, t_db, search_db]
        }

    // Prepare input channels for convertalis
    query_db_channel = convertalis_inputs.map { q_meta, q_db, t_meta, t_db, s_db -> 
        tuple(q_meta, q_db) 
    }
    
    target_db_channel = convertalis_inputs.map { q_meta, q_db, t_meta, t_db, s_db -> 
        tuple(t_meta, t_db) 
    }
    
    search_db_channel = convertalis_inputs.map { q_meta, q_db, t_meta, t_db, s_db -> 
        tuple(q_meta, s_db) 
    }
    
    // Convert alignments to output format
    MMSEQS_CONVERTALIS(
        query_db_channel,
        target_db_channel,
        search_db_channel
    )
}