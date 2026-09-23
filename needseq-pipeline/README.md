# NEEDseq pipeline

A [Nextflow](https://www.nextflow.io/) pipeline for paired-end **NEEDseq** data from
**human**, **mouse**, **Drosophila** and **Arabidopsis**.

```
FASTQ pairs
  └─ Trim Galore      hard-clip 4 bp from both ends of R1/R2, adapter trim, FastQC
      └─ Bowtie2      --very-sensitive --dovetail, concordant pairs only, fragments ≤ 1 kb
          └─ samtools sort + index
              └─ Picard MarkDuplicates   remove PCR duplicates
                  └─ samtools view       keep nuclear chromosomes only (drop chrM / chloroplast / contigs)
                      ├─ MACS3 callpeak  narrow (_N) and broad (_B) peaks, BAMPE, SPMR bedGraphs
                      └─ deepTools       RPKM bigWig + plotEnrichment for narrow and broad peaks
                                           └─ MultiQC summary report
```

## Supported genomes

| `--genome` (any of)                 | Build  | Chromosomes kept for peak calling | MACS3 `-g` |
|-------------------------------------|--------|-----------------------------------|------------|
| `human`, `hs`, `hg38`               | hg38   | chr1–22, chrX, chrY               | `hs`       |
| `mouse`, `mm`, `mm10`               | mm10   | chr1–19, chrX, chrY               | `mm`       |
| `mm39`                              | mm39   | chr1–19, chrX, chrY               | `mm`       |
| `drosophila`, `fly`, `dm`, `dm6`    | dm6    | chr2L, chr2R, chr3L, chr3R, chr4, chrX, chrY | `dm` |
| `arabidopsis`, `at`, `ath`, `tair10`| TAIR10 | Chr1–Chr5                         | `1.19e8`   |

Genome settings live in [`conf/genomes.config`](conf/genomes.config); override per run with
`--keep_chroms "..."` and `--macs_gsize ...`.

## Requirements

| Tool         | Version    |
|--------------|------------|
| Nextflow     | ≥ 24.04 (needs Java 17+) |
| Trim Galore  | ≥ 0.6.10 (with Cutadapt ≥ 4.4) |
| FastQC       | ≥ 0.12     |
| Bowtie2      | ≥ 2.5      |
| samtools     | ≥ 1.17     |
| Picard       | ≥ 3.0      |
| MACS3        | ≥ 3.0      |
| deepTools    | ≥ 3.5.4    |
| MultiQC      | ≥ 1.21     |

Hardware: building the human/mouse index needs ~16 GB RAM and ~40 GB disk. Alignment runs with up
to 16 CPUs / 32 GB RAM by default (see [Resources](#resources)).

## Installation

```bash
git clone https://github.com/Sagnik-Epigen/NEEDseq_Pipeline.git
cd NEEDseq_Pipeline
```

Pick **one** of the following.

### Option A – Conda / Mamba (recommended)

```bash
# Install Miniforge first if you have no conda: https://github.com/conda-forge/miniforge
mamba env create -f environment.yml      # or: conda env create -f environment.yml
conda activate needseq
```

All tools, including Nextflow, are now on your `PATH`, so you can run without a profile.

### Option B – Docker / Singularity

```bash
docker build -t needseq-pipeline:1.0.0 .
# Singularity/Apptainer users can convert it:
singularity build needseq-pipeline.sif docker-daemon://needseq-pipeline:1.0.0
```

Install Nextflow separately (`curl -s https://get.nextflow.io | bash`) and run with
`-profile docker`, or `-profile singularity --container needseq-pipeline.sif`.

### Option C – pip + system tools

`requirements.txt` covers the Python tools only (Cutadapt, MACS3, deepTools, MultiQC):

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
```

Nextflow, Trim Galore, FastQC, Bowtie2, samtools and Picard must then be installed another way
(e.g. your package manager or HPC modules) and be on your `PATH`.

## 1. Build the reference index (once per genome)

```bash
bash scripts/build_index.sh human        genomes 16
bash scripts/build_index.sh mouse        genomes 16   # mm10; use "mm39" for GRCm39
bash scripts/build_index.sh drosophila   genomes 8
bash scripts/build_index.sh arabidopsis  genomes 8
```

The script downloads the FASTA (UCSC for hg38 analysis set / mm10 / mm39 / dm6; Ensembl Plants for
TAIR10, renamed to `Chr1..Chr5`, `ChrM`, `ChrC`), keeps the nuclear chromosomes plus organelles,
and builds a Bowtie2 index at `genomes/<build>/<build>`.

Already have an index? Skip this and pass `--bowtie2_index /path/to/index/prefix` — just make sure
its chromosome names match `keep_chroms` (or set `--keep_chroms`).

## 2. Describe your samples

Create a CSV like [`assets/samplesheet.csv`](assets/samplesheet.csv):

```csv
sample,fastq_1,fastq_2
sample1,/data/run1/sample1.1.fastq.gz,/data/run1/sample1.2.fastq.gz
sample2,/data/run1/sample2.1.fastq.gz,/data/run1/sample2.2.fastq.gz
```

Or skip the CSV and give a glob: `--reads '/data/run1/*.{1,2}.fastq.gz'` (sample name = the part
matched by `*`).

## 3. Run

```bash
# Human
nextflow run main.nf --input samplesheet.csv --genome human       --outdir results_hs
# Mouse
nextflow run main.nf --input samplesheet.csv --genome mouse       --outdir results_mm
# Drosophila
nextflow run main.nf --input samplesheet.csv --genome drosophila  --outdir results_dm
# Arabidopsis
nextflow run main.nf --input samplesheet.csv --genome arabidopsis --outdir results_at
```

Add `-profile conda`, `-profile docker`, `-profile singularity` and/or `-profile slurm`
(comma-separated, e.g. `-profile singularity,slurm`) as needed. Resume an interrupted run with
`-resume`. See all options with `nextflow run main.nf --help`.

### Options

| Parameter | Default | Description |
|---|---|---|
| `--input` | – | Samplesheet CSV (`sample,fastq_1,fastq_2`) |
| `--reads` | – | Glob of FASTQ pairs (alternative to `--input`) |
| `--genome` | `human` | See [Supported genomes](#supported-genomes) |
| `--index_dir` | `<pipeline>/genomes` | Where `build_index.sh` wrote the indices |
| `--bowtie2_index` | – | Explicit Bowtie2 index prefix |
| `--keep_chroms` | per genome | Chromosomes kept after duplicate removal |
| `--macs_gsize` | per genome | MACS3 effective genome size |
| `--clip_r1`, `--clip_r2` | `4` | 5′ bases clipped by Trim Galore |
| `--three_prime_clip_r1`, `--three_prime_clip_r2` | `4` | 3′ bases clipped |
| `--max_fragment` | `1000` | Bowtie2 `-X` |
| `--min_mapq` | `0` (off) | MAPQ filter applied with the chromosome filter (e.g. `30`) |
| `--bin_size` | `10` | bamCoverage bin size |
| `--outdir` | `results` | Output directory |
| `--skip_multiqc` | `false` | Skip MultiQC |

### Resources

Default per-task requests are set in [`nextflow.config`](nextflow.config) (labels
`process_low/medium/high`) and capped by `process.resourceLimits` (16 CPUs, 64 GB, 48 h). On a
smaller machine, create `local.config`:

```groovy
process.resourceLimits = [cpus: 4, memory: 16.GB, time: 24.h]
```

and add `-c local.config` to the command.

## Output

```
results/
├── <sample>/
│   ├── trimmed/     *_val_{1,2}.fq.gz, trimming reports, FastQC
│   ├── alignment/   .sorted.bam  → .dedup.bam (PCR duplicates removed)
│   │                → .filtered.bam (nuclear chromosomes; used downstream)
│   │                bowtie2 log, duplicate metrics, flagstat
│   ├── macs3/       <sample>_N_peaks.narrowPeak, <sample>_B_peaks.broadPeak, summits,
│   │                .xls, SPMR bedGraphs
│   └── coverage/    <sample>.bw (RPKM), <sample>_{N,B}.png enrichment plots + raw counts
├── multiqc/multiqc_report.html
└── pipeline_info/   Nextflow timeline, report, trace
```

## Changes from the original single-sample script

- Mouse reads were aligned to the **hg38** index; each species now uses its own genome.
- Added Drosophila (dm6) and Arabidopsis (TAIR10) support.
- Many samples per run via a samplesheet; no hard-coded paths or copy-back to a working directory
  (results are published to `--outdir`).
- Bowtie2 output is piped straight into `samtools sort` (no intermediate SAM).
- Unknown species now stop the run with an error instead of silently producing empty files.

## License

Released under the [MIT License](LICENSE). © 2026 Sagnik Sen
