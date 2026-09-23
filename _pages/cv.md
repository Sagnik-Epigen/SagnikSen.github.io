---
layout: archive
title: "CV"
permalink: /cv/
author_profile: true
redirect_from:
  - /resume
---

{% include base_path %}

<a href="{{ base_path }}/files/Sagnik-Sen-CV.pdf" class="btn btn--primary">Download full CV (PDF)</a>

Education
======
* **Ph.D. in Engineering**, Jadavpur University, India, 2016–2021
* **M.Tech in Bioinformatics**, SRM University, India, 2015 — 1st class, Hons., 1st rank (Gold Medalist)
* **B.Tech in Computer Science and Engineering**, Haldia Institute of Technology, India, 2013 — 1st class, Hons.

Work experience
======
* **Research Scientist I** (Feb 2024 – present)
  * Molecular Genetics and Genomics Division, New England Biolabs, Ipswich, MA
  * Group of Dr. Sriharsa Pradhan
* **Post-Doctoral Scientist** (Sep 2021 – Feb 2024)
  * Genome Biology Division, New England Biolabs, Ipswich, MA
* **Project-linked person**, SBIR collaborative project with EpiCypher Inc. (2022 – present)
* **Research Fellow**, Jadavpur University, India (from June 2015)
* **Collaborative Researcher**, CSIR–Indian Institute of Chemical Biology, India (from November 2016)
* **Master's thesis joint supervision** — 10 students graduated

Collaborations
======
* Prof. Petra Hajkova, Developmental Epigenetics, Imperial College London (since 2025)
* Dr. Brad Langhorst, Dr. Louise Williams and Dr. Chaithanya Ponnaluri, New England Biolabs (since 2022)
* Prof. Laura Landweber, Center for Computational Biology and Bioinformatics, Columbia University (since 2022)
* Prof. Melanie Ehrlich, Tulane Cancer Center, Tulane University (since 2021)
* Dr. Amit Sharma, University Hospital Bonn, Germany (since 2019)
* Eischen Laboratory, Thomas Jefferson University, Philadelphia (since 2019)
* Prof. Vladimir Uversky, Molecular Medicine, University of South Florida, Tampa (since 2017)

Awards and fellowships
======
* Nominated for the **2026 BBA Rising Stars in Biochemistry** award
* **Emerging Scientist Award**, 11th International Scientist Awards on Engineering, Science and Medicine (VDGOOD Technology)
* **DST-INSPIRE Fellowship**, Department of Science and Technology, India, 2016–2021
* **Gold Medal**, Department of Bioinformatics, M.Tech program, SRM University, 2015

Skills
======
* **Assays:** NEED-seq, FERN-seq, NicE-seq, EM-seq, Western blots
* **Data analysis pipelines:** NEED-seq, ChIP-seq, NicE-seq, NicE-view-seq (image segmentation), ATAC-seq, EM-seq, WGBS, Hi-C, RNA-seq, scRNA-seq, histopathology image analysis
* **Methods:** graph-theoretical and mathematical modelling, machine learning, deep learning (CNNs, GNNs, transformers), statistical analysis
* **Languages & workflow tools:** Python, R, Bash, Nextflow, Snakemake
* **Environments:** Anaconda, VS Code, HPC, Unix/Linux, macOS, Windows

Pipeline highlights
======
* Automated end-to-end pipeline for NEED-seq upstream analysis
* Downstream pipeline for epigenetic marks, transcription factors and DNA methylation from high-throughput sequencing (NEED-seq, ChIP-seq, NicE-seq)
* Automated fluorescence-image pipeline to study the open-chromatin landscape from NicE-view-seq microscopy
* Graph-theoretical pipeline for the impact of transcription factors on oncogenesis and tumour suppression in multi-omics settings
* Graph-theoretical and numerical-modelling pipeline for the mechanism of therapeutic agents (e.g. CX-5461) across epigenomics and chromosome architecture
* Hi-C analysis pipeline
* Comparative DNA methylation / transcription-factor analysis (ChIP-BS-seq, TEM-seq)
* Network, unsupervised-learning and mathematical-modelling pipelines for structural aberrations of intrinsically disordered proteins
* CNN-based histopathology model for predicting breast-tumour sub-classes

Publications
======
459 citations, h-index 11, i10-index 15 ([Google Scholar]({{ site.author.googlescholar }})). <b>S. Sen</b>* = first/joint-first author; <sup>+</sup> = corresponding author.

{% for category in site.publication_category %}
  {% assign items = site.publications | where: "category", category[0] | reverse %}
  {% if items.size > 0 %}
### {{ category[1].title }}
  <ul>{% for post in items %}
    {% include archive-single-cv.html %}
  {% endfor %}</ul>
  {% endif %}
{% endfor %}

Talks and panels
======
  <ul>{% for post in site.talks reversed %}
    {% include archive-single-talk-cv.html  %}
  {% endfor %}</ul>

Academic service
======
* Topic Editor, *Frontiers in Bioinformatics*
* Review Editor, Computational Genomics, *Frontiers in Genetics*
* PC member, Function COSI: Protein Function Annotation, ISMB/ECCB 2019
* Reviewer for *Current Opinion in Structural Biology*, *NAR Genomics and Bioinformatics*, *Briefings in Bioinformatics*, *Communications Biology*, *IEEE/ACM TCBB*, *Sādhanā*, *Life* (MDPI), *Cancers* (MDPI), *Ecotoxicology and Environmental Safety*
