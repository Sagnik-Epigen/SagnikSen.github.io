#!/usr/bin/env nextflow
/*
 * NEEDseq pipeline
 * ----------------
 * Paired-end NEEDseq processing for human, mouse, Drosophila and Arabidopsis:
 *   trim (Trim Galore) -> align (Bowtie2) -> sort/index (samtools)
 *   -> remove PCR duplicates (Picard) -> drop chrM / chloroplast / unplaced contigs
 *   -> call narrow + broad peaks (MACS3) -> RPKM bigWig + enrichment plots (deepTools)
 *   -> QC summary (MultiQC)
 */
nextflow.enable.dsl = 2

// Species names / short codes accepted by --genome, mapped to a genome build in conf/genomes.config
def genomeAliases() {
    [
        human      : 'hg38',   hs  : 'hg38',
        mouse      : 'mm10',   mm  : 'mm10',
        drosophila : 'dm6',    fly : 'dm6',    dm : 'dm6',
        arabidopsis: 'tair10', at  : 'tair10', ath: 'tair10',
    ]
}

def helpMessage() {
    """
    NEEDseq pipeline

    Usage:
      nextflow run main.nf --input samplesheet.csv --genome human -profile conda
      nextflow run main.nf --reads 'data/*.{1,2}.fastq.gz' --genome mouse -profile docker

    Input (one of):
      --input          CSV with columns: sample,fastq_1,fastq_2
      --reads          Glob for paired FASTQs, e.g. 'data/*_R{1,2}.fastq.gz'

    Genome:
      --genome         human|hs|hg38, mouse|mm|mm10|mm39, drosophila|fly|dm|dm6,
                       arabidopsis|at|tair10                       [${params.genome}]
      --index_dir      Where scripts/build_index.sh put the indices [${params.index_dir}]
      --bowtie2_index  Explicit Bowtie2 index prefix (overrides --index_dir)
      --keep_chroms    Space-separated chromosomes to keep (overrides genome default)
      --macs_gsize     MACS3 effective genome size (overrides genome default)

    Options:
      --outdir         Output directory                             [${params.outdir}]
      --clip_r1/--clip_r2, --three_prime_clip_r1/--three_prime_clip_r2
                       Trim Galore hard clipping                    [4]
      --max_fragment   Bowtie2 -X max fragment length               [${params.max_fragment}]
      --min_mapq       Minimum MAPQ kept after alignment (0 = off)  [${params.min_mapq}]
      --bin_size       bamCoverage bin size                         [${params.bin_size}]
      --skip_multiqc   Skip the MultiQC report
    """.stripIndent()
}

/*
 * PROCESSES
 */

process TRIM_READS {
    tag "$sample"
    label 'process_medium'
    publishDir "${params.outdir}/${sample}/trimmed", mode: params.publish_mode

    input:
    tuple val(sample), path(reads)

    output:
    tuple val(sample), path("${sample}_val_*.fq.gz"), emit: reads
    path "*_trimming_report.txt",                     emit: reports
    path "*_fastqc.{zip,html}",                       emit: fastqc

    script:
    """
    trim_galore ${reads[0]} ${reads[1]} \\
        --paired --gzip --fastqc \\
        --basename ${sample} \\
        --clip_R1 ${params.clip_r1} --clip_R2 ${params.clip_r2} \\
        --three_prime_clip_R1 ${params.three_prime_clip_r1} \\
        --three_prime_clip_R2 ${params.three_prime_clip_r2} \\
        --cores ${Math.min(task.cpus as int, 4)}
    """
}

process ALIGN_READS {
    tag "$sample"
    label 'process_high'
    publishDir "${params.outdir}/${sample}/alignment", mode: params.publish_mode

    input:
    tuple val(sample), path(reads)
    path index_files
    val index_name

    output:
    tuple val(sample), path("${sample}.sorted.bam"), path("${sample}.sorted.bam.bai"), emit: bam
    path "${sample}.bowtie2.log",                                                    emit: log

    script:
    """
    bowtie2 -x ${index_name} -1 ${reads[0]} -2 ${reads[1]} \\
        --dovetail --no-unal --no-discordant --no-mixed --very-sensitive \\
        -I 0 -X ${params.max_fragment} -p ${task.cpus} \\
        2> ${sample}.bowtie2.log \\
        | samtools sort -@ ${task.cpus} -o ${sample}.sorted.bam -
    samtools index ${sample}.sorted.bam
    """
}

process REMOVE_DUPLICATES {
    tag "$sample"
    label 'process_medium'
    publishDir "${params.outdir}/${sample}/alignment", mode: params.publish_mode

    input:
    tuple val(sample), path(bam), path(bai)

    output:
    tuple val(sample), path("${sample}.dedup.bam"), path("${sample}.dedup.bam.bai"), emit: bam
    path "${sample}.dup_metrics.txt",                                              emit: metrics

    script:
    def xmx = task.memory ? "-Xmx${Math.max(1, (task.memory.toGiga() * 0.8) as int)}g" : ''
    """
    picard ${xmx} MarkDuplicates \\
        --INPUT ${bam} \\
        --OUTPUT ${sample}.dedup.bam \\
        --METRICS_FILE ${sample}.dup_metrics.txt \\
        --REMOVE_DUPLICATES true \\
        --VALIDATION_STRINGENCY LENIENT
    samtools index ${sample}.dedup.bam
    """
}

// Keeps only the nuclear chromosomes for the genome: removes chrM, chloroplast and unplaced contigs
process FILTER_CHROMOSOMES {
    tag "$sample"
    label 'process_low'
    publishDir "${params.outdir}/${sample}/alignment", mode: params.publish_mode

    input:
    tuple val(sample), path(bam), path(bai)
    val keep_chroms

    output:
    tuple val(sample), path("${sample}.filtered.bam"), path("${sample}.filtered.bam.bai"), emit: bam
    path "${sample}.filtered.flagstat",                                                  emit: flagstat

    script:
    def mapq = params.min_mapq > 0 ? "-q ${params.min_mapq}" : ''
    """
    samtools view -@ ${task.cpus} -h -b ${mapq} -o ${sample}.filtered.bam ${bam} ${keep_chroms}
    samtools index ${sample}.filtered.bam
    samtools flagstat ${sample}.filtered.bam > ${sample}.filtered.flagstat
    """
}

process CALL_PEAKS {
    tag "$sample"
    label 'process_low'
    publishDir "${params.outdir}/${sample}/macs3", mode: params.publish_mode

    input:
    tuple val(sample), path(bam), path(bai)
    val gsize

    output:
    tuple val(sample), path("${sample}_N_peaks.narrowPeak"), path("${sample}_B_peaks.broadPeak"), emit: peaks
    path "${sample}_{N,B}_*",                                                                   emit: all

    script:
    """
    macs3 callpeak -t ${bam} -f BAMPE -m 4 100 -g ${gsize} --bdg --SPMR \\
        --outdir . -n ${sample}_N
    macs3 callpeak -t ${bam} -f BAMPE -m 4 100 -g ${gsize} --bdg --SPMR --broad \\
        --outdir . -n ${sample}_B
    """
}

process COVERAGE_AND_PLOTS {
    tag "$sample"
    label 'process_medium'
    publishDir "${params.outdir}/${sample}/coverage", mode: params.publish_mode

    input:
    tuple val(sample), path(bam), path(bai), path(narrow), path(broad)

    output:
    path "${sample}.bw",       emit: bigwig
    path "${sample}_{N,B}.png", emit: plots
    path "${sample}_*_counts.tsv", emit: counts

    script:
    """
    bamCoverage --bam ${bam} -o ${sample}.bw \\
        --normalizeUsing RPKM --binSize ${params.bin_size} -p ${task.cpus}
    plotEnrichment --bamfiles ${bam} --BED ${narrow} -p ${task.cpus} \\
        -o ${sample}_N.png --outRawCounts ${sample}_N_counts.tsv
    plotEnrichment --bamfiles ${bam} --BED ${broad} -p ${task.cpus} \\
        -o ${sample}_B.png --outRawCounts ${sample}_B_counts.tsv
    """
}

process MULTIQC {
    label 'process_low'
    publishDir "${params.outdir}/multiqc", mode: params.publish_mode

    input:
    path qc_files

    output:
    path "multiqc_report.html"
    path "multiqc_report_data"

    script:
    """
    multiqc --force --filename multiqc_report.html .
    """
}

/*
 * WORKFLOW
 */

workflow {
    if (params.help) {
        log.info helpMessage()
        exit 0
    }

    // ---- Resolve genome settings -------------------------------------------------------
    def requested  = params.genome.toString().toLowerCase()
    def aliases    = genomeAliases()
    def genome_key = aliases.get(requested, requested)
    if (!params.genomes.containsKey(genome_key)) {
        error "Unknown --genome '${params.genome}'. Choose one of: ${(aliases.keySet() + params.genomes.keySet()).join(', ')}"
    }
    def genome     = params.genomes[genome_key]

    def index_prefix = params.bowtie2_index ?: "${params.index_dir}/${genome_key}/${genome_key}"
    if (!file("${index_prefix}.1.bt2").exists() && !file("${index_prefix}.1.bt2l").exists()) {
        error "Bowtie2 index not found at '${index_prefix}'. Build it with: bash scripts/build_index.sh ${genome_key} ${params.index_dir}\n" +
              "or point to an existing index with --bowtie2_index /path/to/prefix"
    }
    def keep_chroms = params.keep_chroms ?: genome.keep_chroms
    def gsize       = params.macs_gsize  ?: genome.macs_gsize

    log.info """
    NEEDseq pipeline
    ================
    genome        : ${genome_key} (${genome.species})
    bowtie2 index : ${index_prefix}
    keep chroms   : ${keep_chroms}
    MACS3 gsize   : ${gsize}
    outdir        : ${params.outdir}
    """.stripIndent()

    // ---- Input reads ----------------------------------------------------------------------
    if (params.input) {
        reads_ch = Channel
            .fromPath(params.input, checkIfExists: true)
            .splitCsv(header: true, strip: true)
            .map { row ->
                if (!row.sample || !row.fastq_1 || !row.fastq_2) {
                    error "Samplesheet rows need 'sample', 'fastq_1' and 'fastq_2' columns: ${row}"
                }
                tuple(row.sample, [file(row.fastq_1, checkIfExists: true), file(row.fastq_2, checkIfExists: true)])
            }
    } else if (params.reads) {
        reads_ch = Channel.fromFilePairs(params.reads, checkIfExists: true)
    } else {
        error "Provide reads with --input samplesheet.csv or --reads 'path/*_{1,2}.fastq.gz' (see --help)"
    }

    index_files = Channel.fromPath("${index_prefix}*.bt2*").collect()

    // ---- Processing -----------------------------------------------------------------------
    TRIM_READS(reads_ch)
    ALIGN_READS(TRIM_READS.out.reads, index_files, file(index_prefix).name)
    REMOVE_DUPLICATES(ALIGN_READS.out.bam)
    FILTER_CHROMOSOMES(REMOVE_DUPLICATES.out.bam, keep_chroms)
    CALL_PEAKS(FILTER_CHROMOSOMES.out.bam, gsize)
    COVERAGE_AND_PLOTS(FILTER_CHROMOSOMES.out.bam.join(CALL_PEAKS.out.peaks))

    if (!params.skip_multiqc) {
        MULTIQC(
            TRIM_READS.out.reports
                .mix(TRIM_READS.out.fastqc, ALIGN_READS.out.log, REMOVE_DUPLICATES.out.metrics,
                     FILTER_CHROMOSOMES.out.flagstat,
                     CALL_PEAKS.out.all.flatten().filter { it.name.endsWith('_peaks.xls') })
                .collect()
        )
    }
}
