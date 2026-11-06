#!/usr/bin/env python

## Modules
import pandas as pd
import argparse
import glob
import os

## Arguments
parser = argparse.ArgumentParser(description='Add Diva vaccine outcome to summary LIMS table for run')
parser.add_argument(
	'-d', '--diva_dir',
	dest = 'diva_dir',
	help = 'Input dir with isolate specific *SummaryTable_plusLIMS_t-diva_added/results.csv output',
	required = True
	)
parser.add_argument(
	'-i', '--summary_table',
	dest = 'in_sum',
	help = 'Input *SummaryTable_plusLIMS.csv',
	required = True
	)
parser.add_argument(
	'-pi', '--plate-id',
	dest = 'plate_id',
	help = 'Plate ID for run (placed on output *SummaryTable_plusLIMS_t-diva_results.csv)',
	required = True
	)

args = parser.parse_args()

## Main body of script

# Pool all diva 'added' and 'result' for all isolates
divaOut_dir = args.diva_dir

isolate_dirs = [d for d in glob.glob(os.path.join(divaOut_dir, "*/")) if os.path.isdir(d)]

added_dirs = [glob.glob(d + 'diva_temp/*SummaryTable_plusLIMS_t-diva_added.csv')[0] for d in isolate_dirs]
added_dfs = [pd.read_csv(add_tab) for add_tab in added_dirs]
added_df = pd.concat(added_dfs, ignore_index=True).dropna(subset=['diva_t-primun'])

results_dirs = [glob.glob(d + 'diva_temp/*SummaryTable_plusLIMS_t-diva_results.csv')[0] for d in isolate_dirs]
result_dfs = [pd.read_csv(res_tab) for res_tab in results_dirs]
result_df = pd.concat(result_dfs, ignore_index=True)

# Load lims_summary and diva_summary
lims_df = pd.read_csv(args.in_sum).set_index('Isolate_ID')
diva_df = added_df.set_index('Isolate_ID')

# ID Diva vaccine isolates
diva_isolates = list(diva_df[diva_df['diva_t-primun'] == 't-primun'].index)

# Update LIMs summary LIM_Vaccaine column with Diva designation
for isolate in diva_isolates:
	if lims_df.loc[isolate,'LIMS_Vaccine'] == 'NOT VACCINE STRAIN':
		lims_df.loc[isolate,'LIMS_Vaccine'] = 'Salmonella Typhimurium Primun T Vaccine Strain'
		lims_df.loc[isolate,'vaccine'] = 'Salmonella Typhimurium Primun T Vaccine Strain'
	elif lims_df.loc[isolate,'LIMS_Vaccine'] != 'NOT VACCINE STRAIN':
		lims_df.loc[isolate,'LIMS_Vaccine'] = lims_df.loc[isolate,'LIMS_Vaccine'] + '_' + 'Salmonella Typhimurium Primun T Vaccine Strain'
		lims_df.loc[isolate,'vaccine'] = 'Salmonella Typhimurium Primun T Vaccine Strain'
lims_df.to_csv(args.in_sum)
result_df.to_csv(divaOut_dir + '/' + str(args.plate_id) + '_SummaryTable_plusLIMS_t-diva_results.csv')
