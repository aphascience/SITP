import subprocess
import os
import glob
import argparse
#import boto3
import update_master_sum
import yaml

with open("/home/jahcubtrew/test_branches/SalmoType/salmo_typeConfig_procesPlate.yaml", "r") as f:
    in_config = yaml.safe_load(f)

# TODO: Rename directories to BGE defaults
DEFAULT_READS_DIRECTORY = os.path.expanduser('~/wgs-reads/')
DEFAULT_RESULTS_DIRECTORY = os.path.expanduser('~/wgs-results/')
DEFAULT_IMAGE = in_config['default_image']

def run(cmd):
    """ Run a command and assert that the process exits with a non-zero exit code.

        Parameters:
            cmd (list): List of strings defining the command, see (subprocess.run in python docs)
    """
    # TODO: store stdout to a file
    returncode = subprocess.run(cmd).returncode

    if returncode:
        raise Exception("""*****
            %s
            cmd failed with exit code %i
        *****""" % (cmd, returncode))

def run_pipeline(reads, results, plate_name, assemblies_dir, image=DEFAULT_IMAGE):
    """ Run the Salmonella pipeline using docker """
    if not os.path.isdir("/opt/kmerid/"):
        print('###Downloading kmerID reference for the first time, this should take ~10 mins###')
        run(['wget', '-O', 'kmerid.zip', 'https://zenodo.org/records/23765058/files/kmerid.zip?download=1'])
        print('###Unzipping kmerID reference###')
        run(['unzip', 'kmerid.zip'])
        run(['rm', 'kmerid.zip'])
        run(['tar', '-vxf', 'kmerid.tar'])
        run(['rm', 'kmerid.tar'])
        run(['sudo', 'mv', 'kmerid', '/opt/'])
    run([
        "sudo", "docker", "run", "--rm", "-it",
        "-v", f"{reads}:/root/wgs-reads/{plate_name}/",
        "-v", f"{results}:/root/wgs-results/{plate_name}/",
        "-v", f"{assemblies_dir}:/root/wgs-results/{plate_name}/assemblies/",
        "-v", f"/opt/kmerid/ref:/opt/kmerid/ref",
        "-v", f"/opt/kmerid/config:/opt/kmerid/config",
        image,
        "/root/nextflow/nextflow", "SCE3_pipeline_update.nf",
        "--runID", plate_name, "--plateRun", "False", "-c", "salmoType.config"
    ])

def rename_fastq_file(filepath):
    """ Rename a fastq file from CSU's convention to BGE """

    # Parse
    directory = os.path.dirname(filepath)
    filename = os.path.basename(filepath) + '/'
    sample_name = filename.split("_")[0]

    # Determine Read Number
    if "_R1" in filename:
        read_number = 1

    elif "_R2" in filename:
        read_number = 2

    else:
        raise Exception("Unable to determine read pair number: ", filename)

    # Rename
    renamed = f"{directory}/{sample_name}_R{read_number}.fastq.gz"
    os.rename(filepath, renamed)

def run_plate(reads_dir, results_dir, image, runID, updateSum):

    """ Download, process and store a plate of raw Salmonella data """

    # Add trailing slash to directory names
    reads_dir = os.path.join(reads_dir, '')
    results_dir = os.path.join(results_dir, '')
    
    plate_reads_dir = ''
    plate_results_dir = ''
    plate_name = ''

    if runID:

        plate_name = runID
        plate_reads_dir = reads_dir + runID + '/'
        plate_results_dir = results_dir + runID +'/'

        for filepath in glob.glob(plate_reads_dir + '/*.fastq.gz'):
            rename_fastq_file(filepath)

    assemblies_dir = str(plate_results_dir) + "assemblies/"
    run_pipeline(plate_reads_dir, plate_results_dir, plate_name, assemblies_dir, image=args.image)
    TableFile = plate_name + "_SummaryTable_plusLIMS.csv"
    summaryTable_path = os.path.join("~/wgs-results/",plate_name,TableFile)
    summaryTable_path = os.path.expanduser(summaryTable_path)

    if updateSum:
        try:
            update_master_sum.update_summary(updateSum, summaryTable_path)
            print("Master summary table updated")
        except:
            print("Unable to update master summary table")
        


if __name__ == '__main__':
    # Parse
    parser = argparse.ArgumentParser(description="run pipeline on a routine Salmonella Plate")
    parser.add_argument("--reads-dir", default=DEFAULT_READS_DIRECTORY,  help="base directory that s3 objects are stored to")
    parser.add_argument("--results-dir", default=DEFAULT_RESULTS_DIRECTORY,  help="base directory where pipeline results are stored")
    parser.add_argument("--image", default=DEFAULT_IMAGE, help="docker image to use")
    parser.add_argument("-r","--runID", default=False, help="The name of the run which should be the name of the folder with your reads", required=True)
    parser.add_argument("-u", "--updateSum", default=False, help="Set to path of master summary table if you want to update the master the summary table with the results from this run")

    args = parser.parse_args()
    
    # Run
    run_plate(args.reads_dir, args.results_dir, args.image, args.runID, args.updateSum)