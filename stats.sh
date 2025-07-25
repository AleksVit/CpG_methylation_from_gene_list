 
bedtools nuc -fi "$REF" -bed prom_tmp.bed -pattern CG \
| awk 'BEGIN{OFS="\t"}$1 !~ /^#/ {coord = $1":"$2"-"$3; print $4, coord, $10 }'  > _gene_cpg.tmp          # Gene_prom  coord  CpG_sites

modkit stats --regions prom_tmp.bed \
             --out-table stdout \
             --min-coverage 1 \
             mods_cpg_filt.bed.gz \
| awk 'BEGIN{OFS="\t"} $1 !~ /^#/ { print $4, $9 }' \
> _gene_meth.tmp          # Gene   CpG_sites   CpG_methylated

# 2) Среднее покрытие (mosdepth) — ключ = Gene
mosdepth --by prom_tmp.bed -t "$THREADS" geneCov "$BAM"

zgrep -v '^#' geneCov.regions.bed.gz | awk '{print $4"\t"$5}' \
| sort -k1,1 > _gene_cov.tmp        # Gene  mean_cov
rm -f geneCov.*
##############################################################################
# 3) Склеиваем on-the-fly: CpG-таблица ➜ hash ➜ добавляем coverage
# 3) Склеиваем всё в одну таблицу
##############################################################################
#  _gene_cpg.tmp  : Gene  coord  CpG_sites
#  _gene_meth.tmp : Gene  CpG_methylated
#  _gene_cov.tmp  : Gene  mean_cov

awk -v OFS='\t' '
    ARGIND==1 { meth[$1] = $2;  next }          # файл 1: метилированные CpG
    ARGIND==2 { cov[$1]  = $2;  next }          # файл 2: среднее покрытие
    # файл 3 (CpG_sites + coord) → вывод
    {
       gene  = $1
       coord = $2
       cpg   = $3
       printf "%s\t%s\t%s\t%d\t%.2f\n", \
              gene, coord, cpg,                \
              (gene in meth ? meth[gene] : 0), \
              (gene in cov  ? cov[gene]  : 0)
    }
' _gene_meth.tmp _gene_cov.tmp _gene_cpg.tmp \
| sort -k1,1 \
| sed '1iGene\tcoord\tCpG_sites\tCpG_methylated\tmean_coverage' \
> "$OUT"
echo "✓ Готово: gene_summary.tsv"
echo "Формат: Gene  chr:start-end  CpG_sites  mean_coverage"
