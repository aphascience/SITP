FROM ubuntu:20.04

################## METADATA ###########################

LABEL base.image=ubuntu:20.04
LABEL software="Salmonella Serotyping Pipeline Image"
LABEL about.summary="Salmonella Serotyping Pipeline"
LABEL about.documentation="https://github.com/aphascience/SalmoType"
LABEL about.tags="Genomics, WGS"


################## ARGS #############################

ARG SALMO_PATH="/root/SalmoType/"


################## DEPENDENCIES ######################
RUN apt-get -y update; apt-get -y install curl
RUN apt-get -y update; apt-get -y install unzip
RUN mkdir awscli \
&& cd awscli \
&& curl -k https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip \
&& unzip awscliv2.zip \
&& ./aws/install

# Copy repository
WORKDIR $SALMO_PATH
COPY ./ ./

# Set conda paths. The ENV declaration is required for the $PATH var to remain updated after build
ENV PATH=/opt/conda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Install dependencies
RUN bash install/install.bash

#Stop issues where /bin/bash is not found
CMD ["/bin/bash"]
