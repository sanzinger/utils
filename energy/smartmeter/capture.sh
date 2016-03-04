#!/bin/bash

while true; do
	d="$(date +%Y-%m-%d_%H:%M:%S)"

	dev=/dev/video0
	v4l2-ctl -d ${dev} --set-ctrl=exposure_auto=1

	#ffmpeg  -f video4linux2 -s 160x120 -i ${dev} -c:v libx264 -preset slow -c:a none /home/stefan/capture/output-${d}.mkv
	#ffmpeg  -f video4linux2 -s 160x120 -i ${dev} -r 25 /home/stefan/capture/output-${d}.mpg
	ffmpeg -f video4linux2  -framerate 25 -s 160x120 -i ${dev} -r 25 -t 3600 /home/stefan/capture/output-${d}.mpg
done
