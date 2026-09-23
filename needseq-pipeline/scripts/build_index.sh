#!/usr/bin/env bash
# Download a reference genome and build the Bowtie2 index the pipeline expects.
#
#   bash scripts/build_index.sh <genome> [index_dir] [threads]
#
#   genome    : human|hg38, mouse|mm10, mm39, drosophila|dm6, arabidopsis|tair10
#   index_dir : default ./genomes  (pass the same value to the pipeline with --index_dir)
#   threads   : default 8
#
# Only nuclear chromosomes + chrM (+ chloroplast for Arabidopsis) are indexed, so alt/unplaced
# contigs don't split multi-mapping reads, and organellar reads map to their true origin before
# the pipeline filters them out.
#
# Result: <index_dir>/<build>/<build>.{1..4,rev.1,rev.2}.bt2, <build>.fa, <build>.chrom.sizes
set -euo pipefail

usage() { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
[[ $# -ge 1 ]] || usage

GENOME=$(echo "$1" | tr '[:upper:]' '[:lower:]')
INDEX_DIR=${2:-genomes}
THREADS=${3:-8}
UCSC=https://hgdownload.soe.ucsc.edu/goldenPath
RENAME_TAIR=false

case "$GENOME" in
    human|hs|hg38)
        BUILD=hg38
        URL=$UCSC/hg38/bigZips/analysisSet/hg38.analysisSet.fa.gz
        KEEP="$(printf 'chr%s ' {1..22} X Y M)" ;;
    mouse|mm|mm10)
        BUILD=mm10
        URL=$UCSC/mm10/bigZips/mm10.fa.gz
        KEEP="$(printf 'chr%s ' {1..19} X Y M)" ;;
    mm39)
        BUILD=mm39
        URL=$UCSC/mm39/bigZips/mm39.fa.gz
        KEEP="$(printf 'chr%s ' {1..19} X Y M)" ;;
    drosophila|fly|dm|dm6)
        BUILD=dm6
        URL=$UCSC/dm6/bigZips/dm6.fa.gz
        KEEP="chr2L chr2R chr3L chr3R chr4 chrX chrY chrM" ;;
    arabidopsis|at|ath|tair10)
        BUILD=tair10
        URL=https://ftp.ensemblgenomes.ebi.ac.uk/pub/plants/current/fasta/arabidopsis_thaliana/dna/Arabidopsis_thaliana.TAIR10.dna.toplevel.fa.gz
        KEEP="Chr1 Chr2 Chr3 Chr4 Chr5 ChrM ChrC"
        RENAME_TAIR=true ;;
    *)
        echo "Unknown genome: $1" >&2; usage ;;
esac

for tool in curl samtools bowtie2-build; do
    command -v "$tool" >/dev/null || { echo "Missing '$tool' - activate the needseq conda env first." >&2; exit 1; }
done

OUT="$INDEX_DIR/$BUILD"
mkdir -p "$OUT"
cd "$OUT"

echo ">> Downloading $BUILD from $URL"
curl -fL --retry 3 -C - -o "$BUILD.download.fa.gz" "$URL"

echo ">> Preparing FASTA"
if $RENAME_TAIR; then
    # Ensembl names (1..5, Mt, Pt) -> TAIR names (Chr1..Chr5, ChrM, ChrC)
    gzip -dc "$BUILD.download.fa.gz" \
        | sed -E 's/^>([^ ]+).*/>Chr\1/; s/^>ChrMt$/>ChrM/; s/^>ChrPt$/>ChrC/' > "$BUILD.full.fa"
else
    gzip -dc "$BUILD.download.fa.gz" > "$BUILD.full.fa"
fi
samtools faidx "$BUILD.full.fa"
# shellcheck disable=SC2086
samtools faidx "$BUILD.full.fa" $KEEP > "$BUILD.fa"
samtools faidx "$BUILD.fa"
cut -f1,2 "$BUILD.fa.fai" > "$BUILD.chrom.sizes"
rm -f "$BUILD.full.fa" "$BUILD.full.fa.fai" "$BUILD.download.fa.gz"

echo ">> Building Bowtie2 index with $THREADS threads (hg38/mm10 take ~1-3 h)"
bowtie2-build --threads "$THREADS" "$BUILD.fa" "$BUILD"

echo ">> Done: $(pwd)/$BUILD"
echo "   Run the pipeline with: --genome $BUILD --index_dir $INDEX_DIR"
