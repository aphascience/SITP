# Introduction

Salmonella in silico typing pipeline (SITP) was developed by APHA and is written in [Nextflow](https://www.nextflow.io/). The pipeline compares outputs from several publicly available serotyping tools to increase performance and includes bespoke differentiation of strains important for veterinary surveillance.

# Dependancies
- Docker ≥ 29.8.2

# Installation
To build the image for the Nextflow salmonella serotyping pipeline:

First clone the rpository into a local directory:

```
$ git clone https://github.com/aphascience/SITP.git

```
And then run the following commands while in the repository:

```
$ cd SITP/

$ sudo docker build ./ -t salmotype

$ mkdir ~/wgs-reads
```

# Running the pipeline

To run the pipeline on a batch of samples, the raw `.fastq.gz` files must be stored in `~/wgs-reads/<runID>`.  Each read-pair sample is represented by a pair of files named `*_R1.fastq.gz` and `*_R2.fastq.gz`. For example, to batch two samples named `salmonella_a` and `salmonella_b`, a `~/wgs-reads/<runID>` directory containing four files is required: `salmonella_a_R1.fastq.gz`, `salmonella_a_R2.fastq.gz`,  `salmonella_b_R1.fastq.gz` and `salmonella_b_R2.fastq.gz`.

The default image name that process_plate.py will try to run with docker is "salmoType". If you change this on '-t' parameter on the build command above, appropriately change the "default_image" in salmo_typeConfig_procesPlate.yaml.

Then, to run the pipeline from the terminal call:
```
$ python ./plate/process_plate.py -r <runID>

```

Pipeline output is stored in  `~/wgs-results/<runID>/` and contains:
- TODO

# Run options

These are the run options for process_plate.py:

- --reads-dir Sets the directory for where the directory containing the reads are stored. Default is: "~/wgs-reads"
- --results-dir Sets the directory for where the directory containing the results are stored. Default is: "~/wgs-results"
- --runID The name of the run which will also be the name of the directory for the results.

# Pipeline Algorithm

The pipelines processes data in three stages, as shown below. During the preprocessing stage; low quality bases and adapter sequences are removed from the fastq sample files and then subsampled to a maximum of 3M reads. Following this, the analysis stage runs multiple serotyping tools in parallel.
This strategy has been demonstrated to provide more accurate serovar detection than any tools running individually.
Bespoke typing of vaccine strains and particular servoars of interest to APHA is included as part of this analysis.
Outputs from each tool are compared in the consensus call step.
The final postprocessing stage assigns an `Outcome` to each sample by analysing data gathered during the analysis stage. The following `Outcome`s are used to signify subsequent lab processing steps:

- **Pass**: The sample contains Salmonella and has a serovar assigned
- **Check Required**: Further scrutiny of the data is required
- **Inconclusive**: The sample contains insufficient data volumes for analysis, is contaminated, or has low assembly quality.

![image](https://user-images.githubusercontent.com/6979169/154251677-43d55d28-24bb-4dc2-9def-61322ba58629.png)

# Validation

This pipeline has been internally validated and approved by the APHA validation team against a large dataset in excess of 3,500 samples as well as non-Salmonella isolates to determine sensitivity and specificity.
