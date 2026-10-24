# Nguyên tắc dựng

## Chia khâu, mỗi khâu một sản phẩm kiểm được
Nguồn/tư liệu → kịch bản → giọng → mốc thời gian từng chữ → hình → dựng → cổng kiểm → đăng/hẹn. Mỗi khâu ghi ra tệp riêng; khâu sau chỉ đọc tệp của khâu trước. Lỗi ở đâu sửa ở đó, không dựng lại từ đầu.

## Tổ chức công việc
1. **Một tập một thư mục**, có `goi.json` mô tả cảnh, hình, mốc. Cảnh nào dùng clip nào phải ghi, kèm lý do chọn.
2. **Cấu hình ra ngoài mã:** đường dẫn, id tài khoản, khoá nằm trong `.env`, có `.env.example`. Không commit `.env`.
3. **Lệnh dài chạy tách tiến trình** rồi đọc log, vì một lệnh công cụ có thể bị cắt giữa chừng. Tệp ra đứng im lâu mà tiến trình không thoát là dấu hiệu treo: kiểm tệp bằng ffprobe, diệt, chạy lại một lần.
4. **Chạy nháp trước, ghi thật sau.** Script đụng tài khoản thật phải có chế độ chỉ in việc sẽ làm.
5. **Tệp dấu "đã đăng"** chặn đăng trùng, nhưng sự thật phải hỏi thẳng nền tảng, đừng đếm tệp dấu.
6. **Đăng lỗi một kênh thì chạy lại đúng kênh đó**, không đăng lại cả bộ.
7. **Dọn gói khi xong:** xoá tệp trung gian nặng, giữ sản phẩm, lời, caption, json.
8. **Kiểm trùng trước khi làm:** nguồn đã có video, đang hẹn, hoặc đã ra định dạng khác. Một nguồn một định dạng.
9. **Dựng trước cho ngày mai:** kênh không hẹn giờ được (đăng ngay) thì để đến đúng ngày. Giờ hẹn phải sau giờ nguồn lên site, nếu không caption trỏ vào link chưa sống.
10. **Video dài hơn khung thì tách phần có lời dẫn**, đừng ép tăng tốc.

## Kỹ thuật cần nhớ
- Chấm khớp giọng bằng `difflib.SequenceMatcher(autojunk=False)`. Mặc định bật autojunk làm chuỗi dài bị chấm sai bét và báo giọng hỏng oan.
- Lớp chữ/ảnh trong suốt xuất `.mov` codec `qtrle`; `.mp4` không chứa kênh trong suốt.
- Chrome tự động: mỗi luồng song song một hồ sơ riêng, mở tab nền, không cướp cửa sổ người dùng.
- Tải stock: đọc URL thật từ trang video qua trình duyệt, đừng đoán tên tệp.
- Python 3.11: không lồng cùng loại nháy trong f-string.
- Chi tiết ffmpeg: `bay-ffmpeg.md`.
