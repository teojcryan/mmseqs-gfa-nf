#!/usr/bin/env nextflow

include { MMSEQS_CREATEDB }   from './modules/nf-core/mmseqs/createdb/main.nf'
include { MMSEQS_CREATEINDEX }   from './modules/nf-core/mmseqs/createindex/main.nf'
include { MMSEQS_SEARCH }   from './modules/nf-core/mmseqs/search/main.nf'
include { MMSEQS_EASYSEARCH }   from './modules/nf-core/mmseqs/easysearch/main.nf'
