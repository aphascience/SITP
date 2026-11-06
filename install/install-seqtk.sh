#!/bin/bash
set -e

######################################################################################
# seqtk
cd $HOME
conda config --set ssl_verify /etc/ssl/certs/ca-certificates.crt
conda install -c bioconda seqtk=1.3
