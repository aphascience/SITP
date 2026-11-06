import pandas as pd
import re


def update_summary(master_sum,new_sum):
	master_df=pd.read_csv(master_sum)
	new_df=pd.read_csv(new_sum)
	print(new_sum)
	sum_info = new_sum.split('/')[-2].split('_')
	date = sum_info[0]
	plate_id = str(sum_info[2]) + '_' + str(sum_info[3])

	day=date[0:2]
	month=date[2:4]
	year=date[4:6]
	year = "20" + year
	date=day+"/"+month+"/"+year

	new_df.loc[0:,'Date']=date
	new_df.loc[0:,'Plate_ID']=plate_id

	master_df=pd.concat([master_df,new_df])
	master_df.to_csv(master_sum,index=False)