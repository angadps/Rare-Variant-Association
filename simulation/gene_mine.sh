#!/bin/sh

# To be run from path $Data/PI-1/var-1024/

for i in `seq 1 100`
do
	grep -v ^# case_${i}_annotated.vcf | cut -f 8 | cut -d';' -f5- | tr ';' '\n' | cut -d'(' -f2 | cut -d')' -f 1 | grep uc | sort | uniq -c | awk -F " " 'BEGIN{max=0;gene="uc";} {sub(/^[ \t]+/,"");if($1>max) {max=$1;gene=$2;}} END{print gene}' > ds_${i}.gene
done

