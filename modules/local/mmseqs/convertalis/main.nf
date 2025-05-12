process MMSEQS_CONVERTALIS {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mmseqs2:4.bff50--h21aa3a5_1':
        'quay.io/biocontainers/mmseqs2:17-b804f' }"

    input:
    tuple val(meta), path(db_query)
    tuple val(meta2), path(db_target)
    tuple val(meta3), path(db_alignment)

    output:
    tuple val(meta), path("*.{m8,tsv}"), emit: result
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def args2 = task.ext.args2 ?: "*.dbtype"
    def args3 = task.ext.args3 ?: "*.dbtype"
    def out_file = "${prefix}_${meta2.id}_${meta.id}${params.format_mode == 0 ? '.m8' : '.tsv'}"

    if ("${db_query}" == "${prefix}" || "${db_target}" == "${prefix}") {
        error("Input and output names of databases are the same, set prefix in module configuration to disambiguate!")
    }
    """
    # Extract files with specified args based suffix | remove suffix | isolate longest common substring of files
    DB_QUERY_PATH_NAME=\$(find -L "${db_query}/" -maxdepth 1 -name "${args2}" | sed 's/\\.[^.]*\$//' | sed -e 'N;s/^\\(.*\\).*\\n\\1.*\$/\\1\\n\\1/;D' )
    DB_TARGET_PATH_NAME=\$(find -L "${db_target}/" -maxdepth 1 -name "${args3}" | sed 's/\\.[^.]*\$//' | sed -e 'N;s/^\\(.*\\).*\\n\\1.*\$/\\1\\n\\1/;D' )
    DB_ALIGNMENT_PATH_NAME=\$(find -L "${db_alignment}/" -maxdepth 1 -name "${args2}" | sed 's/\\.[^.]*\$//' | sed -e 'N;s/^\\(.*\\).*\\n\\1.*\$/\\1\\n\\1/;D' )

    mmseqs convertalis \\
        \$DB_QUERY_PATH_NAME \\
        \$DB_TARGET_PATH_NAME \\
        \$DB_ALIGNMENT_PATH_NAME \\
        ${out_file} \\
        --format-mode ${params.format_mode} \\
        ${ params.format_output ? "--format-output ${params.format_output}" : "" } \\
        ${task.ext.args ?: ''}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mmseqs: \$(mmseqs | grep 'Version' | sed 's/MMseqs2 Version: //')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    if ("$db_query" == "${prefix}" || "$db_target" == "${prefix}"  ) error "Input and output names of databases are the same, set prefix in module configuration to disambiguate!"
    """
    touch ${out_file}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mmseqs: \$(mmseqs | grep 'Version' | sed 's/MMseqs2 Version: //')
    END_VERSIONS
    """
}
