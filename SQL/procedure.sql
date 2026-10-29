-- =========================== Tao tai khoan nguoi dung ==========================

DELIMITER $$

DROP PROCEDURE IF EXISTS tao_tai_khoan_dang_nhap$$
CREATE PROCEDURE tao_tai_khoan_dang_nhap (
    IN t_Ho VARCHAR(50),
    IN t_Ten_lot VARCHAR(50),
    IN t_Ten VARCHAR(50),
    IN t_CCCD VARCHAR(12),
    IN t_Gioi_tinh VARCHAR(10),
    IN t_Quoc_tich VARCHAR(50),
    IN t_Ngay_sinh DATE,
    IN t_Sdt VARCHAR(10),
    IN t_Ten_dang_nhap VARCHAR(50),
    IN t_Mat_khau VARCHAR(255)
)
BEGIN
    DECLARE t_So_tk VARCHAR(50);
    DECLARE t_Ma_so VARCHAR(50);

    INSERT INTO Nguoi VALUES (
        t_CCCD, t_Ho, t_Ten_lot, t_Ten,
        t_Quoc_tich, t_Gioi_tinh, t_Ngay_sinh
    );

    INSERT INTO Nguoi_dung VALUES (t_CCCD);
    INSERT INTO So_dien_thoai VALUES (t_CCCD, t_Sdt);

    SET t_So_tk = CONCAT('TK', FLOOR(RAND()*100000000));

    SELECT Ma_so INTO t_Ma_so
    FROM Quan_tri_vien
    ORDER BY RAND() LIMIT 1;

    INSERT INTO Tai_khoan VALUES (
        t_So_tk,
        CONCAT(t_Ho,' ',t_Ten_lot,' ',t_Ten),
        t_Ten_dang_nhap,
        t_Mat_khau,
        t_CCCD,
        'ACTIVE',
        t_Ma_so
    );

    INSERT INTO Tai_khoan_thanh_toan
    (So_tai_khoan, Han_muc, So_du)
    VALUES (
        t_So_tk,
        1000000000,
        0
    );
END$$

-- =========================== Chuyen tien mat sang tien tai khoan===========================
DROP PROCEDURE IF EXISTS chuyen_tien_mat_sang_tai_khoan$$
CREATE PROCEDURE chuyen_tien_mat_sang_tai_khoan (
    IN c_Ma_so VARCHAR(50),
    IN c_So_tai_khoan VARCHAR(50),
    IN c_So_Tien DECIMAL(15,2)
)
BEGIN
    DECLARE v_ID INT;
    DECLARE v_MaGD VARCHAR(50);
    DECLARE v_Truy_cap VARCHAR(10);
    -- 1. Check request co phai qtv + quyen han
    IF NOT EXISTS(
        SELECT 1
        FROM Quan_tri_vien
        WHERE Ma_so = c_Ma_so
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Ban khong phai la quan tri vien';
    END IF;
    SET v_Truy_cap = (SELECT Cap_do_truy_cap FROM Quan_tri_vien WHERE Ma_so = c_Ma_so);
    IF v_Truy_cap NOT IN ('2', '3') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Ban khong du quyen han thuc hien';
    END IF;
    -- 2.Check so tai khoan kha dung khong
    IF NOT EXISTS(
        SELECT 1
        FROM Tai_khoan_thanh_toan
        WHERE So_tai_khoan = c_So_tai_khoan
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'So tai khoan khong ton tai';
    END IF;
    -- 3. Kiem tra so tien
    IF c_So_Tien <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'So tien khong kha dung';
    END IF;
    -- 4. Update so tien
    UPDATE Tai_khoan_thanh_toan
    SET So_du = So_du + c_So_Tien
    WHERE So_tai_khoan = c_So_tai_khoan;
    
    -- 5. Thuc hien giao dich - record transaction
    SET v_MaGD = CONCAT('GD', LPAD(FLOOR(RAND() * 100000000), 8, '0'));

    INSERT INTO Giao_dich
    (Ma_giao_dich, So_tai_khoan_gui, So_tai_khoan_nhan, So_tien, Phi_chuyen_tien, Thoi_gian, Phan_loai)
    VALUES
    (v_MaGD, c_So_tai_khoan, c_So_tai_khoan, c_So_Tien, 0, NOW(), 'Trans');
END$$



-- =========================== Tao the===========================

DROP PROCEDURE IF EXISTS tao_the$$
CREATE PROCEDURE tao_the (
    IN t_So_tai_khoan VARCHAR(50),
    IN t_Ten_the VARCHAR(50)
)
BEGIN
    DECLARE t_Ma_so_the VARCHAR(50);
    DECLARE t_Ten_chu_the VARCHAR(255);
    DECLARE t_Ngay_het_han DATE;

    -- 1. Check so tai khoan
    IF NOT EXISTS(
        SELECT 1
        FROM Tai_khoan_thanh_toan
        WHERE So_tai_khoan = t_So_tai_khoan
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Khong the thuc hien viec mo the';
    END IF;

    -- 2. Check loai the
    IF NOT EXISTS(
        SELECT 1
        FROM Loai_the
        WHERE Ten_the = t_Ten_the
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Loai the khong kha dung';
    END IF;

    -- 3. Tao the
    SET t_Ma_so_the = CONCAT(t_Ten_the, FLOOR(RAND()*100000000));

    SELECT Ten_khach_hang INTO t_Ten_chu_the
    FROM Tai_khoan
    WHERE So_tai_khoan = t_So_tai_khoan;

    SET t_Ngay_het_han = DATE_ADD(CURDATE(), INTERVAL 5 YEAR);

    INSERT INTO The 
    (Ma_so_the, Ngay_mo_the, Ngay_het_han, So_tai_khoan)
    VALUES (
        t_Ma_so_the,
        CURDATE(),
        t_Ngay_het_han,
        t_So_tai_khoan
    );

END$$


-- =========================== Vo hieu hoa tai khoan===========================
DROP PROCEDURE IF EXISTS vo_hieu_hoa_tai_khoan$$
CREATE PROCEDURE vo_hieu_hoa_tai_khoan (
    IN v_Ma_so VARCHAR(50),
    IN v_So_tai_khoan VARCHAR(50)
)
BEGIN
    DECLARE v_Trang_thai VARCHAR(50);

    -- 1. Chi quan tri vien moi duoc phep vo hieu hoa
    IF NOT EXISTS(
        SELECT 1
        FROM Quan_tri_vien
        WHERE Ma_so = v_Ma_so
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Ban khong phai la quan tri vien';
    END IF;

    -- 2. Kiem tra tai khoan ton tai
    IF NOT EXISTS(
        SELECT 1
        FROM Tai_khoan
        WHERE So_tai_khoan = v_So_tai_khoan
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'So tai khoan khong ton tai';
    END IF;

    SELECT Trang_thai INTO v_Trang_thai
    FROM Tai_khoan
    WHERE So_tai_khoan = v_So_tai_khoan;

    -- 3. If already deactivated, do not update again (use DB enum)
    IF v_Trang_thai = 'DEACTIVE' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Tai khoan da o trang thai DEACTIVE';
    END IF;

    -- 4. Set database enum value to DEACTIVE
    UPDATE Tai_khoan
    SET Trang_thai = 'DEACTIVE'
    WHERE So_tai_khoan = v_So_tai_khoan;
END$$


-- =========================== Kich hoat lai tai khoan===========================
DROP PROCEDURE IF EXISTS kich_hoat_lai_tai_khoan$$
CREATE PROCEDURE kich_hoat_lai_tai_khoan (
    IN v_Ma_so VARCHAR(50),
    IN v_So_tai_khoan VARCHAR(50)
)
BEGIN
    DECLARE v_Trang_thai VARCHAR(50);

    -- 1. Chi quan tri vien moi duoc phep kich hoat lai
    IF NOT EXISTS(
        SELECT 1
        FROM Quan_tri_vien
        WHERE Ma_so = v_Ma_so
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Ban khong phai la quan tri vien';
    END IF;

    -- 2. Kiem tra tai khoan ton tai
    IF NOT EXISTS(
        SELECT 1
        FROM Tai_khoan
        WHERE So_tai_khoan = v_So_tai_khoan
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'So tai khoan khong ton tai';
    END IF;

    SELECT Trang_thai INTO v_Trang_thai
    FROM Tai_khoan
    WHERE So_tai_khoan = v_So_tai_khoan;

    -- 3. If already active, do not update again (use DB enum)
    IF v_Trang_thai = 'ACTIVE' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Tai khoan da o trang thai ACTIVE';
    END IF;

    -- 4. Set database enum value to ACTIVE
    UPDATE Tai_khoan
    SET Trang_thai = 'ACTIVE'
    WHERE So_tai_khoan = v_So_tai_khoan;
END$$


-- =========================== Tao tai khoan tiet kiem===========================
DROP PROCEDURE IF EXISTS tao_tai_khoan_tiet_kiem$$
CREATE PROCEDURE tao_tai_khoan_tiet_kiem (
    IN p_CCCD VARCHAR(12),
    IN p_Ten_dang_nhap VARCHAR(50),
    IN p_Mat_khau VARCHAR(255),
    IN p_Ky_han INT,
    IN p_Lai_suat DECIMAL(5,4),
    IN p_So_tien DECIMAL(15,2),
    IN p_Hinh_thuc_nhan VARCHAR(20),
    OUT p_So_tai_khoan VARCHAR(50)
)
BEGIN
    DECLARE v_Ma_so VARCHAR(50);
    DECLARE v_Ten_khach_hang VARCHAR(255);
    DECLARE v_Next_numeric BIGINT;

    IF p_CCCD IS NULL OR CHAR_LENGTH(TRIM(p_CCCD)) <> 12 OR TRIM(p_CCCD) NOT REGEXP '^[0-9]{12}$' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'CCCD must contain exactly 12 digits.';
    END IF;

    IF p_Ten_dang_nhap IS NULL OR CHAR_LENGTH(TRIM(p_Ten_dang_nhap)) = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Username is required.';
    END IF;

    IF p_Mat_khau IS NULL OR CHAR_LENGTH(p_Mat_khau) < 8 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Password must be at least 8 characters.';
    END IF;

    IF p_Ky_han <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Ky han must be greater than 0.';
    END IF;

    IF p_Lai_suat < 0 OR p_Lai_suat > 0.2 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Lai suat must be between 0 and 0.2.';
    END IF;

    IF p_So_tien < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'So tien cannot be negative.';
    END IF;

    IF p_Hinh_thuc_nhan NOT IN ('Online', 'Offline') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Hinh thuc nhan must be Online or Offline.';
    END IF;

    SELECT tk.Ten_khach_hang INTO v_Ten_khach_hang
    FROM Tai_khoan tk
    WHERE tk.CCCD = TRIM(p_CCCD)
    ORDER BY tk.So_tai_khoan
    LIMIT 1;

    IF v_Ten_khach_hang IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Customer not found for this CCCD.';
    END IF;

    SELECT Ma_so INTO v_Ma_so
    FROM Quan_tri_vien
    ORDER BY RAND()
    LIMIT 1;

    IF v_Ma_so IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No administrator configured in database.';
    END IF;

    SELECT IFNULL(MAX(CAST(So_tai_khoan AS UNSIGNED)), 1000000000) + 1 INTO v_Next_numeric
    FROM Tai_khoan
    WHERE So_tai_khoan REGEXP '^[0-9]+$';

    SET p_So_tai_khoan = CAST(v_Next_numeric AS CHAR);

    INSERT INTO Tai_khoan
    (So_tai_khoan, Ten_khach_hang, Ten_dang_nhap, Mat_khau, CCCD, Trang_thai, Ma_so)
    VALUES
    (p_So_tai_khoan, v_Ten_khach_hang, TRIM(p_Ten_dang_nhap), p_Mat_khau, TRIM(p_CCCD), 'ACTIVE', v_Ma_so);

    INSERT INTO Tai_khoan_tiet_kiem
    (So_tai_khoan, Lai_suat, Ky_han, Hinh_thuc_nhan, So_tien)
    VALUES
    (p_So_tai_khoan, p_Lai_suat, p_Ky_han, p_Hinh_thuc_nhan, p_So_tien);
END$$


-- =========================== Giao dich tien===========================
DROP PROCEDURE IF EXISTS giao_dich_tien$$
CREATE PROCEDURE giao_dich_tien (
    IN p_So_tk_gui VARCHAR(50),
    IN p_So_tk_nhan VARCHAR(50),
    IN p_So_tien DECIMAL(15,2)
)   
BEGIN
    DECLARE v_MaGD VARCHAR(50);
    DECLARE v_ID INT;

    -- 1. Khong cho chuyen chinh minh
    IF p_So_tk_gui = p_So_tk_nhan THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Khong the chuyen cho chinh minh';
    END IF;

    -- 2. Khong cho chuyen tien am
    IF p_So_tien <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'So tien giao dich khong hop le';
    END IF;
    -- 3. Kiem tra han muc
    IF (SELECT Han_muc 
        FROM Tai_khoan_thanh_toan 
        WHERE So_tai_khoan = p_So_tk_gui) < p_So_tien THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Han muc khong du de thuc hien giao dich';
    END IF;
    -- 4. Kiem tra so du
    IF (SELECT So_du 
        FROM Tai_khoan_thanh_toan 
        WHERE So_tai_khoan = p_So_tk_gui) < p_So_tien THEN

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'So du khong du de thuc hien giao dich';
    END IF;

    -- Lay id cho giao dich
    SELECT ID INTO v_ID
    FROM Tai_khoan_thanh_toan
    WHERE So_tai_khoan = p_So_tk_gui;

    -- 5. Thuc hien giao dich
    SET v_MaGD = CONCAT('GD', UNIX_TIMESTAMP());

    -- Tru tien tai khoan gui
    UPDATE Tai_khoan_thanh_toan
    SET So_du = So_du - p_So_tien
    WHERE So_tai_khoan = p_So_tk_gui;

    -- Cong tien tai khoan nhan (chi noi bo)
    IF EXISTS (
        SELECT 1 
        FROM Tai_khoan_thanh_toan 
        WHERE So_tai_khoan = p_So_tk_nhan
    ) THEN
        UPDATE Tai_khoan_thanh_toan
        SET So_du = So_du + p_So_tien
        WHERE So_tai_khoan = p_So_tk_nhan;
    END IF;

    -- 6. Luu lich su giao dich
    SET v_MaGD = CONCAT('GD', LPAD(FLOOR(RAND() * 100000000), 8, '0'));
    
    INSERT INTO Giao_dich
    (Ma_giao_dich, So_tai_khoan_gui, So_tai_khoan_nhan, So_tien, Phi_chuyen_tien, Thoi_gian, Phan_loai)
    VALUES
    (v_MaGD, p_So_tk_gui, p_So_tk_nhan, p_So_tien, 0, NOW(), 'Trans');

END$$


-- =========================== Giao dich hoa don (co khuyen mai===========================

-- =========================== Hoa_don schema migration ===========================
ALTER TABLE Hoa_don MODIFY Ma_giao_dich VARCHAR(50) NULL$$

DROP PROCEDURE IF EXISTS migrate_hoa_don_columns$$
CREATE PROCEDURE migrate_hoa_don_columns()
BEGIN
    DO 0;
END$$

CALL migrate_hoa_don_columns()$$
DROP PROCEDURE IF EXISTS migrate_hoa_don_columns$$

-- =========================== Giao dich khoan vay ===========================

DROP PROCEDURE IF EXISTS GenerateLoanRepayments$$
CREATE PROCEDURE GenerateLoanRepayments (
    IN p_Ma_khoan_vay VARCHAR(50)
)
BEGIN
    DECLARE v_Khoan_vay DECIMAL(15,2);
    DECLARE v_Lai_suat DECIMAL(2,2);
    DECLARE v_Thoi_han_vay INT;
    DECLARE v_Ky_han_tra_goc INT;
    DECLARE v_So_tien_goc DECIMAL(15,2);
    DECLARE v_Num_payments INT;
    DECLARE v_Due_date DATE;
    DECLARE v_Ma_thanh_toan VARCHAR(50);
    DECLARE v_Ma_giao_dich VARCHAR(50);
    DECLARE v_Counter INT;
    DECLARE v_Interest_payment DECIMAL(15,2);
    DECLARE v_Total_payment DECIMAL(15,2);
    DECLARE v_Loan_number INT;

    -- Check if loan exists
    IF NOT EXISTS (
        SELECT 1 FROM Khoan_vay WHERE Ma_khoan_vay = p_Ma_khoan_vay
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Khoan vay khong ton tai';
    END IF;

    -- Get loan details
    SELECT Khoan_vay, Lai_suat, Thoi_han_vay, Ky_han_tra_goc
    INTO v_Khoan_vay, v_Lai_suat, v_Thoi_han_vay, v_Ky_han_tra_goc
    FROM Khoan_vay
    WHERE Ma_khoan_vay = p_Ma_khoan_vay;

    -- Extract loan number from Ma_khoan_vay (assuming format KVXXXX)
    SET v_Loan_number = CAST(SUBSTRING(p_Ma_khoan_vay, 3) AS UNSIGNED);

    -- Calculate number of payments
    SET v_Num_payments = v_Thoi_han_vay DIV v_Ky_han_tra_goc;
    SET v_So_tien_goc = v_Khoan_vay / v_Num_payments;

    -- Validate inputs
    IF v_Ky_han_tra_goc = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Ky han tra goc khong duoc bang 0';
    END IF;
    IF v_Num_payments = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'So lan thanh toan phai lon hon 0';
    END IF;

    -- Delete existing repayments for this loan (if any)
    DELETE FROM Thanh_toan_khoan_vay
    WHERE Ma_khoan_vay = p_Ma_khoan_vay;

    -- Generate repayment schedule
    SET v_Counter = 1;
    WHILE v_Counter <= v_Num_payments DO
        SET v_Due_date = DATE_ADD(CURDATE(), INTERVAL (v_Counter * v_Ky_han_tra_goc) MONTH);
        SET v_Ma_thanh_toan = CONCAT('TT', LPAD(v_Counter - 1, 8, '0'));
        SET v_So_tien_goc = ROUND(v_Khoan_vay / v_Num_payments, 2);
        IF v_Counter = v_Num_payments THEN
            SET v_So_tien_goc = v_Khoan_vay - ROUND(v_So_tien_goc * (v_Num_payments - 1), 2);
        END IF;
        SET v_Interest_payment = ROUND(v_So_tien_goc * v_Lai_suat, 2);
        SET v_Total_payment = ROUND(v_So_tien_goc + v_Interest_payment, 2);

        -- Create repayment record
        INSERT INTO Thanh_toan_khoan_vay (
            Ma_thanh_toan,
            Ma_khoan_vay,
            Ngay_tra_thuc_te,
            Ngay_tra_du_kien,
            So_tien_goc_tra,
            So_tien_lai_tra,
            So_tien_phai_tra,
            Ma_giao_dich
        ) VALUES (
            v_Ma_thanh_toan,
            p_Ma_khoan_vay,
            NULL,
            v_Due_date,
            v_So_tien_goc,
            v_Interest_payment,
            v_Total_payment,
            NULL
        );

        SET v_Counter = v_Counter + 1;
    END WHILE;

END$$

-- =========================== Xoa tai khoan (Admin only) ===========================

DROP PROCEDURE IF EXISTS delete_tai_khoan$$
CREATE PROCEDURE delete_tai_khoan (
    IN p_Ma_so VARCHAR(50),
    IN p_So_tai_khoan VARCHAR(50)
)
BEGIN
    DECLARE v_So_du DECIMAL(15,2);
    DECLARE v_Trang_thai VARCHAR(50);
    DECLARE v_Loan_count INT;
    DECLARE v_Bill_count INT;
    DECLARE v_CCCD VARCHAR(12);

    -- 1. Validate admin permissions
    IF NOT EXISTS(
        SELECT 1 FROM Quan_tri_vien
        WHERE Ma_so = p_Ma_so AND Cap_do_truy_cap = '3'
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Ban khong du quyen han xoa tai khoan (chi co admin cap 3 moi duoc)';
    END IF;

    -- 2. Check account exists
    IF NOT EXISTS(
        SELECT 1 FROM Tai_khoan
        WHERE So_tai_khoan = p_So_tai_khoan
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'So tai khoan khong ton tai';
    END IF;

    -- 3. Get account details from both tables
    SELECT tk.Trang_thai, tk.CCCD, tkt.So_du
    INTO v_Trang_thai, v_CCCD, v_So_du
    FROM Tai_khoan tk
    LEFT JOIN Tai_khoan_thanh_toan tkt ON tk.So_tai_khoan = tkt.So_tai_khoan
    WHERE tk.So_tai_khoan = p_So_tai_khoan;

    -- 4. Check if account has zero balance
    IF v_So_du <> 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Khong the xoa tai khoan co so du khac 0';
    END IF;

    -- 5. Check for active loans
    SELECT COUNT(*)
    INTO v_Loan_count
    FROM Khoan_vay
    WHERE So_tai_khoan = p_So_tai_khoan
      AND Trang_thai IN ('Hoat_dong', 'Qua_han');

    IF v_Loan_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Khong the xoa tai khoan co khoan vay dang hoat dong';
    END IF;

    -- 6. Check for unpaid bills (Hoa_don doesn't have Trang_thai, check via Ma_giao_dich)
    SELECT COUNT(*)
    INTO v_Bill_count
    FROM Hoa_don
    WHERE So_tai_khoan = p_So_tai_khoan;

    IF v_Bill_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Khong the xoa tai khoan co hoa don chua thanh toan';
    END IF;

    -- 7. Delete related records
    DELETE FROM The WHERE So_tai_khoan = p_So_tai_khoan;
    DELETE FROM So_huu WHERE So_tai_khoan = p_So_tai_khoan;
    DELETE FROM Tai_khoan_tiet_kiem WHERE So_tai_khoan = p_So_tai_khoan;
    DELETE FROM Tai_khoan_thanh_toan WHERE So_tai_khoan = p_So_tai_khoan;

    -- 8. Delete transaction records linked to this account
    DELETE FROM Giao_dich
    WHERE So_tai_khoan_gui = p_So_tai_khoan
       OR So_tai_khoan_nhan = p_So_tai_khoan;

    -- 9. Finally delete the account
    DELETE FROM Tai_khoan
    WHERE So_tai_khoan = p_So_tai_khoan;

END$$


-- =========================== SELECT Procedure 1: Get account transactions with details ===========================

DROP PROCEDURE IF EXISTS get_account_transactions$$
CREATE PROCEDURE get_account_transactions (
    IN p_So_tai_khoan VARCHAR(50),
    IN p_Order_by VARCHAR(20)
)
BEGIN
    DECLARE v_Valid_order INT;
    DECLARE v_order VARCHAR(10);

    -- Validate account exists
    IF NOT EXISTS(
        SELECT 1 FROM Tai_khoan
        WHERE So_tai_khoan = p_So_tai_khoan
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'So tai khoan khong ton tai';
    END IF;

    -- Validate order_by parameter
    SET v_Valid_order = CASE
        WHEN p_Order_by IN ('ASC', 'DESC') THEN 1
        ELSE 0
    END;

    SET v_order = p_Order_by;
    IF v_Valid_order = 0 THEN
        SET v_order = 'DESC';
    END IF;

    -- Execute dynamic query
    SET @query = CONCAT('
        SELECT
            gd.Ma_giao_dich,
            gd.So_tai_khoan_gui,
            gd.So_tai_khoan_nhan,
            gd.So_tien,
            gd.Phi_chuyen_tien,
            (gd.So_tien + IFNULL(gd.Phi_chuyen_tien, 0)) AS Tong_chi_phi,
            gd.Thoi_gian AS Ngay_gio,
            gd.Phan_loai AS Hinh_thuc_nhan,
            tk.Ten_khach_hang,
            hd.Ma_hoa_don,
            hd.Loai_hoa_don
        FROM Giao_dich gd
        JOIN Tai_khoan tk ON gd.So_tai_khoan_gui = tk.So_tai_khoan
        LEFT JOIN Hoa_don hd ON gd.Ma_giao_dich = hd.Ma_giao_dich
        WHERE gd.So_tai_khoan_gui = ''', p_So_tai_khoan, '''
           OR gd.So_tai_khoan_nhan = ''', p_So_tai_khoan, '''
        ORDER BY gd.Thoi_gian ', v_order
    );

    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

END$$


-- =========================== UPDATE Procedure 1: Update transaction type safely ===========================

DROP PROCEDURE IF EXISTS cap_nhat_loai_giao_dich$$
CREATE PROCEDURE cap_nhat_loai_giao_dich (
    IN p_Ma_giao_dich VARCHAR(10),
    IN p_So_tai_khoan VARCHAR(50),
    IN p_Phan_loai ENUM('Trans','Bill','Loan')
)
BEGIN
    DECLARE v_So_tai_khoan_gui VARCHAR(10);
    DECLARE v_So_tai_khoan_nhan VARCHAR(10);

    IF NOT EXISTS(
        SELECT 1
        FROM Giao_dich
        WHERE Ma_giao_dich = p_Ma_giao_dich
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Transaction not found.';
    END IF;

    SELECT So_tai_khoan_gui, So_tai_khoan_nhan
    INTO v_So_tai_khoan_gui, v_So_tai_khoan_nhan
    FROM Giao_dich
    WHERE Ma_giao_dich = p_Ma_giao_dich
    LIMIT 1;

    IF p_So_tai_khoan NOT IN (v_So_tai_khoan_gui, v_So_tai_khoan_nhan) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'You can only edit transactions for the selected account.';
    END IF;

    IF EXISTS(SELECT 1 FROM Hoa_don WHERE Ma_giao_dich = p_Ma_giao_dich) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Transaction is linked to a bill and cannot be modified.';
    END IF;

    IF EXISTS(SELECT 1 FROM Ap_dung WHERE Ma_giao_dich = p_Ma_giao_dich) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Transaction is linked to a promotion and cannot be modified.';
    END IF;

    IF EXISTS(SELECT 1 FROM Thanh_toan_khoan_vay WHERE Ma_giao_dich = p_Ma_giao_dich) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Transaction is linked to a loan repayment and cannot be modified.';
    END IF;

    UPDATE Giao_dich
    SET Phan_loai = p_Phan_loai
    WHERE Ma_giao_dich = p_Ma_giao_dich;
END$$


-- =========================== DELETE Procedure 1: Delete transaction safely ===========================

DROP PROCEDURE IF EXISTS xoa_giao_dich$$
CREATE PROCEDURE xoa_giao_dich (
    IN p_Ma_giao_dich VARCHAR(10),
    IN p_So_tai_khoan VARCHAR(50)
)
BEGIN
    DECLARE v_So_tai_khoan_gui VARCHAR(10);
    DECLARE v_So_tai_khoan_nhan VARCHAR(10);

    IF NOT EXISTS(
        SELECT 1
        FROM Giao_dich
        WHERE Ma_giao_dich = p_Ma_giao_dich
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Transaction not found.';
    END IF;

    SELECT So_tai_khoan_gui, So_tai_khoan_nhan
    INTO v_So_tai_khoan_gui, v_So_tai_khoan_nhan
    FROM Giao_dich
    WHERE Ma_giao_dich = p_Ma_giao_dich
    LIMIT 1;

    IF p_So_tai_khoan NOT IN (v_So_tai_khoan_gui, v_So_tai_khoan_nhan) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'You can only delete transactions for the selected account.';
    END IF;

    IF EXISTS(SELECT 1 FROM Hoa_don WHERE Ma_giao_dich = p_Ma_giao_dich) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Transaction is linked to a bill and cannot be deleted.';
    END IF;

    IF EXISTS(SELECT 1 FROM Ap_dung WHERE Ma_giao_dich = p_Ma_giao_dich) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Transaction is linked to a promotion and cannot be deleted.';
    END IF;

    IF EXISTS(SELECT 1 FROM Thanh_toan_khoan_vay WHERE Ma_giao_dich = p_Ma_giao_dich) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Transaction is linked to a loan repayment and cannot be deleted.';
    END IF;

    DELETE FROM Giao_dich
    WHERE Ma_giao_dich = p_Ma_giao_dich;
END$$


-- =========================== SELECT Procedure 2: Get loan summary with aggregate functions ===========================

DROP PROCEDURE IF EXISTS get_loan_summary_by_admin$$
CREATE PROCEDURE get_loan_summary_by_admin (
    IN p_Ma_so VARCHAR(50),
    IN p_Min_total_amount DECIMAL(15,2)
)
BEGIN
    DECLARE v_Cap_do INT;

    -- Validate admin exists and get access level
    IF NOT EXISTS(
        SELECT 1 FROM Quan_tri_vien
        WHERE Ma_so = p_Ma_so
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Ban khong phai la quan tri vien';
    END IF;

    SELECT Cap_do_truy_cap INTO v_Cap_do
    FROM Quan_tri_vien
    WHERE Ma_so = p_Ma_so;

    -- Query with GROUP BY, HAVING, aggregate functions
    SELECT
        qtv.Ma_so,
        CONCAT_WS(' ', n.Ho, n.Ten_lot, n.Ten) AS full_name,
        COUNT(kv.Ma_khoan_vay) AS So_khoan_vay,
        SUM(kv.Khoan_vay) AS Tong_tien_vay,
        AVG(kv.Lai_suat) AS Lai_suat_trung_binh,
        SUM(CASE WHEN kv.Trang_thai = 'Hoat_dong' THEN 1 ELSE 0 END) AS So_khoan_dang_hoat_dong,
        SUM(CASE WHEN kv.Trang_thai = 'Da_thanh_toan' THEN 1 ELSE 0 END) AS So_khoan_da_tat_toan,
        MAX(kv.Ngay_tao_khoan_vay) AS Ngay_phe_duyet_gan_nhat
    FROM Quan_tri_vien qtv
    JOIN Nguoi n ON qtv.CCCD = n.CCCD
    LEFT JOIN Khoan_vay kv ON kv.Ma_so = qtv.Ma_so
    WHERE qtv.Ma_so = p_Ma_so
    GROUP BY qtv.Ma_so, n.Ho, n.Ten_lot, n.Ten, qtv.CCCD
    HAVING p_Min_total_amount = 0 OR COALESCE(SUM(kv.Khoan_vay), 0) >= p_Min_total_amount
    ORDER BY SUM(kv.Khoan_vay) DESC;

END$$


-- =========================== Function 1: Calculate total interest for customer ===========================

DROP FUNCTION IF EXISTS calculate_total_interest$$
CREATE FUNCTION calculate_total_interest(
    p_So_tai_khoan VARCHAR(50)
)
RETURNS DECIMAL(15,2)
READS SQL DATA
BEGIN
    DECLARE v_Total_interest DECIMAL(15,2);

    -- Validate account exists
    IF NOT EXISTS(
        SELECT 1 FROM Tai_khoan
        WHERE So_tai_khoan = p_So_tai_khoan
    ) THEN
        RETURN -1;
    END IF;

    -- Sum up all interest amounts from unpaid repayments
    SELECT COALESCE(SUM(So_tien_lai_tra), 0)
    INTO v_Total_interest
    FROM Thanh_toan_khoan_vay ttk
    JOIN Khoan_vay kv ON ttk.Ma_khoan_vay = kv.Ma_khoan_vay
    WHERE kv.So_tai_khoan = p_So_tai_khoan
    AND ttk.Ngay_tra_thuc_te IS NULL;

    RETURN v_Total_interest;
END$$


-- =========================== Function 2: Check loan eligibility ===========================

DROP FUNCTION IF EXISTS check_loan_eligibility$$
CREATE FUNCTION check_loan_eligibility(
    p_CCCD VARCHAR(12)
)
RETURNS VARCHAR(100)
READS SQL DATA
BEGIN
    DECLARE v_Age INT;
    DECLARE v_Active_loan_count INT;
    DECLARE v_Overdue_loan_count INT;
    DECLARE v_Account_status VARCHAR(50);

    -- Validate CCCD exists
    IF NOT EXISTS(
        SELECT 1 FROM Nguoi
        WHERE CCCD = p_CCCD
    ) THEN
        RETURN 'Khong tim thay nguoi dung';
    END IF;

    -- Check age >= 18
    SELECT TIMESTAMPDIFF(YEAR, Ngay_sinh, CURDATE())
    INTO v_Age
    FROM Nguoi
    WHERE CCCD = p_CCCD;

    IF v_Age < 18 THEN
        RETURN 'Phai tren 18 tuoi';
    END IF;

    -- Check if has active account
    SELECT COUNT(*), Trang_thai
    INTO v_Active_loan_count, v_Account_status
    FROM Tai_khoan
    WHERE CCCD = p_CCCD
    GROUP BY Trang_thai;

    IF v_Account_status <> 'ACTIVE' THEN
        RETURN 'Tai khoan khong hoat dong';
    END IF;

    -- Check for overdue loans
    SELECT COUNT(*)
    INTO v_Overdue_loan_count
    FROM Khoan_vay
    WHERE So_tai_khoan IN (
        SELECT So_tai_khoan FROM Tai_khoan WHERE CCCD = p_CCCD
    )
    AND Trang_thai = 'Qua_han';

    IF v_Overdue_loan_count > 0 THEN
        RETURN 'Co khoan vay qua han - khong du dieu kien vay moi';
    END IF;

    -- Check number of active loans (max 3)
    SELECT COUNT(*)
    INTO v_Active_loan_count
    FROM Khoan_vay
    WHERE So_tai_khoan IN (
        SELECT So_tai_khoan FROM Tai_khoan WHERE CCCD = p_CCCD
    )
    AND Trang_thai = 'Hoat_dong';

    IF v_Active_loan_count >= 3 THEN
        RETURN 'Da dat so khoan vay toi da (3 khoan)';
    END IF;

    RETURN 'Du dieu kien vay';
END$$

-- =========================== API helpers ==========================
DROP PROCEDURE IF EXISTS api_generate_transaction_id$$
CREATE PROCEDURE api_generate_transaction_id(OUT p_id VARCHAR(10))
BEGIN
    DECLARE v_candidate VARCHAR(10);
    DECLARE v_tries INT DEFAULT 0;

    SET p_id = '';

    gen_loop: WHILE v_tries < 25 DO
        SET v_candidate = CONCAT('GD', LPAD(FLOOR(RAND() * 100000000), 8, '0'));
        IF NOT EXISTS (SELECT 1 FROM Giao_dich WHERE Ma_giao_dich = v_candidate) THEN
            SET p_id = v_candidate;
            LEAVE gen_loop;
        END IF;
        SET v_tries = v_tries + 1;
    END WHILE;

    IF p_id = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Unable to generate unique transaction id.';
    END IF;
END$$

DROP PROCEDURE IF EXISTS api_generate_bill_id$$
CREATE PROCEDURE api_generate_bill_id(OUT p_id VARCHAR(10))
BEGIN
    DECLARE v_candidate VARCHAR(10);
    DECLARE v_tries INT DEFAULT 0;

    SET p_id = '';

    gen_loop: WHILE v_tries < 25 DO
        SET v_candidate = CONCAT('HD', LPAD(FLOOR(RAND() * 100000000), 8, '0'));
        IF NOT EXISTS (SELECT 1 FROM Hoa_don WHERE Ma_hoa_don = v_candidate) THEN
            SET p_id = v_candidate;
            LEAVE gen_loop;
        END IF;
        SET v_tries = v_tries + 1;
    END WHILE;

    IF p_id = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Unable to generate unique bill id.';
    END IF;
END$$

DROP PROCEDURE IF EXISTS api_generate_loan_id$$
CREATE PROCEDURE api_generate_loan_id(OUT p_id VARCHAR(10))
BEGIN
    DECLARE v_candidate VARCHAR(10);
    DECLARE v_tries INT DEFAULT 0;

    SET p_id = '';

    gen_loop: WHILE v_tries < 25 DO
        SET v_candidate = CONCAT('KV', LPAD(FLOOR(RAND() * 10000), 4, '0'));
        IF NOT EXISTS (SELECT 1 FROM Khoan_vay WHERE Ma_khoan_vay = v_candidate) THEN
            SET p_id = v_candidate;
            LEAVE gen_loop;
        END IF;
        SET v_tries = v_tries + 1;
    END WHILE;

    IF p_id = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Unable to generate unique loan id.';
    END IF;
END$$

DROP PROCEDURE IF EXISTS api_generate_card_number$$
CREATE PROCEDURE api_generate_card_number(OUT p_id VARCHAR(20))
BEGIN
    DECLARE v_candidate VARCHAR(20);
    DECLARE v_tries INT DEFAULT 0;

    SET p_id = '';

    gen_loop: WHILE v_tries < 25 DO
        SET v_candidate = CONCAT(
            LPAD(FLOOR(RAND() * 10000), 4, '0'),
            LPAD(FLOOR(RAND() * 10000), 4, '0'),
            LPAD(FLOOR(RAND() * 10000), 4, '0'),
            LPAD(FLOOR(RAND() * 10000), 4, '0')
        );
        IF NOT EXISTS (SELECT 1 FROM The WHERE Ma_so_the = v_candidate) THEN
            SET p_id = v_candidate;
            LEAVE gen_loop;
        END IF;
        SET v_tries = v_tries + 1;
    END WHILE;

    IF p_id = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Unable to generate unique card number.';
    END IF;
END$$

DROP PROCEDURE IF EXISTS api_next_numeric_account_number$$
CREATE PROCEDURE api_next_numeric_account_number(OUT p_account_number VARCHAR(20))
BEGIN
    DECLARE v_max BIGINT;

    SELECT MAX(CAST(So_tai_khoan AS UNSIGNED)) INTO v_max
    FROM Tai_khoan
    WHERE So_tai_khoan REGEXP '^[0-9]+$';

    IF v_max IS NULL THEN
        SET v_max = 1000000000;
    END IF;

    SET p_account_number = CAST(v_max + 1 AS CHAR);
END$$

-- =========================== API procedures ==========================
DROP PROCEDURE IF EXISTS api_health_check$$
CREATE PROCEDURE api_health_check()
BEGIN
    SELECT 1 AS status;
END$$

DROP PROCEDURE IF EXISTS api_get_card_types$$
CREATE PROCEDURE api_get_card_types()
BEGIN
    SELECT Ten_the FROM Loai_the ORDER BY Ten_the;
END$$

DROP PROCEDURE IF EXISTS api_create_card$$
CREATE PROCEDURE api_create_card(
    IN p_account_number VARCHAR(10),
    IN p_card_type VARCHAR(50),
    IN p_cccd VARCHAR(12)
)
BEGIN
    DECLARE v_customer_name VARCHAR(255);
    DECLARE v_card_number VARCHAR(20);

    IF p_cccd IS NULL OR p_cccd = '' THEN
        SELECT tk.Ten_khach_hang INTO v_customer_name
        FROM Tai_khoan tk
        JOIN Tai_khoan_thanh_toan ttt ON ttt.So_tai_khoan = tk.So_tai_khoan
        WHERE tk.So_tai_khoan = p_account_number
        LIMIT 1;
    ELSE
        SELECT tk.Ten_khach_hang INTO v_customer_name
        FROM Tai_khoan tk
        JOIN Tai_khoan_thanh_toan ttt ON ttt.So_tai_khoan = tk.So_tai_khoan
        WHERE tk.So_tai_khoan = p_account_number
          AND tk.CCCD = p_cccd
        LIMIT 1;
    END IF;

    IF v_customer_name IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Payment account not found for this customer.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM Loai_the WHERE Ten_the = p_card_type LIMIT 1) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Card type does not exist.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM Loai_the lt
        JOIN The t ON t.Ma_so_the = lt.Ma_so_the
        WHERE t.So_tai_khoan = p_account_number
          AND lt.Ten_the = p_card_type
        LIMIT 1
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'This card type already exists for the selected account.';
    END IF;

    CALL api_generate_card_number(v_card_number);

    INSERT INTO The (Ma_so_the, Ngay_mo_the, Ngay_het_han, So_tai_khoan)
    VALUES (v_card_number, CURDATE(), DATE_ADD(CURDATE(), INTERVAL 5 YEAR), p_account_number);

    INSERT INTO Loai_the (Ten_the, Ma_so_the)
    VALUES (p_card_type, v_card_number);

    SELECT v_card_number AS cardNumber,
           p_card_type AS cardType,
           p_account_number AS accountNumber;
END$$

DROP PROCEDURE IF EXISTS api_login_user$$
CREATE PROCEDURE api_login_user(
    IN p_username VARCHAR(50),
    IN p_password VARCHAR(255)
)
BEGIN
    SELECT tk.So_tai_khoan,
           tk.Ten_khach_hang,
           tk.Ten_dang_nhap,
           tk.CCCD
    FROM Tai_khoan tk
    WHERE tk.Ten_dang_nhap = p_username
      AND tk.Mat_khau = p_password
      AND tk.Trang_thai <> 'REMOVED'
    LIMIT 1;
END$$

DROP PROCEDURE IF EXISTS api_admin_login$$
CREATE PROCEDURE api_admin_login(
    IN p_username VARCHAR(50),
    IN p_password VARCHAR(50)
)
BEGIN
    SELECT qtv.Ten_dang_nhap AS username,
           qtv.Ma_so,
           n.CCCD,
           CONCAT_WS(' ', n.Ho, n.Ten_lot, n.Ten) AS full_name,
           n.Gioi_tinh,
           n.Quoc_tich,
           GROUP_CONCAT(DISTINCT sdt.So_dien_thoai ORDER BY sdt.So_dien_thoai SEPARATOR ', ') AS phone_numbers,
           GROUP_CONCAT(DISTINCT em.Tk_email ORDER BY em.Tk_email SEPARATOR ', ') AS emails
    FROM Quan_tri_vien qtv
    JOIN Nguoi n ON n.CCCD = qtv.CCCD
    LEFT JOIN So_dien_thoai sdt ON sdt.CCCD = n.CCCD
    LEFT JOIN Tai_khoan_email em ON em.CCCD = n.CCCD
    WHERE qtv.Ten_dang_nhap = p_username
      AND qtv.Mat_khau = p_password
    GROUP BY qtv.Ten_dang_nhap, qtv.Ma_so, n.CCCD, n.Ho, n.Ten_lot, n.Ten, n.Gioi_tinh, n.Quoc_tich
    LIMIT 1;
END$$

DROP PROCEDURE IF EXISTS api_register_account$$
CREATE PROCEDURE api_register_account(
    IN p_first_name VARCHAR(50),
    IN p_middle_name VARCHAR(50),
    IN p_last_name VARCHAR(50),
    IN p_cccd VARCHAR(12),
    IN p_gender VARCHAR(10),
    IN p_nationality VARCHAR(50),
    IN p_dob DATE,
    IN p_phone VARCHAR(10),
    IN p_email VARCHAR(50),
    IN p_referrer_cccd VARCHAR(12),
    IN p_username VARCHAR(50),
    IN p_password VARCHAR(255)
)
BEGIN
    DECLARE v_account_number VARCHAR(20);
    DECLARE v_admin_ma_so VARCHAR(20);
    DECLARE v_full_name VARCHAR(255);

    SET v_full_name = TRIM(CONCAT_WS(' ', p_first_name, p_middle_name, p_last_name));

    SELECT Ma_so INTO v_admin_ma_so
    FROM Quan_tri_vien
    ORDER BY Ma_so
    LIMIT 1;

    IF v_admin_ma_so IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No administrator configured in database.';
    END IF;

    CALL api_next_numeric_account_number(v_account_number);

    INSERT INTO Nguoi (CCCD, Ho, Ten_lot, Ten, Quoc_tich, Gioi_tinh, Ngay_sinh)
    VALUES (p_cccd, p_first_name, p_middle_name, p_last_name, p_nationality, p_gender, p_dob);

    INSERT INTO Nguoi_dung (CCCD) VALUES (p_cccd);

    IF p_referrer_cccd IS NOT NULL AND p_referrer_cccd <> '' THEN
        IF NOT EXISTS (SELECT 1 FROM Nguoi WHERE CCCD = p_referrer_cccd LIMIT 1) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Referrer CCCD does not exist.';
        END IF;
        INSERT INTO Gioi_thieu (CCCD_Nguoi_gioi_thieu, CCCD_Khach_moi)
        VALUES (p_referrer_cccd, p_cccd);
    END IF;

    INSERT INTO So_dien_thoai (CCCD, So_dien_thoai)
    VALUES (p_cccd, p_phone);

    IF p_email IS NOT NULL AND p_email <> '' THEN
        INSERT INTO Tai_khoan_email (CCCD, Tk_email)
        VALUES (p_cccd, p_email);
    END IF;

    INSERT INTO Tai_khoan
    (So_tai_khoan, Ten_khach_hang, Ten_dang_nhap, Mat_khau, CCCD, Trang_thai, Ma_so)
    VALUES (v_account_number, v_full_name, p_username, p_password, p_cccd, 'ACTIVE', v_admin_ma_so);

    INSERT INTO Tai_khoan_thanh_toan (So_tai_khoan, Han_muc, So_du)
    VALUES (v_account_number, 50000000, 0);

    INSERT INTO Tai_khoan_giao_dich (So_tai_khoan, Loai_tk)
    VALUES (v_account_number, 'Noi_bo');

    SELECT v_account_number AS accountNumber,
           p_username AS username,
           v_full_name AS fullName,
           p_cccd AS cccd;
END$$

DROP PROCEDURE IF EXISTS api_create_additional_account$$
CREATE PROCEDURE api_create_additional_account(
    IN p_cccd VARCHAR(12),
    IN p_username VARCHAR(50),
    IN p_password VARCHAR(255)
)
BEGIN
    DECLARE v_account_number VARCHAR(20);
    DECLARE v_admin_ma_so VARCHAR(20);
    DECLARE v_owner_name VARCHAR(255);

    SELECT Ten_khach_hang INTO v_owner_name
    FROM Tai_khoan
    WHERE CCCD = p_cccd
    ORDER BY So_tai_khoan
    LIMIT 1;

    IF v_owner_name IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Customer not found for this CCCD.';
    END IF;

    SELECT Ma_so INTO v_admin_ma_so
    FROM Quan_tri_vien
    ORDER BY RAND()
    LIMIT 1;

    IF v_admin_ma_so IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No administrator configured in database.';
    END IF;

    CALL api_next_numeric_account_number(v_account_number);

    INSERT INTO Tai_khoan
    (So_tai_khoan, Ten_khach_hang, Ten_dang_nhap, Mat_khau, CCCD, Trang_thai, Ma_so)
    VALUES (v_account_number, v_owner_name, p_username, p_password, p_cccd, 'ACTIVE', v_admin_ma_so);

    INSERT INTO Tai_khoan_thanh_toan (So_tai_khoan, Han_muc, So_du)
    VALUES (v_account_number, 50000000, 0);

    INSERT INTO Tai_khoan_giao_dich (So_tai_khoan, Loai_tk)
    VALUES (v_account_number, 'Noi_bo');

    SELECT v_account_number AS accountNumber,
           p_username AS username,
           p_cccd AS cccd;
END$$

DROP PROCEDURE IF EXISTS api_create_savings_account$$
CREATE PROCEDURE api_create_savings_account(
    IN p_cccd VARCHAR(12),
    IN p_username VARCHAR(50),
    IN p_password VARCHAR(255),
    IN p_term_months INT,
    IN p_interest_rate DECIMAL(5,4),
    IN p_amount DECIMAL(15,2),
    IN p_receive_method VARCHAR(20)
)
BEGIN
    DECLARE v_account_number VARCHAR(50);

    CALL tao_tai_khoan_tiet_kiem(
        p_cccd,
        p_username,
        p_password,
        p_term_months,
        p_interest_rate,
        p_amount,
        p_receive_method,
        v_account_number
    );

    SELECT v_account_number AS accountNumber;
END$$

DROP PROCEDURE IF EXISTS api_create_transaction$$
CREATE PROCEDURE api_create_transaction(
    IN p_sender_account VARCHAR(15),
    IN p_receiver_account VARCHAR(15),
    IN p_amount DECIMAL(15,2),
    IN p_fee DECIMAL(15,2),
    IN p_cccd VARCHAR(12),
    IN p_promotion_code VARCHAR(10)
)
BEGIN
    DECLARE v_so_du DECIMAL(15,2);
    DECLARE v_han_muc DECIMAL(15,2);
    DECLARE v_transaction_id VARCHAR(10);

    IF p_amount IS NULL OR p_amount <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Amount must be greater than 0.';
    END IF;

    IF p_sender_account = p_receiver_account THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Sender and receiver accounts must be different.';
    END IF;

    IF p_cccd IS NULL OR p_cccd = '' THEN
        SELECT ttt.So_du, ttt.Han_muc INTO v_so_du, v_han_muc
        FROM Tai_khoan_thanh_toan ttt
        JOIN Tai_khoan tk ON tk.So_tai_khoan = ttt.So_tai_khoan
        WHERE ttt.So_tai_khoan = p_sender_account
          AND tk.Trang_thai = 'ACTIVE'
        LIMIT 1;
    ELSE
        SELECT ttt.So_du, ttt.Han_muc INTO v_so_du, v_han_muc
        FROM Tai_khoan_thanh_toan ttt
        JOIN Tai_khoan tk ON tk.So_tai_khoan = ttt.So_tai_khoan
        WHERE ttt.So_tai_khoan = p_sender_account
          AND tk.CCCD = p_cccd
          AND tk.Trang_thai = 'ACTIVE'
        LIMIT 1;
    END IF;

    IF v_so_du IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Sender account is not active or does not belong to the customer.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM Tai_khoan_thanh_toan WHERE So_tai_khoan = p_receiver_account
        UNION
        SELECT 1 FROM Tai_khoan_ngoai WHERE So_tai_khoan = p_receiver_account
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Receiver account does not exist.';
    END IF;

    IF v_han_muc < p_amount THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Amount exceeds account spending limit.';
    END IF;

    IF v_so_du < (p_amount + IFNULL(p_fee, 0)) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Insufficient balance for this transaction.';
    END IF;

    CALL api_generate_transaction_id(v_transaction_id);

    INSERT INTO Giao_dich
    (Ma_giao_dich, So_tai_khoan_gui, So_tai_khoan_nhan, So_tien, Phi_chuyen_tien, Thoi_gian, Phan_loai)
    VALUES (v_transaction_id, p_sender_account, p_receiver_account, p_amount, IFNULL(p_fee, 0), NOW(), 'Trans');

    IF p_promotion_code IS NOT NULL AND p_promotion_code <> '' THEN
        IF NOT EXISTS (
            SELECT 1
            FROM Khuyen_mai km
            WHERE km.Ma = p_promotion_code
              AND CURDATE() BETWEEN km.Ngay_bat_dau AND km.Ngay_ket_thuc
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Promotion code does not exist or is not active.';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM Cap_nhat WHERE Ma = p_promotion_code) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Promotion has not been updated by an administrator yet.';
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM So_huu WHERE Ma = p_promotion_code AND So_tai_khoan = p_sender_account
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'This promotion is not assigned to the selected sender account.';
        END IF;

        INSERT INTO Ap_dung (Ma, Ma_giao_dich)
        VALUES (p_promotion_code, v_transaction_id);
    END IF;

    SELECT v_transaction_id AS transactionId,
           ttt.So_du AS remainingBalance,
           ttt.Han_muc AS remainingLimit
    FROM Tai_khoan_thanh_toan ttt
    WHERE ttt.So_tai_khoan = p_sender_account
    LIMIT 1;
END$$

DROP PROCEDURE IF EXISTS api_get_transactions$$
CREATE PROCEDURE api_get_transactions(
    IN p_account_number VARCHAR(15)
)
BEGIN
    SELECT gd.Ma_giao_dich,
           gd.So_tien,
           gd.Phi_chuyen_tien,
           gd.Thoi_gian AS Ngay_gio,
           gd.Phan_loai AS Hinh_thuc_nhan,
           IFNULL(
               (
                   SELECT GROUP_CONCAT(km.Ten_chuong_trinh ORDER BY km.Ma SEPARATOR ', ')
                   FROM Ap_dung ad
                   JOIN Khuyen_mai km ON km.Ma = ad.Ma
                   WHERE ad.Ma_giao_dich = gd.Ma_giao_dich
               ),
               ''
           ) AS Ten_khuyen_mai,
           IFNULL(
               (
                   SELECT SUM(km.Gia_tri)
                   FROM Ap_dung ad
                   JOIN Khuyen_mai km ON km.Ma = ad.Ma
                   WHERE ad.Ma_giao_dich = gd.Ma_giao_dich
               ),
               0
           ) AS Tong_tien_khuyen_mai
    FROM Giao_dich gd
    WHERE gd.So_tai_khoan_gui = p_account_number
       OR gd.So_tai_khoan_nhan = p_account_number
    ORDER BY gd.Thoi_gian DESC
    LIMIT 20;
END$$

DROP PROCEDURE IF EXISTS api_get_accounts_by_cccd$$
CREATE PROCEDURE api_get_accounts_by_cccd(
    IN p_cccd VARCHAR(12)
)
BEGIN
    SELECT tk.So_tai_khoan,
           tk.Ten_khach_hang,
           tk.Trang_thai,
           IFNULL(ttt.So_du, 0) AS So_du,
           IFNULL(ttt.Han_muc, 0) AS Han_muc,
           CASE WHEN tsk.So_tai_khoan IS NOT NULL THEN 'savings' ELSE 'payment' END AS account_type,
           IFNULL(tsk.Lai_suat, 0) AS Lai_suat,
           IFNULL(tsk.Ky_han, 0) AS Ky_han,
           IFNULL(tsk.Hinh_thuc_nhan, '') AS Hinh_thuc_nhan,
           IFNULL(tsk.So_tien, 0) AS tsk_So_tien
    FROM Tai_khoan tk
    LEFT JOIN Tai_khoan_thanh_toan ttt ON ttt.So_tai_khoan = tk.So_tai_khoan
    LEFT JOIN Tai_khoan_tiet_kiem tsk ON tsk.So_tai_khoan = tk.So_tai_khoan
    WHERE tk.CCCD = p_cccd
    ORDER BY tk.So_tai_khoan;
END$$

DROP PROCEDURE IF EXISTS api_lookup_recipient$$
CREATE PROCEDURE api_lookup_recipient(
    IN p_query VARCHAR(20)
)
BEGIN
    IF EXISTS (SELECT 1 FROM Tai_khoan WHERE So_tai_khoan = p_query LIMIT 1) THEN
        SELECT tk.So_tai_khoan AS key_value,
               tk.Ten_khach_hang AS display_name,
               NULL AS bank_name,
               'account' AS source
        FROM Tai_khoan tk
        WHERE tk.So_tai_khoan = p_query
        LIMIT 1;
    ELSEIF EXISTS (SELECT 1 FROM Tai_khoan_ngoai WHERE So_tai_khoan = p_query LIMIT 1) THEN
        SELECT tkn.So_tai_khoan AS key_value,
               tkn.Ten_nguoi_nhan AS display_name,
               tkn.Ngan_hang_nhan AS bank_name,
               'external' AS source
        FROM Tai_khoan_ngoai tkn
        WHERE tkn.So_tai_khoan = p_query
        LIMIT 1;
    END IF;
END$$

DROP PROCEDURE IF EXISTS api_get_promotions$$
CREATE PROCEDURE api_get_promotions(
    IN p_account_number VARCHAR(15)
)
BEGIN
    IF p_account_number IS NULL OR p_account_number = '' THEN
        SELECT km.Ma,
               km.Ten_chuong_trinh,
               km.Gia_tri,
               km.So_tien_toi_thieu,
               km.Ngay_bat_dau,
               km.Ngay_ket_thuc,
               km.Loai
        FROM Khuyen_mai km
        WHERE CURDATE() BETWEEN km.Ngay_bat_dau AND km.Ngay_ket_thuc
          AND EXISTS (SELECT 1 FROM Cap_nhat cn WHERE cn.Ma = km.Ma)
        ORDER BY km.Ngay_ket_thuc, km.Ma;
    ELSE
        SELECT km.Ma,
               km.Ten_chuong_trinh,
               km.Gia_tri,
               km.So_tien_toi_thieu,
               km.Ngay_bat_dau,
               km.Ngay_ket_thuc,
               km.Loai
        FROM Khuyen_mai km
        WHERE CURDATE() BETWEEN km.Ngay_bat_dau AND km.Ngay_ket_thuc
          AND EXISTS (SELECT 1 FROM Cap_nhat cn WHERE cn.Ma = km.Ma)
          AND EXISTS (
              SELECT 1
              FROM So_huu sh
              WHERE sh.Ma = km.Ma
                AND sh.So_tai_khoan = p_account_number
          )
        ORDER BY km.Ngay_ket_thuc, km.Ma;
    END IF;
END$$

DROP PROCEDURE IF EXISTS api_get_promotion_history$$
CREATE PROCEDURE api_get_promotion_history(
    IN p_cccd VARCHAR(12)
)
BEGIN
    SELECT km.Ma,
           km.Ten_chuong_trinh,
           km.Ngay_bat_dau,
           km.Ngay_ket_thuc,
           cn.Ngay_cap_nhat AS Ngay_gan_nhat,
           cn.Ma_so AS Ma_so_admin,
           qv.Ten_dang_nhap AS Ten_admin
    FROM So_huu sh
    JOIN Khuyen_mai km ON sh.Ma = km.Ma
    JOIN Tai_khoan tk ON tk.So_tai_khoan = sh.So_tai_khoan
    LEFT JOIN Cap_nhat cn ON cn.Ma = km.Ma
    LEFT JOIN Quan_tri_vien qv ON qv.Ma_so = cn.Ma_so
    WHERE tk.CCCD = p_cccd
    ORDER BY cn.Ngay_cap_nhat DESC, km.Ma;
END$$

DROP PROCEDURE IF EXISTS api_get_bills$$
CREATE PROCEDURE api_get_bills(
    IN p_cccd VARCHAR(12)
)
BEGIN
    SELECT hd.Ma_hoa_don,
           hd.Loai_hoa_don,
           hd.So_tien_thanh_toan,
           hd.So_tai_khoan,
           hd.Ma_giao_dich
    FROM Hoa_don hd
    JOIN Tai_khoan tk ON tk.So_tai_khoan = hd.So_tai_khoan
    WHERE tk.CCCD = p_cccd
    ORDER BY hd.Ma_hoa_don DESC;
END$$

DROP PROCEDURE IF EXISTS api_create_bill$$
CREATE PROCEDURE api_create_bill(
    IN p_cccd VARCHAR(12),
    IN p_account_number VARCHAR(10),
    IN p_bill_type VARCHAR(20),
    IN p_amount DECIMAL(15,2)
)
BEGIN
    DECLARE v_bill_id VARCHAR(10);

    IF p_amount IS NULL OR p_amount <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'amount must be greater than 0.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM Tai_khoan_thanh_toan ttt
        JOIN Tai_khoan tk ON tk.So_tai_khoan = ttt.So_tai_khoan
        WHERE ttt.So_tai_khoan = p_account_number
          AND tk.CCCD = p_cccd
        LIMIT 1
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Payment account not found for this customer.';
    END IF;

    CALL api_generate_bill_id(v_bill_id);

    INSERT INTO Hoa_don
    (Ma_hoa_don, Loai_hoa_don, So_tien_thanh_toan, So_tai_khoan, Ma_giao_dich)
    VALUES (v_bill_id, p_bill_type, p_amount, p_account_number, NULL);

    SELECT v_bill_id AS billId;
END$$

DROP PROCEDURE IF EXISTS api_pay_bill$$
CREATE PROCEDURE api_pay_bill(
    IN p_cccd VARCHAR(12),
    IN p_bill_id VARCHAR(10),
    IN p_promotion_code VARCHAR(10)
)
BEGIN
    DECLARE v_amount DECIMAL(15,2);
    DECLARE v_account_number VARCHAR(10);
    DECLARE v_transaction_id VARCHAR(10);
    DECLARE v_so_du DECIMAL(15,2);
    DECLARE v_ma_giao_dich VARCHAR(10);

    SELECT hd.So_tien_thanh_toan,
           hd.So_tai_khoan,
           hd.Ma_giao_dich,
           IFNULL(ttt.So_du, 0)
    INTO v_amount, v_account_number, v_ma_giao_dich, v_so_du
    FROM Hoa_don hd
    JOIN Tai_khoan tk ON tk.So_tai_khoan = hd.So_tai_khoan
    JOIN Tai_khoan_thanh_toan ttt ON ttt.So_tai_khoan = hd.So_tai_khoan
    WHERE hd.Ma_hoa_don = p_bill_id
      AND tk.CCCD = p_cccd
    LIMIT 1;

    IF v_amount IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Bill not found for this customer.';
    END IF;

    IF v_ma_giao_dich IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Bill already paid.';
    END IF;

    IF v_amount <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No outstanding amount for this bill.';
    END IF;

    IF v_so_du < v_amount THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Insufficient balance for this bill.';
    END IF;

    CALL api_generate_transaction_id(v_transaction_id);

    CALL ThemGiaoDich(
        v_transaction_id,
        v_account_number,
        '0000000001',
        v_amount,
        0,
        'Bill',
        p_bill_id,
        NULL,
        NULL
    );

    IF p_promotion_code IS NOT NULL AND p_promotion_code <> '' THEN
        IF NOT EXISTS (
            SELECT 1
            FROM Khuyen_mai km
            WHERE km.Ma = p_promotion_code
              AND CURDATE() BETWEEN km.Ngay_bat_dau AND km.Ngay_ket_thuc
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Promotion does not exist or is not active.';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM Cap_nhat WHERE Ma = p_promotion_code) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Promotion has not been updated by any administrator yet.';
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM So_huu WHERE Ma = p_promotion_code AND So_tai_khoan = v_account_number
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'This promotion is not assigned to the selected account.';
        END IF;

        INSERT INTO Ap_dung (Ma, Ma_giao_dich)
        VALUES (p_promotion_code, v_transaction_id);
    END IF;

    SELECT v_transaction_id AS transactionId,
           ttt.So_du AS remainingBalance
    FROM Tai_khoan_thanh_toan ttt
    WHERE ttt.So_tai_khoan = v_account_number
    LIMIT 1;
END$$

DROP PROCEDURE IF EXISTS api_create_loan$$
CREATE PROCEDURE api_create_loan(
    IN p_cccd VARCHAR(12),
    IN p_account_number VARCHAR(10),
    IN p_term_months INT,
    IN p_principal_cycle INT,
    IN p_interest_rate DECIMAL(4,4),
    IN p_loan_amount DECIMAL(15,2)
)
BEGIN
    DECLARE v_loan_id VARCHAR(10);
    DECLARE v_admin_ma_so VARCHAR(20);
    DECLARE v_transaction_id VARCHAR(10);

    IF p_account_number = '0000000001' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot create loan for system account.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM Tai_khoan tk
        WHERE tk.So_tai_khoan = p_account_number
          AND tk.CCCD = p_cccd
        LIMIT 1
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Selected account does not belong to this customer.';
    END IF;

    SELECT Ma_so INTO v_admin_ma_so
    FROM Quan_tri_vien
    ORDER BY Ma_so
    LIMIT 1;

    IF v_admin_ma_so IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No administrator configured in database.';
    END IF;

    CALL api_generate_loan_id(v_loan_id);

    CALL sp_ThemKhoanVay(
        v_loan_id,
        p_interest_rate,
        p_loan_amount,
        p_term_months,
        p_principal_cycle,
        p_account_number,
        v_admin_ma_so,
        CURDATE()
    );

    CALL api_generate_transaction_id(v_transaction_id);

    INSERT INTO Giao_dich
    (Ma_giao_dich, So_tai_khoan_gui, So_tai_khoan_nhan, So_tien, Phi_chuyen_tien, Thoi_gian, Phan_loai)
    VALUES (v_transaction_id, '0000000001', p_account_number, p_loan_amount, 0, NOW(), 'Trans');

    CALL GenerateLoanRepayments(v_loan_id);

    SELECT v_loan_id AS loanId,
           v_transaction_id AS disbursementTransactionId;
END$$

DROP PROCEDURE IF EXISTS api_get_loans_and_repayments$$
CREATE PROCEDURE api_get_loans_and_repayments(
    IN p_cccd VARCHAR(12)
)
BEGIN
    UPDATE Khoan_vay kv
    JOIN (
        SELECT ttv.Ma_khoan_vay,
               COUNT(*) AS total_rows,
               SUM(CASE WHEN ttv.Ngay_tra_thuc_te IS NOT NULL THEN 1 ELSE 0 END) AS paid_rows,
               SUM(CASE WHEN ttv.Ngay_tra_thuc_te IS NULL AND ttv.Ngay_tra_du_kien < CURDATE() THEN 1 ELSE 0 END) AS overdue_rows
        FROM Thanh_toan_khoan_vay ttv
        GROUP BY ttv.Ma_khoan_vay
    ) stats ON stats.Ma_khoan_vay = kv.Ma_khoan_vay
    SET kv.Trang_thai = CASE
        WHEN stats.total_rows > 0 AND stats.paid_rows >= stats.total_rows THEN 'Da_thanh_toan'
        WHEN stats.overdue_rows > 0 THEN 'Qua_han'
        ELSE 'Hoat_dong'
    END
    WHERE kv.So_tai_khoan IN (
        SELECT So_tai_khoan FROM Tai_khoan WHERE CCCD = p_cccd
    );

    SELECT kv.Ma_khoan_vay,
           kv.Lai_suat,
           kv.Khoan_vay,
           kv.Thoi_han_vay,
           kv.Ky_han_tra_goc,
           kv.Trang_thai,
           kv.So_tai_khoan,
           kv.Ma_so
    FROM Khoan_vay kv
    JOIN Tai_khoan tk ON tk.So_tai_khoan = kv.So_tai_khoan
    WHERE tk.CCCD = p_cccd
    ORDER BY kv.Ma_khoan_vay;

    SELECT ttv.Ma_thanh_toan,
           ttv.Ma_khoan_vay,
           ttv.Ma_giao_dich,
           ttv.Ngay_tra_thuc_te,
           ttv.Ngay_tra_du_kien,
           ttv.So_tien_goc_tra,
           ttv.So_tien_lai_tra,
           ttv.So_tien_phai_tra,
           kv.So_tai_khoan
    FROM Thanh_toan_khoan_vay ttv
    JOIN Khoan_vay kv ON kv.Ma_khoan_vay = ttv.Ma_khoan_vay
    JOIN Tai_khoan tk ON tk.So_tai_khoan = kv.So_tai_khoan
    WHERE tk.CCCD = p_cccd
    ORDER BY ttv.Ngay_tra_du_kien DESC, ttv.Ma_thanh_toan DESC;
END$$

DROP PROCEDURE IF EXISTS api_pay_repayment$$
CREATE PROCEDURE api_pay_repayment(
    IN p_cccd VARCHAR(12),
    IN p_repayment_id VARCHAR(10),
    IN p_amount DECIMAL(15,2)
)
BEGIN
    DECLARE v_due_date DATE;
    DECLARE v_total_due DECIMAL(15,2);
    DECLARE v_paid_date DATE;
    DECLARE v_account_number VARCHAR(10);
    DECLARE v_so_du DECIMAL(15,2);
    DECLARE v_loan_id VARCHAR(10);
    DECLARE v_transaction_id VARCHAR(10);
    DECLARE v_pay_amount DECIMAL(15,2);
    DECLARE v_repayment_status VARCHAR(20);
    DECLARE v_loan_status VARCHAR(20);

    SELECT ttv.Ma_khoan_vay,
           ttv.Ngay_tra_du_kien,
           ttv.Ngay_tra_thuc_te,
           IFNULL(ttv.So_tien_phai_tra, 0),
           kv.So_tai_khoan,
           IFNULL(ttt.So_du, 0)
    INTO v_loan_id, v_due_date, v_paid_date, v_total_due, v_account_number, v_so_du
    FROM Thanh_toan_khoan_vay ttv
    JOIN Khoan_vay kv ON kv.Ma_khoan_vay = ttv.Ma_khoan_vay
    JOIN Tai_khoan tk ON tk.So_tai_khoan = kv.So_tai_khoan
    LEFT JOIN Tai_khoan_thanh_toan ttt ON ttt.So_tai_khoan = kv.So_tai_khoan
    WHERE ttv.Ma_thanh_toan = p_repayment_id
      AND tk.CCCD = p_cccd
    LIMIT 1;

    IF v_loan_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Repayment record not found for this customer.';
    END IF;

    IF v_paid_date IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'This installment is already fully paid.';
    END IF;

    IF v_total_due <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No outstanding amount for this installment.';
    END IF;

    IF p_amount IS NULL OR p_amount = 0 THEN
        SET v_pay_amount = v_total_due;
    ELSE
        SET v_pay_amount = p_amount;
    END IF;

    IF v_pay_amount <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Payment amount must be greater than 0.';
    END IF;

    IF ABS(v_pay_amount - v_total_due) > 0.001 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Installment must be paid in full under current schema.';
    END IF;

    IF v_so_du < v_pay_amount THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Insufficient balance for repayment.';
    END IF;

    CALL api_generate_transaction_id(v_transaction_id);

    CALL ThemGiaoDich(
        v_transaction_id,
        v_account_number,
        '0000000001',
        v_pay_amount,
        0,
        'Loan',
        NULL,
        p_repayment_id,
        v_loan_id
    );

    IF v_due_date IS NOT NULL AND CURDATE() <= v_due_date THEN
        SET v_repayment_status = 'Da_thanh_toan';
    ELSE
        SET v_repayment_status = 'Qua_han';
    END IF;

    UPDATE Khoan_vay kv
    JOIN (
        SELECT ttv.Ma_khoan_vay,
               COUNT(*) AS total_rows,
               SUM(CASE WHEN ttv.Ngay_tra_thuc_te IS NOT NULL THEN 1 ELSE 0 END) AS paid_rows,
               SUM(CASE WHEN ttv.Ngay_tra_thuc_te IS NULL AND ttv.Ngay_tra_du_kien < CURDATE() THEN 1 ELSE 0 END) AS overdue_rows
        FROM Thanh_toan_khoan_vay ttv
        WHERE ttv.Ma_khoan_vay = v_loan_id
        GROUP BY ttv.Ma_khoan_vay
    ) stats ON stats.Ma_khoan_vay = kv.Ma_khoan_vay
    SET kv.Trang_thai = CASE
        WHEN stats.total_rows > 0 AND stats.paid_rows >= stats.total_rows THEN 'Da_thanh_toan'
        WHEN stats.overdue_rows > 0 THEN 'Qua_han'
        ELSE 'Hoat_dong'
    END
    WHERE kv.Ma_khoan_vay = v_loan_id;

    SELECT kv.Trang_thai INTO v_loan_status
    FROM Khoan_vay kv
    WHERE kv.Ma_khoan_vay = v_loan_id
    LIMIT 1;

    SELECT v_transaction_id AS transactionId,
           v_pay_amount AS paymentAmount,
           v_repayment_status AS repaymentStatus,
           v_loan_status AS loanStatus;
END$$

DROP PROCEDURE IF EXISTS api_auto_debit$$
CREATE PROCEDURE api_auto_debit(
    IN p_cccd VARCHAR(12)
)
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE v_repayment_id VARCHAR(10);
    DECLARE v_loan_id VARCHAR(10);
    DECLARE v_due_date DATE;
    DECLARE v_amount DECIMAL(15,2);
    DECLARE v_account_number VARCHAR(10);
    DECLARE v_so_du DECIMAL(15,2);
    DECLARE v_transaction_id VARCHAR(10);

    DECLARE v_processed INT DEFAULT 0;
    DECLARE v_paid INT DEFAULT 0;
    DECLARE v_failed INT DEFAULT 0;
    DECLARE v_overdue INT DEFAULT 0;

    DECLARE cur CURSOR FOR
        SELECT ttv.Ma_thanh_toan,
               ttv.Ma_khoan_vay,
               ttv.Ngay_tra_du_kien,
               IFNULL(ttv.So_tien_phai_tra, 0),
               kv.So_tai_khoan,
               IFNULL(ttt.So_du, 0)
        FROM Thanh_toan_khoan_vay ttv
        JOIN Khoan_vay kv ON kv.Ma_khoan_vay = ttv.Ma_khoan_vay
        JOIN Tai_khoan tk ON tk.So_tai_khoan = kv.So_tai_khoan
        LEFT JOIN Tai_khoan_thanh_toan ttt ON ttt.So_tai_khoan = kv.So_tai_khoan
        WHERE tk.CCCD = p_cccd
          AND ttv.Ngay_tra_thuc_te IS NULL
          AND ttv.Ngay_tra_du_kien <= CURDATE()
        ORDER BY ttv.Ngay_tra_du_kien, ttv.Ma_thanh_toan;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_impacted_loans (
        loan_id VARCHAR(10) PRIMARY KEY
    );

    OPEN cur;
    read_loop: LOOP
        FETCH cur INTO v_repayment_id, v_loan_id, v_due_date, v_amount, v_account_number, v_so_du;
        IF done THEN
            LEAVE read_loop;
        END IF;

        SET v_processed = v_processed + 1;

        IF v_amount <= 0 THEN
            INSERT IGNORE INTO tmp_impacted_loans (loan_id) VALUES (v_loan_id);
            ITERATE read_loop;
        END IF;

        IF v_so_du >= v_amount THEN
            CALL api_generate_transaction_id(v_transaction_id);

            CALL ThemGiaoDich(
                v_transaction_id,
                v_account_number,
                '0000000001',
                v_amount,
                0,
                'Loan',
                NULL,
                v_repayment_id,
                v_loan_id
            );

            SET v_paid = v_paid + 1;
        ELSE
            SET v_failed = v_failed + 1;
            IF v_due_date IS NOT NULL AND v_due_date < CURDATE() THEN
                SET v_overdue = v_overdue + 1;
            END IF;
        END IF;

        INSERT IGNORE INTO tmp_impacted_loans (loan_id) VALUES (v_loan_id);
    END LOOP;
    CLOSE cur;

    UPDATE Khoan_vay kv
    JOIN (
        SELECT ttv.Ma_khoan_vay,
               COUNT(*) AS total_rows,
               SUM(CASE WHEN ttv.Ngay_tra_thuc_te IS NOT NULL THEN 1 ELSE 0 END) AS paid_rows,
               SUM(CASE WHEN ttv.Ngay_tra_thuc_te IS NULL AND ttv.Ngay_tra_du_kien < CURDATE() THEN 1 ELSE 0 END) AS overdue_rows
        FROM Thanh_toan_khoan_vay ttv
        JOIN tmp_impacted_loans til ON til.loan_id = ttv.Ma_khoan_vay
        GROUP BY ttv.Ma_khoan_vay
    ) stats ON stats.Ma_khoan_vay = kv.Ma_khoan_vay
    SET kv.Trang_thai = CASE
        WHEN stats.total_rows > 0 AND stats.paid_rows >= stats.total_rows THEN 'Da_thanh_toan'
        WHEN stats.overdue_rows > 0 THEN 'Qua_han'
        ELSE 'Hoat_dong'
    END;

    DROP TEMPORARY TABLE IF EXISTS tmp_impacted_loans;

    SELECT v_processed AS processed,
           v_paid AS paid,
           v_overdue AS overdue,
           v_failed AS failed;
END$$

DROP PROCEDURE IF EXISTS api_create_deposit$$
CREATE PROCEDURE api_create_deposit(
    IN p_admin_ma_so VARCHAR(20),
    IN p_account_number VARCHAR(10),
    IN p_amount DECIMAL(15,2)
)
BEGIN
    DECLARE v_transaction_id VARCHAR(10);

    IF p_amount IS NULL OR p_amount <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Amount must be greater than 0.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM Quan_tri_vien WHERE Ma_so = p_admin_ma_so LIMIT 1) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Admin account is invalid.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM Tai_khoan_thanh_toan WHERE So_tai_khoan = p_account_number LIMIT 1) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Active payment account not found.';
    END IF;

    CALL api_generate_transaction_id(v_transaction_id);

    INSERT INTO Giao_dich
    (Ma_giao_dich, So_tai_khoan_gui, So_tai_khoan_nhan, So_tien, Phi_chuyen_tien, Thoi_gian, Phan_loai)
    VALUES (v_transaction_id, '0000000001', p_account_number, p_amount, 0, NOW(), 'Trans');

    SELECT v_transaction_id AS transactionId,
           ttt.So_du AS updatedBalance
    FROM Tai_khoan_thanh_toan ttt
    WHERE ttt.So_tai_khoan = p_account_number
    LIMIT 1;
END$$

DROP PROCEDURE IF EXISTS api_get_personal_info$$
CREATE PROCEDURE api_get_personal_info(
    IN p_cccd VARCHAR(12),
    IN p_account_number VARCHAR(10)
)
BEGIN
    SELECT n.CCCD, n.Ho, n.Ten_lot, n.Ten, n.Quoc_tich, n.Gioi_tinh, n.Ngay_sinh,
           gt.CCCD_Nguoi_gioi_thieu AS Nguoi_gioi_thieu
    FROM Nguoi n
    LEFT JOIN Gioi_thieu gt ON gt.CCCD_Khach_moi = n.CCCD
    WHERE n.CCCD = p_cccd
    LIMIT 1;

    SELECT So_dien_thoai
    FROM So_dien_thoai
    WHERE CCCD = p_cccd
    ORDER BY So_dien_thoai;

    SELECT Tk_email
    FROM Tai_khoan_email
    WHERE CCCD = p_cccd
    ORDER BY Tk_email;

    IF p_account_number IS NULL OR p_account_number = '' THEN
        SELECT DISTINCT t.Ma_so_the, lt.Ten_the, t.Ngay_het_han, t.So_tai_khoan, tk.Ten_khach_hang
        FROM The t
        JOIN Loai_the lt ON lt.Ma_so_the = t.Ma_so_the
        JOIN Tai_khoan tk ON tk.So_tai_khoan = t.So_tai_khoan
        WHERE tk.CCCD = p_cccd
        ORDER BY t.Ngay_het_han DESC, lt.Ten_the;
    ELSE
        SELECT DISTINCT t.Ma_so_the, lt.Ten_the, t.Ngay_het_han, t.So_tai_khoan, tk.Ten_khach_hang
        FROM The t
        JOIN Loai_the lt ON lt.Ma_so_the = t.Ma_so_the
        JOIN Tai_khoan tk ON tk.So_tai_khoan = t.So_tai_khoan
        WHERE tk.CCCD = p_cccd
          AND t.So_tai_khoan = p_account_number
        ORDER BY t.Ngay_het_han DESC, lt.Ten_the;
    END IF;
END$$

DROP PROCEDURE IF EXISTS api_admin_search_customers$$
CREATE PROCEDURE api_admin_search_customers(
    IN p_query VARCHAR(50)
)
BEGIN
    DECLARE v_wildcard VARCHAR(60);
    SET v_wildcard = CONCAT('%', p_query, '%');

    SELECT tk.Ten_khach_hang,
           tk.So_tai_khoan,
           tk.CCCD,
           tk.Trang_thai,
           CASE WHEN tsk.So_tai_khoan IS NOT NULL THEN 'savings' ELSE 'payment' END AS account_type,
           COALESCE(ttt.So_du, tsk.So_tien, 0) AS So_du,
           IFNULL(ttt.Han_muc, 0) AS Han_muc,
           GROUP_CONCAT(DISTINCT sdt.So_dien_thoai ORDER BY sdt.So_dien_thoai SEPARATOR ', ') AS phones
    FROM Tai_khoan tk
    LEFT JOIN Tai_khoan_thanh_toan ttt ON ttt.So_tai_khoan = tk.So_tai_khoan
    LEFT JOIN Tai_khoan_tiet_kiem tsk ON tsk.So_tai_khoan = tk.So_tai_khoan
    LEFT JOIN So_dien_thoai sdt ON sdt.CCCD = tk.CCCD
    WHERE tk.CCCD IN (
        SELECT DISTINCT tk2.CCCD
        FROM Tai_khoan tk2
        WHERE tk2.Ten_khach_hang LIKE v_wildcard
           OR tk2.So_tai_khoan = p_query
           OR tk2.CCCD = p_query
    )
    GROUP BY tk.Ten_khach_hang, tk.So_tai_khoan, tk.CCCD, tk.Trang_thai, CASE WHEN tsk.So_tai_khoan IS NOT NULL THEN 'savings' ELSE 'payment' END, ttt.So_du, ttt.Han_muc, tsk.So_tien
    ORDER BY tk.Ten_khach_hang, tk.So_tai_khoan
    LIMIT 50;
END$$

DROP PROCEDURE IF EXISTS api_admin_list_promotions$$
CREATE PROCEDURE api_admin_list_promotions()
BEGIN
    SELECT km.Ma,
           km.Ten_chuong_trinh,
           km.Gia_tri,
           km.So_tien_toi_thieu,
           1 AS So_luong,
           km.Ngay_bat_dau,
           km.Ngay_ket_thuc,
           km.Loai
    FROM Khuyen_mai km
    WHERE CURDATE() BETWEEN km.Ngay_bat_dau AND km.Ngay_ket_thuc
      AND EXISTS (SELECT 1 FROM Cap_nhat cn WHERE cn.Ma = km.Ma)
    ORDER BY km.Ngay_ket_thuc, km.Ma;
END$$

DROP PROCEDURE IF EXISTS api_admin_assign_promotion$$
CREATE PROCEDURE api_admin_assign_promotion(
    IN p_account_number VARCHAR(10),
    IN p_promotion_code VARCHAR(10),
    IN p_admin_ma_so VARCHAR(20)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Quan_tri_vien WHERE Ma_so = p_admin_ma_so LIMIT 1) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Admin account is invalid.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM Tai_khoan WHERE So_tai_khoan = p_account_number AND Trang_thai = 'ACTIVE'
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Target account is not active or does not exist.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM Khuyen_mai
        WHERE Ma = p_promotion_code
          AND CURDATE() BETWEEN Ngay_bat_dau AND Ngay_ket_thuc
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Promotion does not exist or is not active.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM Cap_nhat WHERE Ma = p_promotion_code) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Promotion has not been updated by any administrator yet.';
    END IF;

    IF EXISTS (SELECT 1 FROM So_huu WHERE Ma = p_promotion_code AND So_tai_khoan = p_account_number) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'This promotion has already been assigned to this account.';
    END IF;

    INSERT INTO So_huu (Ma, So_tai_khoan)
    VALUES (p_promotion_code, p_account_number);
END$$

DROP PROCEDURE IF EXISTS api_get_account_status$$
CREATE PROCEDURE api_get_account_status(
    IN p_account_number VARCHAR(10)
)
BEGIN
    SELECT Trang_thai
    FROM Tai_khoan
    WHERE So_tai_khoan = p_account_number
    LIMIT 1;
END$$

DROP PROCEDURE IF EXISTS api_admin_personal_info$$
CREATE PROCEDURE api_admin_personal_info(
    IN p_admin_ma_so VARCHAR(20)
)
BEGIN
    SELECT qtv.Ma_so,
           qtv.Ten_dang_nhap,
           n.CCCD,
           n.Ho,
           n.Ten_lot,
           n.Ten,
           n.Gioi_tinh,
           n.Quoc_tich,
           n.Ngay_sinh
    FROM Quan_tri_vien qtv
    JOIN Nguoi n ON n.CCCD = qtv.CCCD
    WHERE qtv.Ma_so = p_admin_ma_so
    LIMIT 1;

    SELECT So_dien_thoai
    FROM So_dien_thoai
    WHERE CCCD = (
        SELECT CCCD FROM Quan_tri_vien WHERE Ma_so = p_admin_ma_so LIMIT 1
    )
    ORDER BY So_dien_thoai;

    SELECT Tk_email
    FROM Tai_khoan_email
    WHERE CCCD = (
        SELECT CCCD FROM Quan_tri_vien WHERE Ma_so = p_admin_ma_so LIMIT 1
    )
    ORDER BY Tk_email;
END$$

DROP PROCEDURE IF EXISTS api_admin_get_loan$$
CREATE PROCEDURE api_admin_get_loan(
    IN p_loan_id VARCHAR(10)
)
BEGIN
    SELECT kv.Ma_khoan_vay,
           kv.Lai_suat,
           kv.Khoan_vay,
           kv.Thoi_han_vay,
           kv.Ky_han_tra_goc,
           kv.Trang_thai,
           kv.So_tai_khoan,
           kv.Ma_so,
           tk.Ten_khach_hang,
           tk.CCCD
    FROM Khoan_vay kv
    JOIN Tai_khoan tk ON tk.So_tai_khoan = kv.So_tai_khoan
    WHERE kv.Ma_khoan_vay = p_loan_id
    LIMIT 1;
END$$

DROP PROCEDURE IF EXISTS api_get_total_interest$$
CREATE PROCEDURE api_get_total_interest(
    IN p_account_number VARCHAR(10)
)
BEGIN
    SELECT calculate_total_interest(p_account_number) AS total_interest;
END$$

DROP PROCEDURE IF EXISTS api_get_loans_with_debt$$
CREATE PROCEDURE api_get_loans_with_debt(
    IN p_cccd VARCHAR(12)
)
BEGIN
    SELECT kv.Ma_khoan_vay,
           kv.Khoan_vay AS Tong_vay,
           kv.Lai_suat,
           kv.Thoi_han_vay,
           kv.Ky_han_tra_goc,
           kv.Trang_thai,
           kv.Ngay_tao_khoan_vay,
           kv.So_tai_khoan,
           TinhDuNoConLai(kv.Ma_khoan_vay) AS du_no_con_lai,
           (kv.Khoan_vay - TinhDuNoConLai(kv.Ma_khoan_vay)) AS da_tra
    FROM Khoan_vay kv
    JOIN Tai_khoan tk ON tk.So_tai_khoan = kv.So_tai_khoan
    WHERE tk.CCCD = p_cccd
    ORDER BY kv.Ma_khoan_vay;
END$$

DROP PROCEDURE IF EXISTS api_get_loan_statistics$$
CREATE PROCEDURE api_get_loan_statistics(
    IN p_cccd VARCHAR(12),
    IN p_tong_da_tra_min DECIMAL(15,2)
)
BEGIN
    SELECT kv.Ma_khoan_vay,
           kv.So_tai_khoan,
           kv.Khoan_vay AS Tong_von_vay,
           SUM(tt.So_tien_goc_tra) AS Tong_goc_da_tra,
           (kv.Khoan_vay - SUM(tt.So_tien_goc_tra)) AS Du_no_goc_con_lai
    FROM Khoan_vay kv
    LEFT JOIN Thanh_toan_khoan_vay tt ON kv.Ma_khoan_vay = tt.Ma_khoan_vay
    JOIN Tai_khoan tk ON tk.So_tai_khoan = kv.So_tai_khoan
    WHERE tk.CCCD = p_cccd
      AND tt.Ngay_tra_thuc_te IS NOT NULL
      AND kv.Trang_thai IN ('Hoat_dong', 'Qua_han', 'Da_thanh_toan')
    GROUP BY kv.Ma_khoan_vay, kv.So_tai_khoan, kv.Khoan_vay
    HAVING SUM(tt.So_tien_goc_tra) >= IFNULL(p_tong_da_tra_min, 0)
    ORDER BY Du_no_goc_con_lai DESC;
END$$

DROP PROCEDURE IF EXISTS api_check_eligibility$$
CREATE PROCEDURE api_check_eligibility(
    IN p_cccd VARCHAR(12)
)
BEGIN
    SELECT check_loan_eligibility(p_cccd) AS eligibility_status;
END$$

DELIMITER ;