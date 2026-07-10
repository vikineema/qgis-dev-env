# SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
# SPDX-License-Identifier: MIT
#
# Kartoza-branded build-performance infographic for qgis-dev.
# Driven by qgis-dev report, which passes these via -e:
#   infile   TSV: idx  duration_s  hit_pct  ok(1/0)
#   proffile TSV: idx  avg_duration  count  profile_name
#   outfile  target path
#   term     'pdf' | 'svg' | 'png'
#   host, gendate                       (strings)
#   rtotal, ravg, rmed, rmin, rmax,     (build-time scalars, seconds)
#   rhit, rhits, rmisses, rok, rfail,   (ccache + result scalars)
#   rlast, rcache                       (last build s; ccache size string)

set datafile missing "-"

blue   = "#54A2CC"
amber  = "#EEB348"
grey   = "#8A8B8B"
char   = "#383939"
okcol  = "#3C7D54"
badcol = "#B0473C"
cloud  = "#F5F5F2"

if (term eq "pdf") { set terminal pdfcairo size 11in,8.5in font "sans,10" background rgb "white" }
if (term eq "svg") { set terminal svg size 1200,930 font "sans,13" background rgb "white" }
if (term eq "png") { set terminal pngcairo size 1500,1160 font "sans,12" background rgb "white" }
set output outfile

set multiplot

# ---- header band -----------------------------------------------------------
set label 1 "QGIS BUILD PERFORMANCE" at screen 0.06,0.955 left \
    font "sans,20" tc rgb char front
set label 2 sprintf("%s  ·  %d builds logged  ·  generated %s", host, rtotal, gendate) \
    at screen 0.06,0.918 left font "sans,10" tc rgb grey front
set label 3 "Made with love by Kartoza" at screen 0.94,0.955 right \
    font "sans,10" tc rgb blue front
set object 1 rect from screen 0.06,0.905 to screen 0.94,0.907 \
    fc rgb amber fillstyle solid noborder behind

# ---- footer summary band ---------------------------------------------------
set object 2 rect from screen 0.06,0.06 to screen 0.94,0.20 \
    fc rgb cloud fillstyle solid noborder behind
set label 10 sprintf("AVG %s", ravg)   at screen 0.09,0.16 left font "sans,11" tc rgb char front
set label 11 sprintf("MEDIAN %s", rmed) at screen 0.09,0.115 left font "sans,11" tc rgb char front
set label 12 sprintf("FASTEST %s", rmin) at screen 0.30,0.16 left font "sans,11" tc rgb okcol front
set label 13 sprintf("SLOWEST %s", rmax) at screen 0.30,0.115 left font "sans,11" tc rgb badcol front
set label 14 sprintf("LAST %s", rlast) at screen 0.50,0.16 left font "sans,11" tc rgb char front
set label 15 sprintf("BUILDS %d  (%d ok / %d fail)", rtotal, rok, rfail) \
    at screen 0.50,0.115 left font "sans,11" tc rgb char front
set label 16 sprintf("CCACHE HIT %.0f%%", rhit) at screen 0.72,0.16 left font "sans,11" tc rgb blue front
set label 17 sprintf("CACHE %s", rcache) at screen 0.72,0.115 left font "sans,11" tc rgb char front
set label 18 sprintf("%d hits / %d misses", rhits, rmisses) \
    at screen 0.09,0.075 left font "sans,9" tc rgb grey front

set grid ytics lc rgb "#D1D1D1" lw 1
set border lc rgb grey
set tics tc rgb grey font "sans,8"
set key off

# ---- panel 1: build duration trend (wide, top) -----------------------------
set size 0.88,0.42
set origin 0.06,0.47
set title "Build duration over time (seconds)" offset 0,-0.5 tc rgb char font "sans,12"
set xlabel "build #" tc rgb grey font "sans,9"
set ylabel "seconds" tc rgb grey font "sans,9"
set autoscale
if (ylog) { set logscale y; set ylabel "seconds (log scale)" tc rgb grey font "sans,9" }
plot infile using 1:2 with lines lc rgb blue lw 1.5 notitle, \
     infile using 1:($4==1 ? $2 : 1/0) with points pt 7 ps 0.5 lc rgb blue notitle, \
     infile using 1:($4==0 ? $2 : 1/0) with points pt 7 ps 0.7 lc rgb badcol notitle, \
     infile using 1:2 smooth bezier with lines lc rgb amber lw 2.5 dt 2 notitle

# ---- panel 2: ccache hit rate (mid-left) -----------------------------------
unset logscale y
set ylabel "seconds" tc rgb grey font "sans,9"
set size 0.42,0.22
set origin 0.06,0.23
set title "ccache hit rate (%)" offset 0,-0.5 tc rgb char font "sans,11"
set xlabel "build #" tc rgb grey font "sans,8"
set ylabel "%" tc rgb grey font "sans,8"
set yrange [0:100]
plot infile using 1:3 with filledcurves y1=0 fc rgb amber fs solid 0.25 notitle, \
     infile using 1:3 with lines lc rgb amber lw 2 notitle
unset yrange

# ---- panel 3: average duration by profile (mid-right) ----------------------
set size 0.42,0.22
set origin 0.52,0.23
set title "avg duration by profile (s)" offset 0,-0.5 tc rgb char font "sans,11"
set style fill solid 0.85 border rgb char
set boxwidth 0.6
set xtics tc rgb grey font "sans,8"
unset xlabel
set ylabel "seconds" tc rgb grey font "sans,8"
plot proffile using 1:2:xtic(4) with boxes lc rgb blue notitle, \
     proffile using 1:($2*1.02):(sprintf("%d", $3)) with labels tc rgb grey font "sans,7" notitle

unset multiplot
set output
