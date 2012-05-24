unset logscale                              # remove any log-scaling
unset label
set term jpeg
set output 'pooled_test.jpeg'
set title "Power of pooled tests"
set xlabel "log(variants)"
set ylabel "Power"
set yrange [0:120]
set logscale x
plot 'pooled_test_with_unique_top_ranks' w linespoints, \
     'pooled_test_with_a_top_rank' w linespoints

