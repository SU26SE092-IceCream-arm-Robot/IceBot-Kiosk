# Hướng dẫn cài đặt và thiết lập IceBot Kiosk trên tablet Windows

Tài liệu này dành cho nhân viên triển khai hoặc quản lý điểm bán khi cài đặt
IceBot Kiosk trên tablet Windows.

## 1. Chuẩn bị trước khi cài đặt

Đảm bảo tablet có:

- Windows 10 hoặc Windows 11 bản 64-bit.
- Kết nối Internet ổn định và truy cập được hệ thống IceBot.
- Quyền quản trị viên Windows để cài đặt phần mềm.
- Tài khoản Manager đang hoạt động và đã được gán đúng điểm bán hoặc kiosk.
- Tên hoặc mã kiosk của máy vật lý cần thiết lập.

Không chia sẻ mật khẩu Manager hoặc lưu mật khẩu trong tài liệu triển khai.

## 2. Cài đặt ứng dụng

1. Tải file `IceBot_Kiosk_<phiên-bản>.msi` từ trang phát hành chính thức.
2. Mở file MSI bằng tài khoản có quyền quản trị viên.
3. Đọc điều khoản sử dụng, chọn chấp nhận rồi bấm **Next**.
4. Giữ thư mục cài đặt mặc định hoặc chọn thư mục khác nếu đơn vị triển khai
   có yêu cầu.
5. Bấm **Install** và chờ quá trình cài đặt hoàn tất.
6. Mở **IceBot Kiosk** từ Desktop hoặc Start Menu.

Khi nâng cấp từ phiên bản cũ, chạy MSI phiên bản mới. Trình cài đặt sẽ thực
hiện nâng cấp ứng dụng hiện có.

## 3. Liên kết tablet với kiosk

Việc liên kết chỉ cần thực hiện ở lần cài đặt đầu tiên hoặc sau khi gỡ liên kết.

1. Tại màn hình **Đăng nhập Manager**, nhập email hoặc tên đăng nhập và mật
   khẩu của Manager phụ trách điểm bán.
2. Bấm **Đăng nhập và thiết lập**.
3. Nếu tài khoản chỉ quản lý một kiosk phù hợp, ứng dụng tự động liên kết với
   kiosk đó.
4. Nếu điểm bán có nhiều kiosk, chọn đúng **tên** và **mã kiosk** tương ứng với
   máy vật lý đang cài đặt, sau đó bấm **Xác nhận kiosk**.
5. Chờ ứng dụng hoàn tất đăng ký tablet và tải menu.

Sau khi thiết lập thành công, phiên Manager được thu hồi. Ứng dụng chỉ lưu định
danh tablet cần thiết trong bộ nhớ bảo mật của Windows để truy cập các chức năng
kiosk.

> **Lưu ý:** Không chọn thử một kiosk đang được tablet khác sử dụng. Thiết lập
> tablet mới cho cùng kiosk có thể thay thế đăng ký của tablet cũ, khiến tablet
> cũ không còn truy cập được chức năng runtime.

## 4. Kiểm tra sau khi thiết lập

Sau khi vào màn hình chính, kiểm tra:

- Menu hiển thị đúng các món đang được cấu hình và kích hoạt.
- Giá bán và hình ảnh món đúng với dữ liệu quản lý.
- Có thể chọn món và đi đến bước giỏ hàng.
- Máy làm kem hoặc thiết bị IoT của kiosk đang online.

Ứng dụng phân biệt hai trường hợp:

- **Menu hiện chưa có món:** kiosk không có món khả dụng trong menu.
- **Thiết bị đang offline:** máy làm kem hoặc thiết bị IoT chưa kết nối; kiosk
  tạm thời không thể nhận đơn. Bấm **Kiểm tra lại** sau khi khôi phục kết nối.

## 5. Gỡ liên kết hoặc chuyển tablet sang kiosk khác

1. Nhấn giữ nút **Cài đặt** ở góc trên bên phải màn hình menu.
2. Trong hộp thoại **Gỡ thiết lập kiosk?**, chọn **Gỡ liên kết**.
3. Ứng dụng xóa cấu hình kiosk và định danh tablet đã lưu trên máy, sau đó quay
   lại màn hình đăng nhập Manager.
4. Đăng nhập lại và chọn kiosk mới nếu cần.

Không gỡ liên kết khi đơn hàng vẫn đang được xử lý.

## 6. Xử lý sự cố thường gặp

### Đăng nhập thành công nhưng không thiết lập được

- Xác nhận tài khoản có quyền Manager.
- Kiểm tra Manager đã được gán đúng điểm bán hoặc kiosk.
- Kiểm tra điểm bán đã có kiosk đang hoạt động.
- Thử lại sau khi xác nhận kết nối Internet của tablet.

### Hiện “Thiết bị đang offline”

- Kiểm tra nguồn và kết nối mạng của máy làm kem hoặc thiết bị IceBot IoT.
- Đảm bảo dịch vụ IoT/edge đang chạy và gửi heartbeat lên hệ thống.
- Sau khi thiết bị online, bấm **Kiểm tra lại** để tải lại menu.
- Nếu thông báo vẫn còn, liên hệ bộ phận kỹ thuật và cung cấp tên/mã kiosk.

### Hiện “Menu hiện chưa có món”

- Kiểm tra menu của kiosk trên hệ thống quản lý.
- Đảm bảo menu và món đang ở trạng thái hoạt động, còn trong thời gian hiệu lực
  và được gán đúng tổ chức, điểm bán hoặc kiosk.
- Bấm **Tải lại menu** sau khi cập nhật dữ liệu.

### Không thể kết nối đến máy chủ

- Kiểm tra Internet trên tablet.
- Kiểm tra ngày, giờ và múi giờ Windows.
- Kiểm tra tường lửa hoặc mạng nội bộ có chặn địa chỉ hệ thống IceBot hay không.
- Thử đóng và mở lại ứng dụng.

## 7. Thông tin cần gửi khi yêu cầu hỗ trợ

Không gửi mật khẩu, token hoặc thông tin bí mật. Chỉ cung cấp:

- Tên và mã kiosk.
- Phiên bản IceBot Kiosk đang cài đặt.
- Thời điểm lỗi xảy ra.
- Ảnh chụp thông báo lỗi.
- Trạng thái mạng của tablet và thiết bị IoT.
