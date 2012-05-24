#!/bin/sh
#$ -cwd

# Sample file for triggering adhoc association test jobs
# Can be invoked as run_assoc_test.sh "8"
# Modify this as per need

var=10
for ds in 94
do
	sh run_assoc_test.sh 8 $var $ds
done

