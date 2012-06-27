unset logscale                              # remove any log-scaling
unset label
set term postscript dl 2 size 3.09,2.29 font 6
set output 'power_tests.ps'
set title "Power of pooled and un-pooled tests"
set xlabel "#causal variants/gene - log scale"
set ylabel "Power"
set xrange [1:1200]
set yrange [0:1]
set logscale x
set tics scale 0.75
set style line 1 lt 1 pt 3 lw 3 lc rgb "cyan"
set style line 2 lt 2 pt 3 lw 3 lc rgb "cyan"
set style line 3 lt 4 pt 3 lw 3 ps 3 lc rgb "magenta"
set style line 4 lt 2 pt 3 lw 3 lc rgb "magenta"
set style line 5 lt 1 pt 3 lw 3 lc rgb "magenta"
set key at 22,0.97
plot 'Pooled: non-unique' w l ls 1, \
     '      : unique' w l ls 2, \
     'Unpooled: non-unique' w l ls 5, \
     '        : majority vote' w l ls 3, \
     '        : unique' w l ls 4

