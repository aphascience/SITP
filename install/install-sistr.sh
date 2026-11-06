#!/bin/bash
set -e

pip install numpy==1.21.6

conda install bioconda::blast
conda install bioconda::mafft=7.525
conda install bioconda::mash=1.1

python -m pip install --upgrade pip

pip install sistr_cmd==1.1.2

# conda config --add channels conda-forge

# #this one is new
# conda config --add channels defaults

# conda config --add channels r
# conda config --add channels bioconda
# # conda install sistr_cmd==1.1.1
# conda install sistr_cmd

pip install pandas==1.0.5
