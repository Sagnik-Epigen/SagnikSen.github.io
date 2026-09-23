# Container with all NEEDseq tools. Build with:
#   docker build -t needseq-pipeline:1.0.0 .
FROM mambaorg/micromamba:1.5.10

USER root
# procps provides `ps`, which Nextflow needs for task metrics
RUN apt-get update \
    && apt-get install -y --no-install-recommends procps \
    && rm -rf /var/lib/apt/lists/*
USER $MAMBA_USER

COPY --chown=$MAMBA_USER:$MAMBA_USER environment.yml /tmp/environment.yml
RUN micromamba install -y -n base -f /tmp/environment.yml \
    && micromamba clean --all --yes

ENV PATH=/opt/conda/bin:$PATH
