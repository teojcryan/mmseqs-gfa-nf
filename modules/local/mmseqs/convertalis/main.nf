process MMSEQS_CONVERTALIS {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mmseqs2:17.b804f--hd6d6fdc_1':
        'biocontainers/mmseqs2:17.b804f--hd6d6fdc_1' }"

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

    if ("${db_query}" == "${prefix}" || "${db_target}" == "${prefix}") {
        error("Input and output names of databases are the same, set prefix in module configuration to disambiguate!")
    }
    """
    mmseqs convertalis \
        ${db_query} \
        ${db_target} \
        ${db_alignment} \
        ${out_file} \
        --format-mode ${params.format_mode} \
        ${ params.format_output ? "--format-output ${params.format_output}" : "" } \
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
