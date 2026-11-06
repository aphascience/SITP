#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Sep  8 09:41:16 2025

@author: javiernunezgarcia
refactoring: jahcubtrew
An example to call the script is:
	python diva_test_s3_251204.py arguments_file_251204.txt /home/jahcubtrew/test_dir/010126_APHA_NB552234_0535_SummaryTable_plusLIMS_fin.csv /home/jahcubtrew/test_dir/ isolate_R1.fastq.gz isolate_R2.fastq.gz
"""

import os,os.path,sys
import csv
from collections import Counter
from pathlib import Path
import glob

####### functions definitions
def read_csv(fname,ch=','):
	infile=open(fname,"r")
	data = csv.reader(infile, delimiter=ch)
	dataOut = [row for row in data]
	infile.close()
	return(dataOut)

def write_csv(fname,matrix):
	with open(fname, "w") as fileOut:
		writer = csv.writer(fileOut)
		writer.writerows(matrix)
		print("file "+fname+" saved.")

def run_cmd(lis):
	print(" ".join(lis))
	os.system(" ".join(lis))

def read_contigs(fname):
	fileIn = open(fname, 'r')
	lines= fileIn.readlines()
	lines=[x.strip() for x in lines]
	ids=[]
	seqs=[]
	seq=""
	for line in lines:
		if line[0]==">":
			if len(ids)>0:
				seqs.append(seq)
				seq=""
			ids.append(line[1:])
		else:
			seq=seq+line
	seqs.append(seq)
	contigs=dict()
	for i in range(len(ids)):
		contigs[ids[i].split(" ")[0]]=seqs[i]
	return(contigs)

def test_insertions_on_ref(snippy_aligned):
	isolate_chr=read_contigs(snippy_aligned)['ST_2_1_1reordered_chromosome']
	row=[]
	for key in del_dict:
		low=int(key.split("_")[2].split('..')[0])
		up=int(key.split("_")[2].split('..')[1])
		seq=isolate_chr[low:up+1]
		dict_seq=Counter(seq)
		present=dict_seq['A']+dict_seq['C']+dict_seq['G']+dict_seq['T']
		per_present=str(round(100*(present)/float(len(seq)),2))
		row.append(per_present+'__'+str(present)+'__'+str(dict_seq['-'])+'__'+str(dict_seq['N']+dict_seq['n']))
	return(row)

def test_snps_on_ref(snippy_aligned):
	isolate_snippy=read_contigs(snippy_aligned)['ST_2_1_1reordered_chromosome']
	match=0
	available=0
	for line in snps[1:]:
		pos=int(line[0])
		if isolate_snippy[pos-1].upper() in ['A','C','G','T']:
			available=available+1
		if line[2]==isolate_snippy[pos-1]:
			match=match+1
	perc_present=round(100*match/float(available),2)
	return([str(perc_present)+'__'+str(match)+'__'+str(available)])


def do_one_sample(isolate_line,fw,rv):
	print(f'Func-isolate_line: {isolate_line}') # Troubleshooting
	sample_id=isolate_line[Isolate_ID_ps]
	print(f'Func-sample_id: {sample_id}') # Troubleshooting
	#R1=[x for x in R1s if sample_id in x][0]
	#print(f'Func-R1: {R1}') # Troubleshooting
	sample_tmp_folder=os.path.join(temp_path,seq_run_id+"_"+sample_id)
	print(f'Func-sample_tmp_folder: {sample_tmp_folder}') # Troubleshooting
	run_cmd(['mkdir',sample_tmp_folder])

	#R1_origin_fil = R1
	#R1_destiny_fil=os.path.join(sample_tmp_folder,R1.split("/")[-1])
	#run_cmd([' cp',R1_origin_fil,R1_destiny_fil])
	#R2=R1.replace('_R1','_R2')
	#R2_origin_fil = R2
	#R2_destiny_fil=os.path.join(sample_tmp_folder,R2.split("/")[-1])
	#run_cmd(['cp',R2_origin_fil,R2_destiny_fil])

	sample_snippy_folder_output=os.path.join(sample_tmp_folder,'snippy')
	run_cmd(['$HOME/SalmoType/ver_controlled_tools/snippy-4.6.0/bin/snippy --force --cpus', '6','--outdir',sample_snippy_folder_output,'--ref',calier_ref,'--R1',fw,'--R2',rv])

	isolate_snippy_file=os.path.join(sample_snippy_folder_output,'snps.aligned.fa')
	if os.path.isfile(isolate_snippy_file):
		snps_res=test_snps_on_ref(isolate_snippy_file)
		ins_res=test_insertions_on_ref(isolate_snippy_file)
		if float(snps_res[0].split('__')[0])>=snps_th and all([float(x.split('__')[0])>=insertions_th for x in ins_res]):
			tprimun='t-primun'
			if int(snps_res[0].split('__')[-1])<snps_availability_th:
				tprimun=tprimun+'_check'
		else:
			tprimun='non_t-primun'
			if int(snps_res[0].split('__')[-1])<snps_availability_th or float(snps_res[0].split('__')[0])>=snps_check_th or any([float(x.split('__')[0])>=insertions_check_th for x in ins_res]):
				tprimun=tprimun+'_check'
		line=isolate_line+[tprimun]+snps_res+ins_res
	else:
		line=isolate_line+['not_aligned']+['not_aligned']+['not_aligned']*len(deletions)

	run_cmd(['rm -r',sample_tmp_folder]) #Troubleshooting
	print(f'Func-line: {line}')
	return(line)

############################ reading arguments

args=sys.argv
if len(args)>1:
	arguments_file=args[1]
	pipeline_line_file=args[2]
	out_dir = args[3]
	forward = args[4]
	reverse = args[5]
else:
	print("five arguments needed; an arguments file, output table from the typing pipeline, out dir (for diva foulder)  and forward and reverse reads")

print(f'script-pipeline_line_file: {pipeline_line_file}') # Troubleshotting
print(f'script-forward: {forward}') # Troubleshotting
print(f'script-reverse: {reverse}') # Troubleshooting
######################## reading arguments file
print('Reading arguments from file: '+arguments_file)
with open(arguments_file,'r') as f:
	for line in f:
		if line[0] not in ['\n',' ','#']:
			print('Loading argument: '+ line.strip())
			exec(line.strip())


################################ some general variables and directories
home = out_dir


###################### creating temp path and output file names
temp_path=os.path.join(home,'diva_temp')
run_cmd(['mkdir',temp_path])

temp_pipeline_line_file=os.path.join(temp_path,pipeline_line_file.split(os.sep)[-1])
print(f'script-temp_pipeline_line_file: {temp_pipeline_line_file}')
run_cmd(['cp',pipeline_line_file,temp_pipeline_line_file])

tem_details_file=os.path.join(temp_path,pipeline_line_file.split(os.sep)[-1].replace('.csv','_t-diva_results.csv'))
print(f'script-tem_details_file: {tem_details_file}')
temp_out_file=os.path.join(temp_path,pipeline_line_file.split(os.sep)[-1].replace('.csv','_t-diva_added.csv'))
print(f'script-temp_out_file: {temp_out_file}')

############################### loading the pipeline output table

pipeline_line_tab=read_csv(temp_pipeline_line_file)
print(f'script-pipeline_line_tab: {pipeline_line_tab}')
Isolate_ID_ps=pipeline_line_tab[0].index('Isolate_ID')
LIMS_SerotypeID_ps=pipeline_line_tab[0].index('LIMS_SerotypeID')
seq_run_id="_".join(pipeline_line_file.split(os.sep)[-1].split('_')[2:4])

########################## isolates to run the DIVA test on

isolates_to_do=[[x[Isolate_ID_ps],seq_run_id,x[LIMS_SerotypeID_ps]] for x in pipeline_line_tab if 'typhimurium' in x[LIMS_SerotypeID_ps].lower()]
isolate_id = forward.split('_')[0]
isolate_to_do = [isolate for isolate in isolates_to_do if isolate_id in isolate][0]
print(f'script-isolates_to_do: {isolates_to_do}') # Troubleshooting

###### loading snps and deletions files
snps=read_csv(snps_file)
del_dict=read_contigs(deletion_fasta_file)
deletions=list(del_dict.keys())

####################### Searching for the R1 fastq files of the isolates in the s3-csu-001 bucket
#R1s=[]

#for fastq in list(glob.glob(out_dir + '*_R1*')):
#	R1s.append(fastq)
#print(f'Script-R1s: {R1s}') # Troubleshooting
########### Running the test singularly
results_tab=[['Isolate_ID','Seq_Run_ID','LIMS_SerotypeID','diva_t-primun','56_calier_snps_[perc__#snps__#available]']+[ins+'_[perc__#bp_present__#bp_absent__#low-quality]' for ins in deletions]]

results = [do_one_sample(isolate_to_do, forward, reverse)]
print(f'Script-results: {results}')
results_tab=results_tab+results

##################### Saving the t-diva results and the log file

write_csv(tem_details_file,results_tab)
run_cmd(['cp',tem_details_file,pipeline_line_file.replace('.csv','_t-diva_results.csv')])

#####################  adding a column in the original input file with the t-diva results

added_tab=[pipeline_line_tab[0]+['diva_t-primun']]
for line in pipeline_line_tab[1:]:
	result=[x[3] for x in results if x[0]==line[Isolate_ID_ps]]
	if len(result)==1:
		added_tab.append(line+result)
	else:
		added_tab.append(line+["NA"])
write_csv(temp_out_file,added_tab)

run_cmd(['cp',temp_out_file,pipeline_line_file.replace('.csv','_t-diva_added.csv')])
