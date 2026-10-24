#!/usr/bin/env bash
# Chay lai cac phep thu trong bay-ffmpeg.md. Can ffmpeg + ffprobe trong PATH
# (hoac dat VP_FFMPEG_DIR = thu muc chua ffmpeg). Chi tao tep nho trong thu muc tam, khong goi mang.
set -euo pipefail
[ -n "${VP_FFMPEG_DIR:-}" ] && export PATH="$VP_FFMPEG_DIR:$PATH"
T="$(mktemp -d)"; cd "$T"; echo "thu muc tam: $T"
px() { ffmpeg -v error -y -ss "$2" -i "$1" -frames:v 1 -vf scale=1:1 -f rawvideo -pix_fmt rgb24 - | od -An -tu1; }
cnt() { ffprobe -v error -count_frames -select_streams v -show_entries stream=nb_read_frames -of csv=p=0 "$1"; }

ffmpeg -v error -y -f lavfi -i color=c=blue:s=320x180:r=30:d=5 -c:v libx264 -pix_fmt yuv420p nen.mp4
ffmpeg -v error -y -f lavfi -i color=c=red:s=320x180:r=30:d=1  -c:v libx264 -pix_fmt yuv420p lop.mp4

echo "== 1. lop phu vao muon (ky vong: xanh luc 1.9s, DO luc 2.5s, xanh luc 3.5s)"
ffmpeg -v error -y -i nen.mp4 -i lop.mp4 -filter_complex \
 "[1:v]format=rgba,tpad=start_mode=add:color=black@0:start_duration=2,setpts=PTS-STARTPTS[o];[0:v][o]overlay=eof_action=pass[v]" \
 -map "[v]" -frames:v 150 muon.mp4
for t in 1.9 2.5 3.5; do echo "t=$t RGB:$(px muon.mp4 $t)"; done

echo "== 2. -frames:v cho so khung chinh xac (ky vong 36 36 36)"
ffmpeg -v error -y -f lavfi -i testsrc=s=320x180:r=30000/1001:d=10 -c:v libx264 -pix_fmt yuv420p src.mp4
for i in 1 2 3; do ffmpeg -v error -y -ss $((i*2)) -i src.mp4 -frames:v 36 -vf fps=30 -c:v libx264 -pix_fmt yuv420p -r 30 c$i.mp4; done
echo "so khung: $(cnt c1.mp4) $(cnt c2.mp4) $(cnt c3.mp4)"

echo "== 3. logo + PNG sequence tach hai buoc (ky vong ma thoat 0 0)"
ffmpeg -v error -y -f lavfi -i "color=c=white:s=60x60,format=rgba" -frames:v 1 logo.png
mkdir seq; ffmpeg -v error -y -f lavfi -i "color=c=red:s=320x180:r=30:d=1,format=rgba" seq/f%03d.png
timeout 60 ffmpeg -v error -y -i nen.mp4 -loop 1 -framerate 30 -i logo.png -filter_complex "[0:v][1:v]overlay=10:10:shortest=1[v]" -map "[v]" -frames:v 150 b1.mp4; echo "buoc1 ma thoat: $?"
timeout 60 ffmpeg -v error -y -i b1.mp4 -framerate 30 -i seq/f%03d.png -filter_complex \
 "[1:v]format=rgba,tpad=start_mode=add:color=black@0:start_duration=2,setpts=PTS-STARTPTS[o];[0:v][o]overlay[v]" \
 -map "[v]" -frames:v 150 b2.mp4; echo "buoc2 ma thoat: $?"

echo "== 4. xoay: cat theo khung da giai ma (ky vong 180,320 va 100,180)"
ffmpeg -v error -y -display_rotation 90 -i src.mp4 -c copy rot.mp4
CROP="crop='if(gt(ih,iw),iw,ih*9/16)':'if(gt(ih,iw),iw*16/9,ih)'"
ffmpeg -v error -y -i rot.mp4 -frames:v 1 -vf "$CROP" a.png; ffprobe -v error -show_entries stream=width,height -of csv=p=0 a.png
ffmpeg -v error -y -i src.mp4 -frames:v 1 -vf "$CROP" b.png; ffprobe -v error -show_entries stream=width,height -of csv=p=0 b.png
echo "stream_side_data_list:"; ffprobe -v error -select_streams v -show_entries stream_side_data_list -of default=nw=1 rot.mp4 | grep -m1 rotation
rm -rf "$T"
