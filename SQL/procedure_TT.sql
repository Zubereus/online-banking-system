USE banking;
DELIMITER $$

-- ============================================================
-- 1. THỦ TỤC THÊM KHOẢN VAY (INSERT)
-- ============================================================
DROP PROCEDURE IF EXISTS sp_ThemKhoanVay $$
CREATE PROCEDURE sp_ThemKhoanVay(
    IN p_Ma_khoan_vay    VARCHAR(10),   -- Mã khoản vay (do QTV tự sinh, dạng KV + số)
    IN p_Lai_suat        DECIMAL(4,4),  -- Lãi suất (0.00 < x <= 0.20)
    IN p_Khoan_vay       DECIMAL(15,2), -- Số tiền vay
    IN p_Thoi_han_vay    INT,           -- Thời hạn vay (tháng, > 0)
    IN p_Ky_han_tra_goc  INT,           -- Kỳ hạn trả gốc (tháng, 1-36, chia hết thời hạn)
    IN p_So_tai_khoan    VARCHAR(10),   -- Tài khoản đăng ký vay
    IN p_Ma_so           VARCHAR(20),   -- Mã quản trị viên phê duyệt
    IN p_Ngay_tao        DATE           -- Ngày tạo khoản vay
)
BEGIN
    DECLARE v_trang_thai_tk  VARCHAR(10);
    DECLARE v_cccd_nd        VARCHAR(12);
    DECLARE v_qtv_exists     INT DEFAULT 0;
    DECLARE v_ma_ton_tai     INT DEFAULT 0;

    -- Kiểm tra mã khoản vay không được trùng
    SELECT COUNT(*) INTO v_ma_ton_tai
    FROM Khoan_vay WHERE Ma_khoan_vay = p_Ma_khoan_vay;

    IF v_ma_ton_tai > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: Ma khoản vay da ton tai trong he thong.';
    END IF;

    -- Kiểm tra mã khoản vay đúng định dạng (bắt đầu bằng KV)
    IF p_Ma_khoan_vay NOT REGEXP '^KV[0-9]{4}$' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi dinh dang: Ma khoan vay phai co dang KVxxxx (KV + 4 chu so).';
    END IF;

    -- Kiểm tra lãi suất trong khoảng hợp lệ (0 < lãi suất <= 0.20)
    IF p_Lai_suat <= 0.00 OR p_Lai_suat > 0.20 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: Lai suat phai lon hon 0% va khong vuot qua 20%/nam.';
    END IF;

    -- Kiểm tra số tiền vay phải dương
    IF p_Khoan_vay <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: So tien vay phai lon hon 0 dong.';
    END IF;

    -- Kiểm tra thời hạn vay hợp lệ
    IF p_Thoi_han_vay <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: Thoi han vay phai lon hon 0 thang.';
    END IF;

    -- Kiểm tra kỳ hạn trả gốc hợp lệ (1-36 tháng)
    IF p_Ky_han_tra_goc <= 0 OR p_Ky_han_tra_goc > 36 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: Ky han tra goc phai tu 1 den 36 thang.';
    END IF;

    -- Kỳ hạn trả gốc phải chia hết thời hạn vay
    IF (p_Thoi_han_vay MOD p_Ky_han_tra_goc) <> 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: Thoi han vay phai chia het cho ky han tra goc (de tao deu cac ky tra).';
    END IF;

    -- Kiểm tra tài khoản vay tồn tại và đang ACTIVE
    SELECT Trang_thai INTO v_trang_thai_tk
    FROM Tai_khoan
    WHERE So_tai_khoan = p_So_tai_khoan;

    IF v_trang_thai_tk IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: So tai khoan dang ky vay khong ton tai.';
    END IF;

    IF v_trang_thai_tk = 'DEACTIVE' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: Tai khoan dang bi khoa (DEACTIVE), khong the dang ky vay.';
    END IF;

    IF v_trang_thai_tk = 'REMOVED' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: Tai khoan da bi xoa (REMOVED), khong the dang ky vay.';
    END IF;

    -- Kiểm tra tài khoản đăng ký vay phải thuộc về một Nguoi_dung
    SELECT nd.CCCD INTO v_cccd_nd
    FROM Tai_khoan tk
    JOIN Nguoi_dung nd ON tk.CCCD = nd.CCCD
    WHERE tk.So_tai_khoan = p_So_tai_khoan;
    
    IF v_cccd_nd IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: Chi nguoi dung (khach hang) moi duoc dang ky khoan vay.';
    END IF;

    -- Kiểm tra quản trị viên phê duyệt tồn tại
    SELECT COUNT(*) INTO v_qtv_exists
    FROM Quan_tri_vien WHERE Ma_so = p_Ma_so;

    IF v_qtv_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: Ma quan tri vien phe duyet khong ton tai.';
    END IF;

    -- Kiểm tra ngày tạo không được ở tương lai
    IF p_Ngay_tao > CURDATE() THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: Ngay tao khoan vay khong duoc la ngay trong tuong lai.';
    END IF;

    -- Kiểm tra tài khoản không có khoản vay đang hoạt động / quá hạn chưa xử lý
    IF EXISTS (
        SELECT 1 FROM Khoan_vay
        WHERE So_tai_khoan = p_So_tai_khoan
          AND Trang_thai IN ('Hoat_dong', 'Qua_han')
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: Tai khoan con khoan vay dang hoat dong hoac qua han, khong the tao khoan vay moi.';
    END IF;

    -- Tất cả kiểm tra hợp lệ -> thực hiện INSERT
    INSERT INTO Khoan_vay (
        Ma_khoan_vay, Lai_suat, Khoan_vay,
        Thoi_han_vay, Ky_han_tra_goc,
        So_tai_khoan, Ma_so, Trang_thai, Ngay_tao_khoan_vay
    ) VALUES (
        p_Ma_khoan_vay, p_Lai_suat, p_Khoan_vay,
        p_Thoi_han_vay, p_Ky_han_tra_goc,
        p_So_tai_khoan, p_Ma_so, 'Hoat_dong', p_Ngay_tao
    );

    SELECT CONCAT('Thanh cong: Da tao khoan vay ', p_Ma_khoan_vay,
                  ' voi so tien ', FORMAT(p_Khoan_vay, 0), ' VND',
                  ', thoi han ', p_Thoi_han_vay, ' thang.') AS Ket_qua;
END $$


-- ============================================================
-- 2. THỦ TỤC SỬA KHOẢN VAY (UPDATE)
-- ============================================================
DROP PROCEDURE IF EXISTS sp_SuaKhoanVay $$
CREATE PROCEDURE sp_SuaKhoanVay(
    IN p_Ma_khoan_vay    VARCHAR(10),
    IN p_Lai_suat        DECIMAL(4,4),
    IN p_Thoi_han_vay    INT,
    IN p_Ky_han_tra_goc  INT,
    IN p_Trang_thai      ENUM('Hoat_dong','Qua_han','Da_thanh_toan'),
    IN p_Ma_so           VARCHAR(20)   -- QTV thực hiện sửa (để ghi log / kiểm tra quyền)
)
BEGIN
    DECLARE v_trang_thai_hien    VARCHAR(20);
    DECLARE v_so_luot_da_tra     INT DEFAULT 0;
    DECLARE v_qtv_exists         INT DEFAULT 0;
    DECLARE v_tong_goc_da_tra    DECIMAL(15,2) DEFAULT 0;
    DECLARE v_khoan_vay_goc      DECIMAL(15,2);

    -- Kiểm tra khoản vay tồn tại
    SELECT Trang_thai, Khoan_vay
    INTO v_trang_thai_hien, v_khoan_vay_goc
    FROM Khoan_vay
    WHERE Ma_khoan_vay = p_Ma_khoan_vay;

    IF v_trang_thai_hien IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: Ma khoan vay khong ton tai, khong the cap nhat.';
    END IF;

    -- Không cho sửa khoản vay đã thanh toán xong
    IF v_trang_thai_hien = 'Da_thanh_toan' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: Khoan vay da tat toan, khong the chinh sua them.';
    END IF;

    -- Kiểm tra QTV có quyền
    SELECT COUNT(*) INTO v_qtv_exists
    FROM Quan_tri_vien WHERE Ma_so = p_Ma_so;

    IF v_qtv_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: Ma quan tri vien khong ton tai, khong co quyen cap nhat.';
    END IF;

    -- Kiểm tra lãi suất mới hợp lệ (nếu được cung cấp)
    IF p_Lai_suat IS NOT NULL THEN
        IF p_Lai_suat <= 0.00 OR p_Lai_suat > 0.20 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Loi: Lai suat moi phai lon hon 0% va khong vuot qua 20%/nam.';
        END IF;

        -- Không cho đổi lãi suất nếu đã có lịch sử thanh toán
        SELECT COUNT(*) INTO v_so_luot_da_tra
        FROM Thanh_toan_khoan_vay
        WHERE Ma_khoan_vay = p_Ma_khoan_vay
          AND Ngay_tra_thuc_te IS NOT NULL;

        IF v_so_luot_da_tra > 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Loi: Khoan vay da co lich su tra tien, khong the thay doi lai suat.';
        END IF;
    END IF;

    -- Kiểm tra thời hạn và kỳ hạn trả gốc mới
    IF p_Thoi_han_vay IS NOT NULL AND p_Thoi_han_vay <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: Thoi han vay moi phai lon hon 0 thang.';
    END IF;

    IF p_Ky_han_tra_goc IS NOT NULL THEN
        IF p_Ky_han_tra_goc <= 0 OR p_Ky_han_tra_goc > 36 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Loi: Ky han tra goc moi phai tu 1 den 36 thang.';
        END IF;
    END IF;

    -- Kiểm tra tính chia hết sau khi cả hai được cung cấp
    IF p_Thoi_han_vay IS NOT NULL AND p_Ky_han_tra_goc IS NOT NULL THEN
        IF (p_Thoi_han_vay MOD p_Ky_han_tra_goc) <> 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Loi: Thoi han vay moi phai chia het cho ky han tra goc moi.';
        END IF;
    END IF;

    -- Không cho phép chuyển về Hoat_dong nếu đang Qua_han
    IF v_trang_thai_hien = 'Qua_han' AND p_Trang_thai = 'Da_thanh_toan' THEN
        -- Cho phép chỉ khi tất cả nợ quá hạn đã được thanh toán
        SELECT IFNULL(SUM(So_tien_goc_tra), 0) INTO v_tong_goc_da_tra
        FROM Thanh_toan_khoan_vay
        WHERE Ma_khoan_vay = p_Ma_khoan_vay;

        IF v_tong_goc_da_tra < v_khoan_vay_goc THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Loi: Khoan vay dang qua han, chi co the chuyen sang Da_thanh_toan sau khi tat toan.';
        END IF;
    END IF;

    -- Tất cả kiểm tra hợp lệ -> thực hiện UPDATE (chỉ cột được cung cấp)
    UPDATE Khoan_vay
    SET
        Lai_suat       = COALESCE(p_Lai_suat,       Lai_suat),
        Thoi_han_vay   = COALESCE(p_Thoi_han_vay,   Thoi_han_vay),
        Ky_han_tra_goc = COALESCE(p_Ky_han_tra_goc, Ky_han_tra_goc),
        Trang_thai     = COALESCE(p_Trang_thai,      Trang_thai)
    WHERE Ma_khoan_vay = p_Ma_khoan_vay;

    SELECT CONCAT('Thanh cong: Da cap nhat khoan vay ', p_Ma_khoan_vay, '.') AS Ket_qua;
END $$


-- ============================================================
-- 3. THỦ TỤC XÓA KHOẢN VAY (DELETE)
-- ============================================================
-- Mục đích & lý do cần xóa:
--   Trong nghiệp vụ ngân hàng, khoản vay thông thường KHÔNG
--   được xóa vật lý khỏi hệ thống vì lý do kiểm toán & pháp lý.
--   Tuy nhiên, có MỘT trường hợp hợp lệ cần xóa thật sự:
--   → Khoản vay được tạo do LỖI HỆ THỐNG hoặc NHẬP SAI và
--     CHƯA phát sinh bất kỳ giao dịch giải ngân hay thanh toán
--     nào, VÀ còn trong vòng 24 giờ kể từ lúc tạo.
--   Khi nào KHÔNG được xóa:
--   - Khoản vay đang Hoat_dong và đã có lịch sử thanh toán
--   - Khoản vay đang Qua_han
--   - Khoản vay đã Da_thanh_toan
--   - Khoản vay đã quá 24 giờ kể từ ngày tạo
--   Trong các trường hợp không thể xóa, QTV phải dùng
--   sp_SuaKhoanVay để chuyển trạng thái thay thế.
-- ============================================================
DROP PROCEDURE IF EXISTS sp_XoaKhoanVay $$
CREATE PROCEDURE sp_XoaKhoanVay(
    IN p_Ma_khoan_vay  VARCHAR(10),
    IN p_Ma_so         VARCHAR(20),   -- Mã QTV yêu cầu xóa (phải cấp độ 3)
    IN p_Ly_do         TEXT           -- Lý do xóa bắt buộc ghi rõ
)
BEGIN
    DECLARE v_trang_thai         VARCHAR(20);
    DECLARE v_ngay_tao           DATE;
    DECLARE v_so_thanh_toan      INT DEFAULT 0;
    DECLARE v_cap_do             VARCHAR(1);
    DECLARE v_qtv_exists         INT DEFAULT 0;

    -- Kiểm tra khoản vay tồn tại
    SELECT Trang_thai, Ngay_tao_khoan_vay
    INTO v_trang_thai, v_ngay_tao
    FROM Khoan_vay
    WHERE Ma_khoan_vay = p_Ma_khoan_vay;

    IF v_trang_thai IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: Ma khoan vay khong ton tai, khong co gi de xoa.';
    END IF;

    -- Kiểm tra QTV tồn tại và đủ quyền (phải cấp độ 3 — cao nhất)
    SELECT COUNT(*), MAX(Cap_do_truy_cap) INTO v_qtv_exists, v_cap_do
    FROM Quan_tri_vien WHERE Ma_so = p_Ma_so;

    IF v_qtv_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: Ma quan tri vien khong ton tai.';
    END IF;

    IF v_cap_do <> '3' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: Chi quan tri vien cap do 3 (cap cao nhat) moi duoc phep xoa khoan vay.';
    END IF;

    -- Lý do xóa không được để trống
    IF p_Ly_do IS NULL OR TRIM(p_Ly_do) = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: Phai ghi ro ly do xoa khoan vay de luu lich su kiem toan.';
    END IF;

    -- Không cho xóa khoản vay đang quá hạn
    IF v_trang_thai = 'Qua_han' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: Khoan vay dang qua han, khong duoc phep xoa. Phai xu ly no truoc.';
    END IF;

    -- Không cho xóa khoản vay đã tất toán (cần giữ cho kiểm toán)
    IF v_trang_thai = 'Da_thanh_toan' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: Khoan vay da tat toan. Khong xoa lich su vi ly do kiem toan va phap ly.';
    END IF;

    -- Kiểm tra chưa có bất kỳ lần thanh toán nào
    SELECT COUNT(*) INTO v_so_thanh_toan
    FROM Thanh_toan_khoan_vay
    WHERE Ma_khoan_vay = p_Ma_khoan_vay;

    IF v_so_thanh_toan > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: Khoan vay da co lich su thanh toan, khong the xoa. Hay doi trang thai sang Da_thanh_toan thay the.';
    END IF;

    -- Chỉ cho xóa trong vòng 24 giờ kể từ ngày tạo (ngăn xóa nhầm dữ liệu cũ)
    IF DATEDIFF(CURDATE(), v_ngay_tao) > 1 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: Chi duoc xoa khoan vay trong vong 24 gio sau khi tao (tranh xoa nham du lieu lau dai). Hay lien he cap tren neu can.';
    END IF;

    -- Tất cả kiểm tra hợp lệ => Thực hiện DELETE
    DELETE FROM Khoan_vay WHERE Ma_khoan_vay = p_Ma_khoan_vay;

    SELECT CONCAT(
        'Thanh cong: Da xoa khoan vay ', p_Ma_khoan_vay,
        '. Ly do: ', p_Ly_do,
        '. Thuc hien boi QTV: ', p_Ma_so
    ) AS Ket_qua;
END $$

DELIMITER ;

-- ============================================================
-- VÍ DỤ GỌI THỦ TỤC
-- ============================================================

-- === INSERT: Tạo khoản vay hợp lệ ===
-- CALL sp_ThemKhoanVay(
--     'KV00000001',   -- Mã khoản vay
--     0.08,           -- Lãi suất 8%/năm
--     50000000.00,    -- Vay 50 triệu
--     12,             -- 12 tháng
--     3,              -- Trả gốc mỗi 3 tháng (12 chia hết 3 ✓)
--     '0318398092',   -- Số tài khoản
--     '934057',       -- Mã QTV phê duyệt
--     CURDATE()
-- );

-- INSERT: Lỗi — lãi suất vượt 20% 
--  CALL sp_ThemKhoanVay('KV00000002', 0.25, 50000000, 12, 3, '0000000001', '387177', CURDATE());
-- => Loi: Lai suat phai lon hon 0% va khong vuot qua 20%/nam.

-- INSERT: Lỗi — kỳ hạn không chia hết thời hạn 
-- CALL sp_ThemKhoanVay('KV00000003', 0.08, 50000000, 12, 5, '0000000001', '387177', CURDATE());
-- => Loi: Thoi han vay phai chia het cho ky han tra goc.

-- UPDATE: Cập nhật trạng thái sang quá hạn
-- CALL sp_SuaKhoanVay('KV00000001', NULL, NULL, NULL, 'Da_thanh_toan', '934057');

-- UPDATE: Lỗi — sửa lãi suất khi đã có lịch sử trả
-- CALL sp_SuaKhoanVay('KV00000001', 0.10, NULL, NULL, NULL, '934057');
-- => Loi: Khoan vay da co lich su tra tien, khong the thay doi lai suat.

-- DELETE: Xóa khoản vay nhập nhầm trong ngày (QTV cấp 3)
-- CALL sp_XoaKhoanVay('KV00000001', '934057', 'Nhap sai so tai khoan, can xoa va tao lai.');

-- DELETE: Lỗi — QTV không đủ quyền
-- CALL sp_XoaKhoanVay('KV00000001', '099548', 'Test xoa');
-- => Loi: Chi quan tri vien cap do 3 moi duoc phep xoa khoan vay.
DELIMITER $$

DROP PROCEDURE IF EXISTS LietKeGiaoDichTaiKhoan $$

CREATE PROCEDURE LietKeGiaoDichTaiKhoan(
    IN p_so_tai_khoan VARCHAR(20),
    IN p_ngay_bat_dau DATETIME,
    IN p_ngay_ket_thuc DATETIME
)
BEGIN
    -- Truy vấn từ 2 bảng: Giao_dich và Tai_khoan
    SELECT 
        gd.Ma_giao_dich, 
        gd.Thoi_gian, 
        gd.So_tien, 
        gd.Phan_loai,
        tk.Ten_khach_hang AS Ten_nguoi_gui
    FROM Giao_dich gd
    JOIN Tai_khoan tk ON gd.So_tai_khoan_gui = tk.So_tai_khoan
    -- Tham số đầu vào nằm trong mệnh đề WHERE
    WHERE (gd.So_tai_khoan_gui = p_so_tai_khoan OR gd.So_tai_khoan_nhan = p_so_tai_khoan)
      AND gd.Thoi_gian BETWEEN p_ngay_bat_dau AND p_ngay_ket_thuc
    -- Mệnh đề ORDER BY
    ORDER BY gd.Thoi_gian DESC;
END $$

DELIMITER ;
DELIMITER $$

DROP PROCEDURE IF EXISTS ThongKeDuNoKhoanVay $$

CREATE PROCEDURE ThongKeDuNoKhoanVay(
    IN p_trang_thai VARCHAR(20),
    IN p_tong_da_tra_min DECIMAL(15,2)
)
BEGIN
    -- Truy vấn có Aggregate function (SUM), Group By, Having, Where và Order By
    -- Liên kết 2 bảng: Khoan_vay và Thanh_toan_khoan_vay
    SELECT 
        kv.Ma_khoan_vay,
        kv.So_tai_khoan,
        kv.Khoan_vay AS Tong_von_vay,
        SUM(tt.So_tien_goc_tra) AS Tong_goc_da_tra,
        (kv.Khoan_vay - SUM(tt.So_tien_goc_tra)) AS Du_no_goc_con_lai
    FROM Khoan_vay kv
    LEFT JOIN Thanh_toan_khoan_vay tt ON kv.Ma_khoan_vay = tt.Ma_khoan_vay
    -- Tham số đầu vào trong mệnh đề WHERE
    WHERE kv.Trang_thai = p_trang_thai
      AND tt.Ngay_tra_thuc_te IS NOT NULL
    GROUP BY kv.Ma_khoan_vay, kv.So_tai_khoan, kv.Khoan_vay
    -- Tham số đầu vào trong mệnh đề HAVING
    HAVING SUM(tt.So_tien_goc_tra) >= p_tong_da_tra_min
    -- Mệnh đề ORDER BY
    ORDER BY Du_no_goc_con_lai DESC;
END $$

-- ============================================================
-- 5. THỦ TỤC THÊM GIAO DỊCH (ThemGiaoDich)
-- ============================================================
DROP PROCEDURE IF EXISTS ThemGiaoDich $$
CREATE PROCEDURE ThemGiaoDich(
    IN p_ma_giao_dich         VARCHAR(10),   -- Mã giao dịch
    IN p_so_tai_khoan_gui     VARCHAR(15),   -- Tài khoản gửi tiền
    IN p_so_tai_khoan_nhan    VARCHAR(15),   -- Tài khoản nhận tiền
    IN p_so_tien              DECIMAL(15,2), -- Số tiền chuyển
    IN p_phi_chuyen_tien      DECIMAL(15,2), -- Phí chuyển tiền
    IN p_phan_loai            VARCHAR(10),   -- Loại giao dịch (Trans, Bill, Loan)
    IN p_ma_hoa_don           VARCHAR(10),   -- Mã hóa đơn (cho Bill transactions)
    IN p_ma_thanh_toan_kv     VARCHAR(10),   -- Mã thanh toán khoản vay (cho Loan transactions)
    IN p_ma_khoan_vay         VARCHAR(10)    -- Mã khoản vay (cho Loan transactions)
)
BEGIN
    DECLARE v_exists INT DEFAULT 0;
    
    -- Kiểm tra giao dịch không bị trùng
    SELECT COUNT(*) INTO v_exists
    FROM Giao_dich
    WHERE Ma_giao_dich = p_ma_giao_dich;
    
    IF v_exists > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: Ma giao dich da ton tai trong he thong.';
    END IF;
    
    -- Chèn giao dịch vào bảng Giao_dich
    INSERT INTO Giao_dich (
        Ma_giao_dich,
        So_tai_khoan_gui,
        So_tai_khoan_nhan,
        So_tien,
        Phi_chuyen_tien,
        Thoi_gian,
        Phan_loai
    ) VALUES (
        p_ma_giao_dich,
        p_so_tai_khoan_gui,
        p_so_tai_khoan_nhan,
        p_so_tien,
        p_phi_chuyen_tien,
        NOW(),
        p_phan_loai
    );
    
    -- Nếu là thanh toán hóa đơn, liên kết với Hoa_don
    IF p_phan_loai = 'Bill' AND p_ma_hoa_don IS NOT NULL THEN
        UPDATE Hoa_don
        SET Ma_giao_dich = p_ma_giao_dich
        WHERE Ma_hoa_don = p_ma_hoa_don;
    END IF;
    
    -- Nếu là thanh toán khoản vay, liên kết với Thanh_toan_khoan_vay
    IF p_phan_loai = 'Loan' AND p_ma_thanh_toan_kv IS NOT NULL AND p_ma_khoan_vay IS NOT NULL THEN
        UPDATE Thanh_toan_khoan_vay
        SET Ma_giao_dich = p_ma_giao_dich,
            Ngay_tra_thuc_te = CURDATE()
        WHERE Ma_thanh_toan = p_ma_thanh_toan_kv
          AND Ma_khoan_vay = p_ma_khoan_vay;
    END IF;
    
END $$

DELIMITER ;


-- Xem các giao dịch chuyển khoản, thanh toán hóa đơn hoặc trả nợ của tài khoản 1860636405
-- CALL LietKeGiaoDichTaiKhoan('1860636405', '2026-04-25 00:00:00', '2026-05-02 23:59:59');


-- Thống kê dư nợ cho các khoản vay nợ xấu (quá hạn) đã trả gốc trên 50 triệu
-- CALL ThongKeDuNoKhoanVay('Qua_han', 50000000.00);

-- Thêm ThemGiaoDich procedure using direct execution in app.py
