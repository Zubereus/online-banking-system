DELIMITER $$
 -- ============================================================
-- HÀM: TinhDuNoConLai
-- ============================================================
DROP FUNCTION IF EXISTS TinhDuNoConLai $$
 
CREATE FUNCTION TinhDuNoConLai(p_ma_khoan_vay VARCHAR(10))
RETURNS DECIMAL(15,2)
READS SQL DATA
BEGIN
 
    DECLARE v_tong_vay  DECIMAL(15,2) DEFAULT 0;
    DECLARE v_da_tra    DECIMAL(15,2) DEFAULT 0;
    DECLARE v_goc       DECIMAL(15,2);
    DECLARE v_done      INT DEFAULT 0;
 
    DECLARE cur CURSOR FOR
        SELECT So_tien_goc_tra
        FROM Thanh_toan_khoan_vay
        WHERE Ma_khoan_vay = p_ma_khoan_vay
          AND Ngay_tra_thuc_te IS NOT NULL;
 
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
 
    -- Validate tham số
 
    IF p_ma_khoan_vay IS NULL OR TRIM(p_ma_khoan_vay) = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: Ma khoan vay khong hop le';
    END IF;
 
    -- Lấy tổng khoản vay
 
    SELECT Khoan_vay INTO v_tong_vay
    FROM Khoan_vay
    WHERE Ma_khoan_vay = p_ma_khoan_vay;
 
    -- Không tìm thấy khoản vay
    IF v_tong_vay IS NULL OR v_tong_vay = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: Khoan vay khong ton tai';
    END IF;
 
    -- Reset v_done
    SET v_done = 0;
 
    -- Duyệt cursor tính tổng đã trả
 
    OPEN cur;
 
    doc_loop: LOOP
        FETCH cur INTO v_goc;
        IF v_done THEN
            LEAVE doc_loop;
        END IF;
        SET v_da_tra = v_da_tra + v_goc;
    END LOOP doc_loop;
 
    CLOSE cur;
 
    -- Trả về dư nợ còn lại
 
    RETURN v_tong_vay - v_da_tra;
END $$

-- ============================================================
-- CÂU LỆNH MINH HỌA KHI BÁO CÁO
-- ============================================================
 
-- Dư nợ còn lại của khoản vay KV0000
-- SELECT TinhDuNoConLai('KV0000') AS Du_no_con_lai;
 
-- Xem toàn bộ khoản vay và dư nợ còn lại
-- SELECT
--     Ma_khoan_vay,
--     Khoan_vay           AS Tong_vay,
--     TinhDuNoConLai(Ma_khoan_vay) AS Du_no_con_lai,
--     Khoan_vay - TinhDuNoConLai(Ma_khoan_vay) AS Da_tra,
--     Trang_thai
-- FROM Khoan_vay
-- ORDER BY Ma_khoan_vay;
 
-- Lỗi: khoản vay không tồn tại
-- SELECT TinhDuNoConLai('KV9999') AS Ket_qua;
 
-- Lỗi: tham số rỗng (Không hợp lệ)
-- SELECT TinhDuNoConLai('') AS Ket_qua;
 
-- Lỗi: tham số NULL (Không hợp lệ)
-- SELECT TinhDuNoConLai(NULL) AS Ket_qua;

-- ============================================================
-- HÀM: TinhTongPhiGiaoDich
-- ============================================================
 
DROP FUNCTION IF EXISTS TinhTongPhiGiaoDich $$
 
CREATE FUNCTION TinhTongPhiGiaoDich(
    p_so_tai_khoan  VARCHAR(10),
    p_thang         INT,        -- 1-12, hoặc NULL để tính cả năm
    p_nam           INT
)
RETURNS DECIMAL(15,2)
READS SQL DATA
BEGIN
    -- Biến cho cursor

    DECLARE v_phan_loai     ENUM('Trans','Bill','Loan');
    DECLARE v_phi           DECIMAL(15,2);
    DECLARE v_done          INT DEFAULT 0;
 
    -- Biến tích lũy kết quả
    DECLARE v_tong_phi_trans    DECIMAL(15,2) DEFAULT 0;
    DECLARE v_tong_phi_bill     DECIMAL(15,2) DEFAULT 0;
    DECLARE v_tong_phi_loan     DECIMAL(15,2) DEFAULT 0; 
    DECLARE v_tong_phi          DECIMAL(15,2) DEFAULT 0;
    -- Cursor: duyệt giao dịch GỬI của tài khoản trong tháng
    DECLARE cur CURSOR FOR
        SELECT Phan_loai, Phi_chuyen_tien
        FROM Giao_dich
        WHERE So_tai_khoan_gui = p_so_tai_khoan
          AND YEAR(Thoi_gian)  = p_nam
          AND (p_thang IS NULL OR MONTH(Thoi_gian) = p_thang);
 
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
 
    -- VALIDATE THAM SỐ ĐẦU VÀO
    -- Kiểm tra tài khoản không được NULL/rỗng
    IF p_so_tai_khoan IS NULL OR TRIM(p_so_tai_khoan) = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: So tai khoan khong hop le';
    END IF;
 
    -- Kiểm tra năm hợp lệ
    IF p_nam IS NULL OR p_nam > YEAR(CURDATE()) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: Nam khong hop le';
    END IF;
 
    -- Kiểm tra tháng hợp lệ (nếu có truyền vào)
    IF p_thang IS NOT NULL AND (p_thang < 1 OR p_thang > 12) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: Thang khong hop le';
    END IF;
 
    -- Kiểm tra tài khoản có tồn tại không
    IF NOT EXISTS (
        SELECT 1 FROM Tai_khoan_giao_dich
        WHERE So_tai_khoan = p_so_tai_khoan
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loi: Tai khoan khong ton tai';
    END IF;
 
    -- Duyệt từng giao dịch qua cursor
 
    OPEN cur;
 
    duyet_giao_dich: LOOP
        FETCH cur INTO v_phan_loai, v_phi;
        -- Thoát khi hết dữ liệu
        IF v_done THEN
            LEAVE duyet_giao_dich;
        END IF;
        
        -- Phân loại để tính phí khác nhau cho từng loại GD
        IF v_phan_loai = 'Trans' THEN
            -- Chuyển khoản: tính phi_chuyen_tien thực tế
            SET v_tong_phi_trans = v_tong_phi_trans + IFNULL(v_phi,0);
 
        ELSEIF v_phan_loai = 'Bill' THEN
            -- Thanh toán hóa đơn: miễn phí
            SET v_tong_phi_bill = v_tong_phi_bill + 0;
 
        ELSEIF v_phan_loai = 'Loan' THEN
            -- Trả khoản vay: miễn phí
            SET v_tong_phi_loan = v_tong_phi_loan + 0;
        END IF;
 
    END LOOP duyet_giao_dich;
 
    CLOSE cur;
    
	-- Tính kết quả
    SET v_tong_phi = v_tong_phi_trans + v_tong_phi_bill + v_tong_phi_loan;
 
    RETURN v_tong_phi;
END $$
 
DELIMITER ;
 
 
-- ============================================================
-- CÂU LỆNH MINH HỌA KHI BÁO CÁO
-- ============================================================
 
-- Tổng phí tháng 4/2026 của tài khoản '1860636405'
-- SELECT TinhTongPhiGiaoDich('1860636405', 4, 2026) AS Tong_phi_thang_4;
 
-- Tổng phí cả năm 2026 của tài khoản '1860636405'
-- SELECT TinhTongPhiGiaoDich('1860636405', NULL, 2026) AS Tong_phi_nam_2026;
 
-- So sánh nhiều tài khoản cùng lúc
-- SELECT
--     So_tai_khoan,
--     TinhTongPhiGiaoDich(So_tai_khoan, 4, 2026) AS Phi_thang_4_2026
-- FROM Tai_khoan_giao_dich
-- WHERE Loai_tk = 'Noi_bo'
-- ORDER BY Phi_thang_4_2026 DESC;
 
-- Lỗi: tháng không hợp lệ 
-- SELECT TinhTongPhiGiaoDich('0798711576', 13, 2026) AS Ket_qua;
 
-- Lỗi: vượt thời gian
-- SELECT TinhTongPhiGiaoDich('0798711576', 4, 2100) AS Ket_qua;
 
-- Lỗi: tài khoản không tồn tại
-- SELECT TinhTongPhiGiaoDich('9999999999', 4, 2026) AS Ket_qua;
 
-- Lỗi: tài khoản rỗng 
-- SELECT TinhTongPhiGiaoDich('', 4, 2026) AS Ket_qua;
 