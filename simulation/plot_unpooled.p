unset logscale                              # remove any log-scaling
unset label
set term jpeg
set output 'unpooled_test.jpeg'
set title "Power of unpooled tests"
set xlabel "log(variants)"
set ylabel "Power"
set yrange [0:120]
set logscale x
plot 'unpooled_test_with_unique_top_ranks' w linespoints, \
     'unpooled_test_with_maximal_set_of_top_ranks' w linespoints, \
     'unpooled_test_with_a_top_rank' w linespoints

