set -e
export PIP_CERT=/etc/ssl/certs/ca-certificates.crt 
# Apt Packages
apt-get -y update
DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
    sudo \
    apt-utils \
    make \
    gcc \
    bc \
    git \
    wget \
    curl \
    libz-dev \
    libbz2-dev \
    libncurses5-dev \
    libncursesw5-dev \
    libghc-bzlib-prof \
    zlib1g-dev \
    libcurl4-openssl-dev \
    libfile-copy-recursive-perl \
    libio-socket-ssl-perl \
    libio-tee-perl \
    libunicode-string-perl \
    nano \
    gzip \
    python3

# sudo apt install python3-venv -y
# python3 -m ensurepip --upgrade
sudo apt install python3-pip -y

# Bioinformatics Tools
echo "install conda.sh"
bash install/install-conda.sh
echo "install snippy.sh"
bash install/install-snippy.sh
echo "install fastp.sh"
bash install/install-fastp.sh
echo "install fastq.sh"
bash install/install-fastqc.sh
echo "install seqtk.sh"
bash install/install-seqtk.sh
echo "install shovill.sh"
bash install/install-shovill.sh
echo "install quast.sh"
bash install/install-quast.sh
echo "install most.sh"
bash install/install-most.sh
echo "install kmerid.sh"
bash install/install-kmerid.sh
echo "install seqsero2.sh"
bash install/install-seqsero2.sh
echo "install sistr.sh"
bash install/install-sistr.sh
echo "install srst2.sh"
bash install/install-srst2.sh
echo "install nextflow.sh"
bash install/install-nextflow.sh
echo "install sra-toolkit.sh"
bash install/install-sra-toolkit.sh
echo "install setup-environment.sh"
bash install/setup-environment.sh
pip install boto3
pip install PyYAML

# Output folder for running jobs
mkdir $HOME/wgs-reads/TestIsolates/ $HOME/wgs-results/TestIsolates/ 
