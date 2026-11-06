set -e

#########################################################################################
# Miniconda
cd $HOME

# Old version, currently testing now below
wget https://repo.anaconda.com/miniconda/Miniconda3-py37_4.8.3-Linux-x86_64.sh
sudo chmod +x Miniconda3-py37_4.8.3-Linux-x86_64.sh
sudo ./Miniconda3-py37_4.8.3-Linux-x86_64.sh -b -p /opt/conda
# -b flag is for silent batch installation with no direct PATH modification
rm Miniconda3-py37_4.8.3-Linux-x86_64.sh

# New version
#wget https://repo.anaconda.com/miniconda/Miniconda3-py313_25.11.1-1-Linux-x86_64.sh
#sudo chmod +x Miniconda3-py313_25.11.1-1-Linux-x86_64.sh
#sudo ./Miniconda3-py313_25.11.1-1-Linux-x86_64.sh -b -p /opt/conda
# -b flag is for silent batch installation with no direct PATH modification
#rm Miniconda3-py313_25.11.1-1-Linux-x86_64.sh


export PATH=/opt/conda/bin:$PATH
/opt/conda/bin/conda init bash
source ~/.bashrc

# New - Accept channels that would be accepted interactively when installing
#conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
#conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r
#conda config --add channels conda-forge
conda config --add channels bioconda
#conda config --add channels defaults


# conda update -n base -c defaults conda

# Conda environment
# Now this is where things change. I create a specific Conda environment for the pipeline
# Any other projects on the SCE3 machine will thus be unaffected by conda and pip installs within this environment
conda create -n snippy perl-bioperl pandas

conda create -n salmpipe python=3.7 pip=22.3.1
#line below added based on advice here: https://github.com/conda/conda/issues/7980
eval "$(conda shell.bash hook)"

conda activate salmpipe


# Link to path
sudo ln -s /usr/bin/python3 /usr/bin/python

# Matplotlib
pip install matplotlib

