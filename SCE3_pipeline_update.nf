#!/usr/bin/env nextflow

/*
 * PRE-STEP i - define the input path to the sequences that will be analysed
*/

subsamp = params.subsampThreshold - 500000
println subsamp
println params.minReads
println params.runID

println params.batchRun


readPath = "$HOME/wgs-reads/${params.runID}/*_{R1,R2}.fastq.gz"
publishDirectory = "$HOME/wgs-results/${params.runID}/"
assemblyDirectory = "$HOME/wgs-results/${params.runID}/assemblies/"

println readPath


/*
 * PRE-STEP ii - Initial pre-processing run at the start of the nextflow run
*/

process git_sha {
    """
    # Save the git-sha into the results folder
    mkdir -p $publishDirectory
    mkdir -p $assemblyDirectory
    git rev-parse HEAD > $publishDirectory/sha
    """
}

process email_file {
    shell:
    if (params.batchRun != "False")
    '''
    [ -d "$HOME/wgs-results/" ] || mkdir -p "$HOME/wgs-results/"
    [ -d "$HOME/wgs-results/!{params.runID}" ] || mkdir -p "$HOME/wgs-results/!{params.runID}"
    touch $HOME/wgs-results/!{params.runID}/!{params.runID}_low_readcounts.scemail
    echo "Writing out plate status file to: $HOME/wgs-results/!{params.runID}/!{params.runID}_low_readcounts.scemail"
    echo "The following plate has started running:" | tee -a $HOME/wgs-results/!{params.runID}/!{params.runID}_low_readcounts.scemail
    echo !{params.runID} | tee -a $HOME/wgs-results/!{params.runID}/!{params.runID}_low_readcounts.scemail
    echo "\nIsolates that failed to process due to low readcount and need to be resequenced:" | tee -a $HOME/wgs-results/!{params.runID}/!{params.runID}_low_readcounts.scemail

    '''
    else
    '''
    echo "not a batch run"
    '''
    
}


/*
 * PRE-STEP iii - count reads
*/

reads = Channel.fromFilePairs(readPath)

process count_reads {
    publishDir "$HOME/wgs-results/${params.runID}/${sample_id}/readcount", mode: 'move'

    input:
    tuple sample_id, readPair from reads

    output:
    env(READCOUNT) into countStr1, countStr2
    val sample_id into names1, names2
    val readPair into files1, files2
    val true
    file("*_readcount.txt") into out_iii

    shell:
    '''
    READFILE1=$(echo !{readPair[0]})
    READCOUNT=$(zcat $READFILE1|echo $(wc -l)/4|bc)
    echo $READCOUNT > !{sample_id}_readcount.txt

    
    
    
    if [ "$READCOUNT" -lt "500000" ] && [ !{params.batchRun} != "False" ]; 
    then
        echo !{sample_id} | tee -a $HOME/wgs-results/!{params.runID}/!{params.runID}_low_readcounts.scemail
    fi



    '''
    
}

/*
 * PRE-STEP iv make fasta dir
*/
// process make_dir{
//     input:
//     val ready
    
//     errorStrategy 'ignore'
//     script:
//     """
//     mkdir $HOME/wgs-results/${params.runID}/assemblies
//     """
// }

countInt1 = countStr1.toInteger()
countInt2 = countStr2.toInteger()

names1
    .merge(countInt1)
    .merge(files1)
    .filter {it[1] >= params.minReads}
    .into{runCh; countCh}

names2
    .merge(countInt2)
    .merge(files2)
    .filter {it[1] < params.minReads}
    .set{skipCh}


/*
 * PRE-STEP v - instantiate summary table
*/

samplecount_ch = Channel.fromFilePairs(readPath)

process instantiate_summary_table {
    input:
    val sample_count from samplecount_ch.count()
    val counted_samples from out_iii.count()

    output:
    file("safe_to_delete.txt") into checkCh

    when:
    counted_samples == sample_count

    shell:
    """
    python $HOME/SalmoType/summaryTable_reworked.py ${params.runID} --instantiate
    touch safe_to_delete.txt

    if [ !{params.batchRun} != "False" ];
    then
        aws s3 cp $HOME/wgs-results/!{params.runID}/!{params.runID}_low_readcounts.scemail !{params.s3_email_out} --acl bucket-owner-full-control
    fi

    
    """

}


process check_data {
    input:
    val check from checkCh
    val runCount from countCh.count()

    output:
    val go into goCh1, goCh2

    exec:
    if (runCount > 0) {
        go = 1
    }
    else {
        error "ERROR: No input .fastq.gz files found or all input .fastq.gz files < 500K reads"
        shell:
        """
        echo "Writing out plate status file to: $HOME/wgs-results/!{params.runID}/!{params.runID}_failed.scemail"
        echo "The following plate has failed:" | tee -a $HOME/wgs-results/!{params.runID}_failed.scemail
        echo !{params.runID} | tee -a $HOME/wgs-results/!{params.runID}/!{params.runID}_failed.scemail
        if [ !{params.batchRun} != "False" ];
        then
            aws s3 cp $HOME/wgs-results/!{params.runID}/!{params.runID}_failed.scemail !{params.s3_email_out} --acl bucket-owner-full-control
        fi

        """
    }
}


/*
 * PRE-STEP v - fastp quality trimming
*/

process fastp_qual_trim {
    

    publishDir "$HOME/wgs-results/${params.runID}/${sample_id}/fastp", mode: 'copy'

    input:
    val go from goCh1
    tuple sample_id, readCount, readFile1, readFile2 from runCh

    output:
    file("*_fastp.log") into cleanup_ch1
    tuple sample_id, file("*_{R1,R2}.fastq.gz") into cleanedReads

    script:
    """
    fastp --in1 ${readFile1} --in2 ${readFile2} --out1 ${sample_id}_R1.fastq.gz --out2 ${sample_id}_R2.fastq.gz --qualified_quality_phred 20 -u 40 -l 80 > ${sample_id}_fastp.log 2>&1
    """
}


/*
 * PRE-STEP vi - seqtk subsampling
*/

process subsampling {
    publishDir "$HOME/wgs-results/${params.runID}/${sample_id}/subsampling", mode: 'copy'

    input:
    val logfile from cleanup_ch1
    tuple sample_id, readPair from cleanedReads

    output:
    file("*_subsampling.log") into cleanup_ch2
    val sample_id into cleanup_ch3
    tuple sample_id, file("*_{R1,R2}.fastq.gz") into reads1, reads2, reads3, reads4, reads5, reads6, reads7, reads8, reads9, reads_summ1, reads_summ2

    shell:
    '''
    sleep 15
    ls $HOME/wgs-results/!{params.runID}/!{sample_id}/fastp/*.fastq.gz > cleanup.txt || echo "no files found"
    rm $HOME/wgs-results/!{params.runID}/!{sample_id}/fastp/*.fastq.gz || echo "nothing to delete"
    READFILE1=$(echo !{readPair[0]})
    READCOUNT=$(zcat $READFILE1|echo $(wc -l)/4|bc)
    echo $READCOUNT > !{sample_id}_subsampling.log
    READFILE2=$(echo $READFILE1 | sed -e 's/_R1.fastq.gz/_R2.fastq.gz/')
    OUTNAME1=$(basename $READFILE1 | sed -e 's/_R1.fastq.gz/_R1.fastq/')
    OUTNAME2=$(basename $READFILE2 | sed -e 's/_R2.fastq.gz/_R2.fastq/')
    if [ $READCOUNT -gt !{params.subsampThreshold} ]
    then
        echo "Greater than !{params.subsampThreshold} reads, subsampling to !{subsamp}" >> !{sample_id}_subsampling.log
        /opt/conda/bin/seqtk sample -s100 $READFILE1 !{subsamp} > $OUTNAME1
        gzip --fast $OUTNAME1
        /opt/conda/bin/seqtk sample -s100 $READFILE2 !{subsamp} > $OUTNAME2
        gzip --fast $OUTNAME2
    else
        echo "Fewer than !{params.subsampThreshold} reads, skipping" >> !{sample_id}_subsampling.log
        mv $READFILE1 .
        mv $READFILE2 .
    fi
    CLEANUPDIR=$(dirname !{logfile})
    ls $CLEANUPDIR/*.fastq.gz >> cleanup.txt || echo "no files found"
    rm $CLEANUPDIR/*.fastq.gz || echo "nothing to delete"
    cp $(basename $READFILE1) $HOME/wgs-reads/!{params.runID}
    cp $(basename $READFILE2) $HOME/wgs-reads/!{params.runID}
    '''
}


/*
 * PRE-STEP vii - clean up intermediate readfiles to save disk space
*/

process intermediate_reads_cleanup {
    input:
    val logfile2 from cleanup_ch2
    val sample_id from cleanup_ch3

    shell:
    '''
    sleep 15
    ls $HOME/wgs-results/!{params.runID}/!{sample_id}/subsampling/*.fastq.gz > cleanup.txt || echo "no files found"
    rm $HOME/wgs-results/!{params.runID}/!{sample_id}/subsampling/*.fastq.gz || echo "nothing to delete"
    '''
}


/*
 * STEP 1 - fastqc
*/

process fastqc {
    publishDir "$HOME/wgs-results/${params.runID}/${sample_id}/FASTQC_Reports", mode: 'move'

    input:
    tuple sample_id, file(reads_file) from reads1

    output:
    file("${sample_id}_{R1,R2}_fastqc.{html,zip}")
    file("${sample_id}_1.txt") into out1_ch
    file("${sample_id}_1.txt") into out1_ch_rem


    script:
    """
    fastqc  -f fastq -q ${reads_file}
    touch ${sample_id}_1.txt
    """
}


/*
 * STEP 2 - shovill
*/

process shovill {
    publishDir "$HOME/wgs-results/${params.runID}/${sample_id}/shovill", mode: 'copy'

    input:
    tuple sample_id, file(reads_file) from reads2

    output:
    file "*" into shovill_all_ch
    set sample_id, file("${sample_id}_contigs.fa") into quast_ch
    set sample_id, file("${sample_id}_contigs.fa") into sistr_ch
    file("${sample_id}_2.txt") into out2_ch
    file("${sample_id}_2.txt") into out2_ch_rem


    script:
    """
    #/opt/conda/bin/shovill --R1 ${sample_id}_R1.fastq.gz --R2 ${sample_id}_R2.fastq.gz
    /opt/conda/bin/shovill --outdir $HOME/wgs-results/${params.runID}/${sample_id}/shovill --R1 ${sample_id}_R1.fastq.gz --R2 ${sample_id}_R2.fastq.gz
    mv $HOME/wgs-results/${params.runID}/${sample_id}/shovill/contigs.fa ${sample_id}_contigs.fa
    touch ${sample_id}_2.txt
    
    cp $HOME/wgs-results/${params.runID}/${sample_id}/shovill/contigs.fasta $HOME/wgs-results/${params.runID}/assemblies/${sample_id}.fa

    
    """


}


/*
 * STEP 3 - quast
*/

quast_ch
    .join(reads3)
    .set { quast_in }

process quast {
    publishDir "$HOME/wgs-results/${params.runID}/${sample_id}/quast",  mode: 'copy'

    input:
    set sample_id, file("${sample_id}_contigs.fa"), file (reads_file) from quast_in

    output:
    file("${sample_id}_3.txt") into out3_ch
    file("${sample_id}_3.txt") into out3_ch_rem


    script:
    """
    python /usr/local/bin/quast.py -o $HOME/wgs-results/${params.runID}/${sample_id}/quast "${sample_id}_contigs.fa"
    touch ${sample_id}_3.txt
    """
}


/*
 * STEP 4 - kmerid
*/

process kmerid {
    publishDir "$HOME/wgs-results/${params.runID}/${sample_id}/Kmerid",  mode: 'copy'

    input:
    tuple sample_id, file(reads_file) from reads4

    output:
    file("${sample_id}_R1.tsv")
    file("${sample_id}_4.txt") into out4_ch
    file("${sample_id}_4.txt") into out4_ch_rem

    script:
    """
    python /opt/kmerid/kmerid_python3.py -f ${reads_file[0]} -c /opt/kmerid/config/config.cnf -n > ${sample_id}_R1.tsv
    touch ${sample_id}_4.txt
    """
}


/*
 * STEP 5 - seqsero2
*/

process seqsero2 {
    publishDir "$HOME/wgs-results/${params.runID}/${sample_id}/SeqSero2", mode: 'copy'

    input:
    tuple sample_id, file(reads_file) from reads5

    output:
    file("${sample_id}_5.txt") into out5_ch
    file("${sample_id}_5.txt") into out5_ch_rem

    script:
    """
    /opt/conda/bin/SeqSero2_package.py -m a -b mem -t 2 -d $HOME/wgs-results/${params.runID}/${sample_id}/SeqSero2 -i ${reads_file[0]} ${reads_file[1]}
    touch ${sample_id}_5.txt
    """
}


/*
 * STEP 6 - sistr
*/

sistr_ch
    .join(reads6)
    .set { sistr_in }

process sistr {
    publishDir "$HOME/wgs-results/${params.runID}/${sample_id}/sistr", mode: 'move'

    input:
    set sample_id, file("${sample_id}_contigs.fa"), file (reads_file) from sistr_in

    output:
    file 'sistr_prediction.csv' into sistr_out_ch
    file("${sample_id}_6.txt") into out6_ch
    file("${sample_id}_6.txt") into out6_ch_rem

    script:
    """
    /opt/conda/bin/sistr -i "${sample_id}_contigs.fa" ${sample_id} -f csv -o sistr_prediction.csv --qc
    touch ${sample_id}_6.txt
    """
}


/*
 * STEP 7 - MOST
*/

process most {
    publishDir "$HOME/wgs-results/${params.runID}/${sample_id}/MOST", mode: 'copy'

    input:
    tuple sample_id, file(reads_file) from reads7

    output:
    file("${sample_id}_7.txt") into out7_ch
    file("${sample_id}_7.txt") into out7_ch_rem
    set sample_id, file("${sample_id}_serovar.tsv") into most_out_ch

    shell:
    '''
    python /opt/most/MOST-master/MOST.py -1 !{reads_file[0]} -2 !{reads_file[1]} -st /opt/most/MOST-master/MLST_data/salmonella --output_directory $HOME/wgs-results/!{params.runID}/!{sample_id}/MOST -serotype True --bowtie /opt/most/bowtie2-2.1.0/bowtie2 --samtools /opt/most/samtools-0.1.18/samtools
    if grep "predicted_serotype" $HOME/wgs-results/!{params.runID}/!{sample_id}/MOST/!{sample_id}_R1.fastq.results.xml
    then
        grep "predicted_serotype" $HOME/wgs-results/!{params.runID}/!{sample_id}/MOST/!{sample_id}_R1.fastq.results.xml >> serovar1.txt
        if grep -q "ST-serotype" serovar1.txt
        then
            awk '{print substr(\$2,1,5); }' serovar1.txt > serovar2.txt
            mv serovar2.txt  !{sample_id}_serovar.tsv
        else
            awk '{print substr(\$3,10); }' serovar1.txt > serovar2.txt
            mv serovar2.txt  !{sample_id}_serovar.tsv
        fi
    else
        grep "profile" $HOME/wgs-results/!{params.runID}/!{sample_id}/MOST/!{sample_id}_R1.fastq.results.xml >> serovar1.txt
        awk '{print substr(\$3,1,5); }' serovar1.txt > serovar2.txt
        mv serovar2.txt  !{sample_id}_serovar.tsv
    fi
    touch !{sample_id}_7.txt
    rm $HOME/wgs-results/!{params.runID}/!{sample_id}/MOST/tmp/*.pileup
    rm $HOME/wgs-results/!{params.runID}/!{sample_id}/MOST/tmp/*.fa
    rm $HOME/wgs-results/!{params.runID}/!{sample_id}/MOST/tmp/*.fa.fai
    rm $HOME/wgs-results/!{params.runID}/!{sample_id}/MOST/tmp/*.bam
    rm $HOME/wgs-results/!{params.runID}/!{sample_id}/MOST/tmp/*.bam.bai
    '''
}


/*
 * STEP 8 - srst2
*/

most_out_ch
    .join(reads8)
    .set { sero_in }


process srst2 {
    publishDir "$HOME/wgs-results/${params.runID}/${sample_id}/srst2", mode: 'copy'

    input:
    set sample_id, file("${sample_id}_serovar.tsv"), file (reads_file) from sero_in

    output:
    file("${sample_id}_8.txt") into out8_ch
    file("${sample_id}_8.txt") into out8_ch_rem

    

    script:
    """
    if grep -E "(Typhimurium|Enteritidis|Gallinarum|Pullorum|Idikan|Kedougou|Java|Paratyphi|type=)" ${sample_id}_serovar.tsv
    then
    export SRST2_BOWTIE2=/opt/srst2/bowtie2-2.2.3/bowtie2
    export SRST2_BOWTIE2_BUILD=/opt/srst2/bowtie2-2.2.3/bowtie2-build
    srst2.py  --input_pe ${sample_id}_R1.fastq.gz ${sample_id}_R2.fastq.gz --forward _R1 --reverse _R2 --output $HOME/wgs-results/${params.runID}/${sample_id}/srst2/ --log --gene_db /opt/srst2/VaccineDifferentiation/allVacDB9h4_clustered.fasta
    touch ${sample_id}_8.txt
    else
    touch ${sample_id}_8.txt
    fi
    
    """



}


/*
 * STEP 9 - summary
*/

process summary_and_lims {
    publishDir "$HOME/wgs-results/${params.runID}", mode: 'copy'

    input:
    val read from reads_summ1.count()
        .view()
    val c1 from out1_ch.count()
        .view()
    val c2 from out2_ch.count()
        .view()
    val c3 from out3_ch.count()
        .view()
    val c4 from out4_ch.count()
        .view()
    val c5 from out5_ch.count()
        .view()
    val c6 from out6_ch.count()
        .view()
    val c7 from out7_ch.count()
        .view()
    val c8 from out8_ch.count()
        .view()
    val go from goCh2

    output:
    file("*.csv")
    file("*_plusLIMS.csv") into sum_tab_ch

    when:
    c1 + c2 + c3 + c4+ c5+ c6 + c7 + c8 == read*8

    script:
    """
    python $HOME/SalmoType/summaryTable_reworked.py  ${params.runID}
    python3 $HOME/SalmoType/lims_rules/lims_rules.py $HOME/wgs-results/${params.runID}/${params.runID}_SummaryTable.csv
    """
}


/*
 * STEP 10 - Typhimurium identification
*/

process typhi_move {

    input:
    path sum_file from sum_tab_ch

    output:
    file("typhi.txt") into out9_ch_rem
    path "typhim_here", optional: true into typhi_check_ch
    path "typhimurium_isolates", type: 'dir', optional: true into isolates_dir_ch

    shell:
    """
    mkdir $HOME/wgs-reads/${params.runID}/typhimurium_isolates
    $HOME/SalmoType/scripts/typhimurium_id.py -i ${sum_file} -rd $HOME/wgs-reads/${params.runID}
    cp -r $HOME/wgs-reads/${params.runID}/typhimurium_isolates ./typhimurium_isolates 2>/dev/null || true
    touch typhim_here
    touch typhi.txt
    """

}

summary_single_ch = sum_tab_ch.first()

// Build (id, r1, r2) tuples from each isolates directory
pair_ch = isolates_dir_ch
    .flatMap { dir ->
        // List all FASTQ files once
        def all = file(dir).listFiles()
            .findAll { it.name.endsWith('.fastq.gz') }

        // Group by sample id (strip trailing _R1/_R2)
        def grouped = all.groupBy { f ->
            f.name.replaceAll(/_(R1|R2)\.fastq\.gz$/, '')
        }

        // Return a List of tuples for flatMap to flatten
        grouped.collect { id, files ->
            def r1 = files.find { it.name.endsWith('_R1.fastq.gz') }
            def r2 = files.find { it.name.endsWith('_R2.fastq.gz') }
            (r1 && r2) ? tuple(id, r1, r2) : null
        }.findAll { it != null }
    }

/*
 * STEP 11 - PrimunT screen
*/

process diva_test {
    conda '/opt/conda/envs/snippy'

    input:
    tuple val(isolate_id), path(r1), path(r2) from pair_ch
    path sum_file from summary_single_ch
    path t_check from typhi_check_ch

    when:
    t_check

    output:
    file("*t-diva_added.csv") into diva_tab_ch
    file("diva.txt") into out10_ch_rem


    shell:
    """
    mkdir $HOME/wgs-reads/${params.runID}/typhimurium_isolates/${isolate_id}
    python $HOME/SalmoType/scripts/diva_test_s3_251204_local_single.py $HOME/SalmoType/diva_components/arguments_file_251204.txt ${sum_file} $HOME/wgs-reads/${params.runID}/typhimurium_isolates/${isolate_id} ${r1} ${r2}
    touch diva.txt
    """ 
}

all_isolates_done_ch = diva_tab_ch.collect()

/*
 * STEP 12 - PrimunT summary table merge
*/
process diva_merge {
    conda '/opt/conda/envs/snippy'

    input:
    val all from all_isolates_done_ch

    output:
    file("merge.txt") into out11_ch_rem

    shell:
    """
    $HOME/SalmoType/scripts/sum_diva_merge_single.py -i $HOME/wgs-results/${params.runID}/${params.runID}_SummaryTable_plusLIMS.csv -d $HOME/wgs-reads/${params.runID}/typhimurium_isolates -pi ${params.runID}
    touch merge.txt
    """

}