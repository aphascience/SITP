#!/bin/bash
set -e

######################################################################################
# snippy
cd $HOME


wget 'https://github.com/tseemann/snippy/archive/refs/tags/v4.6.0.tar.gz' --no-check-certificate
tar -vxzf v4.6.0.tar.gz
rm v4.6.0.tar.gz
mkdir SalmoType/ver_controlled_tools
mv snippy-4.6.0 SalmoType/ver_controlled_tools/