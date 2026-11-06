#!/usr/bin/env python

## Modules
import pandas as pd
import argparse
import glob
import os
import shutil

## Arguments
parser = argparse.ArgumentParser(description='Identify Typhimurium isolates on input summary table and copy to separate dir for analysis')
parser.add_argument(
	'-i', '--summary_table',
	dest='in_sum',
	help='Input *SummaryTable_plusLIMS.csv'
	)
parser.add_argument(
	'-rd', '--reads_dir',
	dest='read_dir',
	help='Dir with all trimmed reads. Full path. New dir is made here (tyhimurium_isolates) for Identify Typhimurium'
	)

args = parser.parse_args()

## Main body of script

# Load lims_summary, identify 3-Typhimurium isolates that have passed
sum_df = pd.read_csv(args.in_sum).set_index('Isolate_ID')
typhi_df1 = sum_df[sum_df['LIMS_SerotypeID'].str.lower() == 'typhimurium']

# Get isolate IDs and mv files to new dir
typhi_isolates = list(typhi_df1.index)

#os.mkdir(args.read_dir + '/' + 'typhimurium_isolates')
origin = args.read_dir + '/'
destination = args.read_dir + '/typhimurium_isolates/'

if typhi_isolates:
	open("typhim_here","w").close() # Create file to show Typhimurium isolates were present, to allow required subsequent processes to run
	for isolate in typhi_isolates:
		r1_isolate = isolate + '_R1.fastq.gz'
		r2_isolate = isolate + '_R2.fastq.gz'
		shutil.copy(origin + r1_isolate, destination + r1_isolate)
		shutil.copy(origin + r2_isolate, destination + r2_isolate)
else:
	pass