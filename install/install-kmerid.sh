# KmerID
set -e
cd $HOME

wget --no-check-certificate --content-disposition https://github.com/aphascience/KMERID-PHE/raw/refs/heads/master/pipeline_component_software/KmerID/kmerid.zip
unzip kmerid.zip
sudo cp -r kmerid /opt
sudo make -C /opt/kmerid all # Changed this so no need to change directory
sudo chmod +x /opt/kmerid/setup_refs.py
sudo chmod +x /opt/kmerid/kmerid_python3.py
rm -rf kmerid
rm kmerid.zip

sudo apt-get -y install nodejs
sudo apt-get -y install npm
sudo npm install -g github-files-fetcher