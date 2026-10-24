# Bẫy ffmpeg đã gặp khi dựng video

Gom từ các lần dựng video thật (tháng 9 và 10/2026). Mỗi bẫy ghi rõ một trong hai nhãn:

- **đã kiểm**: chạy lại được trên máy này bằng ffmpeg 8.1.2 (Gyan full build, cài qua winget), lệnh mẫu bên dưới chạy đúng.
- **từ ghi chép, chưa kiểm lại**: lấy từ ghi chép lúc dựng thật, chưa tái hiện được trong bài thử nhỏ.

Chạy lại các phép thử: `bash docs/kiem-bay-ffmpeg.sh` (cần ffmpeg và ffprobe trong PATH, hoặc đặt `VP_FFMPEG_DIR`). Chỉ tạo tệp nhỏ trong thư mục tạm, không gọi mạng.

Gọi ffmpeg trên Windows khi PATH của phiên chưa nhận: dùng đường dẫn đầy đủ tới `ffmpeg.exe` trong thư mục winget (`...\Packages\Gyan.FFmpeg_*\ffmpeg-*\bin`), hoặc đặt biến `VP_FFMPEG_DIR` cho các script trong repo này.

---

## 1. Lớp phủ vào muộn: dùng `tpad`, đừng chỉ dùng `setpts=PTS+t/TB`

**Triệu chứng ghi nhận:** lớp phủ có mốc bắt đầu muộn (ví dụ bốn lớp flash ở giữa clip) biến mất, trong khi lớp phủ bắt đầu ở giây 0 (sting mở đầu) vẫn chạy bình thường. ffmpeg không báo lỗi gì. Rất dễ nhìn thấy sting mở đầu rồi tưởng cả bộ đúng.

**Nguyên nhân theo ghi chép:** framesync của `overlay` bỏ qua luồng phụ bắt đầu sau luồng chính.

**Cách đúng (đã kiểm):**

```bash
ffmpeg -i nen.mp4 -i lop.mp4 -filter_complex \
 "[1:v]format=rgba,tpad=start_mode=add:color=black@0:start_duration=2,setpts=PTS-STARTPTS[o];[0:v][o]overlay=eof_action=pass[v]" \
 -map "[v]" -frames:v 150 muon.mp4
```

`start_duration` là số giây lớp phủ phải chờ. Phép thử: nền xanh 5 giây, lớp đỏ dài 1 giây, `start_duration=2`. Khung ở 1,9 giây xanh, 2,5 giây đỏ, 3,5 giây xanh. Đúng như mong muốn.

**Lưu ý trung thực:** bài thử nhỏ này (hai tệp mp4 hoặc một chuỗi PNG, ffmpeg 8.1.2) với `setpts=PTS+2/TB` đơn thuần vẫn hiện lớp phủ, tức là **chưa tái hiện được lỗi gốc**. Lỗi gốc xảy ra trong filtergraph lớn hơn (nhiều lớp, sting, flash). Vì vậy vẫn giữ `tpad` làm cách mặc định, nó chạy đúng ở cả hai trường hợp.

**Cách soi:** rút 3 khung của từng lớp phủ, ở trước mốc 0,1 giây, đúng mốc, sau mốc 0,1 giây, rồi nhìn. Không nhìn thì không biết.

```bash
ffmpeg -ss 2.4 -i ra.mp4 -frames:v 1 truoc.png   # truoc moc
ffmpeg -ss 2.5 -i ra.mp4 -frames:v 1 dung.png    # dung moc
ffmpeg -ss 2.6 -i ra.mp4 -frames:v 1 sau.png     # sau moc
```

## 2. Dựng từng cảnh: `-frames:v N` thay cho `-t`

**Ghi chép:** render từng cảnh bằng `-t` lệch cộng dồn khoảng một khung mỗi cảnh. 23 cảnh trượt 0,27 giây, đủ làm mọi điểm cắt lệch khỏi nhịp nhạc.

**Cách đúng:** tính N = số giây nhân fps, rồi dùng `-frames:v N` ở cảnh trung gian.

```bash
# canh 1,2 giay o 30 fps = 36 khung
ffmpeg -ss 2 -i nguon.mp4 -frames:v 36 -vf fps=30 -c:v libx264 -pix_fmt yuv420p -r 30 canh.mp4
```

**Trạng thái: đã kiểm một nửa.** `-frames:v 36` luôn ra đúng 36 khung (nguồn 29,97 và 23,976 fps, ba cảnh mỗi loại, đếm bằng `ffprobe -count_frames`). Nhưng cùng bài thử với `-t 1.2` cũng ra đúng 36 khung, nên **chưa tái hiện được độ lệch của `-t`**. Độ lệch gốc có thể đến từ nguồn VFR hoặc cách cắt. Dù vậy `-frames:v` là cách chắc chắn đúng nên vẫn khuyên dùng.

Khi cần xác minh độ dài thật, đếm khung chứ đừng tin trường `duration`:

```bash
ffprobe -v error -count_frames -select_streams v -show_entries stream=nb_read_frames -of csv=p=0 canh.mp4
```

## 3. Treo cứng khi một filtergraph vừa có `-loop 1 logo.png` vừa có nhiều chuỗi PNG

**Triệu chứng ghi nhận:** 0% CPU, khoảng 1,8 GB bộ đệm, tệp ra đứng im giữa chừng, không lỗi, không thoát. Gọi thẳng từ bash vẫn treo (không phải bẫy riêng của Python subprocess).

**Cách đúng: tách hai bước.** Bước 1 đốt logo góc vào hình. Bước 2 mới dán sting, flash, nhạc. Mỗi bước chạy 11 đến 16 giây thay vì treo vô hạn.

```bash
# buoc 1: logo
timeout 60 ffmpeg -i nen.mp4 -loop 1 -framerate 30 -i logo.png \
  -filter_complex "[0:v][1:v]overlay=10:10:shortest=1[v]" -map "[v]" -frames:v 150 b1.mp4
# buoc 2: chuoi PNG (flash/sting)
timeout 60 ffmpeg -i b1.mp4 -framerate 30 -i seq/f%03d.png -filter_complex \
  "[1:v]format=rgba,tpad=start_mode=add:color=black@0:start_duration=2,setpts=PTS-STARTPTS[o];[0:v][o]overlay[v]" \
  -map "[v]" -frames:v 150 b2.mp4
```

**Trạng thái:** hai lệnh trên **đã kiểm là chạy xong** (mã thoát 0 cả hai, cỡ nhỏ). **Chưa tái hiện được cái treo** (cố ý không thử bản gộp trên máy chậm), nên phần "vì sao treo" là từ ghi chép, chưa kiểm lại. Luôn bọc `timeout` khi chạy thử filtergraph lớn.

## 4. Metadata xoay: đừng đọc, hãy quyết theo khung đã giải mã

ffmpeg tự áp cờ xoay lúc giải mã, nên khung đi vào filter đã đứng đúng chiều. Đọc cờ xoay rồi tự xoay thêm là xoay hai lần.

**Cách đúng:** viết crop thành biểu thức dựa trên khung đã giải mã.

```bash
CROP="crop='if(gt(ih,iw),iw,ih*9/16)':'if(gt(ih,iw),iw*16/9,ih)'"
ffmpeg -i nguon.mp4 -vf "$CROP,scale=1080:1920" ra.mp4
```

**Đã kiểm:** tạo tệp 320x180 gắn xoay 90 độ (`ffmpeg -display_rotation 90 -i src.mp4 -c copy rot.mp4`). `ffprobe` báo kích thước mã hoá 320,180 nhưng khung giải mã ra 180,320. Biểu thức crop trên cho 180x320 với tệp xoay và 100x180 với tệp ngang thường, đúng cả hai.

**Về `ffprobe`:** muốn đọc cờ xoay ở mức luồng thì dùng `-show_entries stream_side_data_list`. Ghi chép cũ nói `side_data=rotation` trả rỗng trên 8.1; bài thử này thấy nó **in ra một dòng cho mỗi khung** thay vì rỗng, tức không dùng được để đọc nhanh. Đều dẫn tới cùng kết luận: đừng đọc, dùng biểu thức.

## 5. Chữ tiếng Việt trong filtergraph: dùng `textfile=` và `-/filter_complex`

Dấu phẩy và hai chấm trong câu làm vỡ parser của filtergraph, kể cả khi đã bọc nháy đơn.

**Đã kiểm:** `drawtext=...:text='Ba thứ: hồ sơ, tài chính'` gõ thẳng vào `-vf` báo `No option name near ' hồ sơ, tài chính'` và không ra tệp. Cách đúng chạy được: mỗi dòng chữ một tệp `.txt`, và đọc cả filtergraph từ tệp bằng `-/filter_complex`.

```bash
printf 'Ba thứ lãnh sự xét, và: hồ sơ' > d1.txt
cat > g.txt <<'EOF'
[0:v]drawtext=fontfile=font.ttf:textfile=d1.txt:fontsize=22:fontcolor=white:x=(w-text_w)/2:y=80:enable='between(t,0.5,2.5)':alpha='if(lt(t,1),(t-0.5)/0.5,1)'[v]
EOF
ffmpeg -i nen.mp4 -/filter_complex g.txt -map "[v]" -frames:v 90 dt.mp4
```

Hai điều đi kèm:

- Đường dẫn font kiểu `C:\Windows\...` có dấu hai chấm cũng phá filtergraph. Chạy ffmpeg với thư mục làm việc có sẵn tệp font và dùng đường dẫn tương đối (lệnh trên dùng `font.ttf`).
- Máy dựng có thể không có sẵn Be Vietnam Pro hay Newsreader. Cách khác: thay vì `drawtext`, khung chữ được dựng bằng HTML rồi chụp bằng Chrome headless thành PNG trong suốt, chữ trên video giống chữ trên web.

## 6. Các bẫy khác (từ ghi chép, chưa kiểm lại)

Mỗi bẫy dưới đây đã được ghi lúc dựng thật. Chưa chạy lại bài thử riêng.

| Bẫy | Cách đúng |
|---|---|
| `concat -c copy` nối nhiều mẩu làm đứng hình: dấu thời gian đứt, tệp khai 7 giây nhưng nội dung thật khoảng 2 giây, bộ lọc `fps` nhân bản khung cuối | mã hoá lại với `-fps_mode cfr`, rồi đếm khung thật bằng `-count_frames` |
| `-ss` đặt trước `-i` là tua thô theo keyframe, ra khung xám phẳng | tua thô tới trước điểm cần khoảng 1,5 giây, rồi tua tinh bằng `-ss` đặt sau `-i`. Cửa kiểm: độ bão hoà trung bình dưới 6 là cảnh xám |
| ảnh `-loop 1` thiếu `-t` làm ffmpeg chạy hàng giờ, tệp tạm vài GB. `overlay=shortest=1` không cứu khi cả hai nhánh đều là ảnh lặp | giới hạn mọi ảnh lặp và cả đầu ra bằng `-t` hoặc `-frames:v` |
| `alphamerge` ghép theo dấu thời gian: montage nối bằng copy làm vài khung lọt qua không có mặt nạ | ép `setpts=N/FPS/TB` cho cả ba luồng trước khi ghép |
| `zoompan` với `-loop 1 -t d -i anh.png`: mỗi khung vào lại nở ra `d=` khung, 33 giây thành 900 giây | đưa ảnh vào đúng một khung (`-i anh.png`, bỏ `-loop 1 -t`), để zoompan tự sinh |
| chiều cao khung cắt tính theo `ih*0.5344` làm hình bị nén dọc | tính theo `iw*9/16` |
| đọc `duration` của tệp ghép rồi tin | đếm khung thật |

## 7. Chuẩn nghiệm thu nhanh trước khi giao

1. Đếm khung và so với số cảnh nhân độ dài (mục 2).
2. Rút 3 khung quanh mốc của từng lớp phủ muộn (mục 1).
3. Dò chỗ lặng quá dài bằng RMS, không dựa vào cảm giác.
4. Soi khung xám phẳng ở đầu mỗi cảnh (mục 6).
5. Nghe bằng tai người. Máy chỉ đo được độ lớn, không nghe được nhạc hay giọng.
