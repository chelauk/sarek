include { initOptions; saveFiles; getSoftwareName } from './../functions'

params.options = [:]
def options    = initOptions(params.options)

process GATK4_APPLYBQSR {
    tag "$meta.id"
    label 'process_medium'
    publishDir params.outdir, mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), publish_id:meta.id) }

    conda (params.enable_conda ? "bioconda::gatk4=4.2.0.0" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/gatk4:4.2.0.0--0"
    } else {
        container "quay.io/biocontainers/gatk4:4.2.0.0--0"
    }

    input:
    tuple val(meta), path(bam), path(bai), path(recalibrationReport), path(interval)
    path dict
    path fasta
    path fai

    output:
    tuple val(meta), path("${prefix}${meta.sample}.recal.bam") , emit: bam
    path "*.version.txt" , emit: version

    script:
    def software = getSoftwareName(task.process)
    prefix = params.no_intervals ? "" : "${interval.baseName}_"
    options_intervals = params.no_intervals ? "" : "-L ${interval}"
    """
    gatk --java-options -Xmx${task.memory.toGiga()}g \
        ApplyBQSR \
        -R ${fasta} \
        --input ${bam} \
        --output ${prefix}${meta.sample}.recal.bam \
        ${options_intervals} \
        --bqsr-recal-file ${recalibrationReport}

    echo \$(gatk ApplyBQSR --version 2>&1) | sed 's/^.*(GATK) v//; s/ HTSJDK.*\$//' > ${software}.version.txt
    """
}