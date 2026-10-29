
DELIMITER $$

CREATE TRIGGER chk_union_tkgd 
BEFORE INSERT ON Tai_khoan_giao_dich
FOR EACH ROW
BEGIN
	IF NEW.Loai_tk = 'Noi_bo' THEN
		IF NOT EXISTS (SELECT 1 FROM Tai_khoan_thanh_toan WHERE So_tai_khoan = NEW.So_tai_khoan) THEN
			SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'So_tai_khoan khong ton tai trong Tai_khoan_thanh_toan';
		END IF;
	ELSEIF NEW.Loai_tk = 'Ngoai' THEN 
		IF NOT EXISTS (SELECT 1 FROM Tai_khoan_ngoai WHERE So_tai_khoan = NEW.So_tai_khoan) THEN 
			SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'So_tai_khoan khong ton tai trong Tai_khoan_ngoai';
		END IF;
	END IF;
END $$

CREATE TRIGGER chk_union_tkgd_update 
BEFORE UPDATE ON Tai_khoan_giao_dich
FOR EACH ROW
BEGIN 
	IF NEW.Loai_tk = 'Noi_bo' THEN
		IF NOT EXISTS (SELECT 1 FROM Tai_khoan_thanh_toan WHERE So_tai_khoan = New.So_tai_khoan) THEN 
			SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'So_tai_khoan khong ton tai trong Tai_khoan_thanh_toan';
		END IF;
	ELSEIF NEW.Loai_tk = 'Ngoai' THEN 
		IF NOT EXISTS (SELECT 1 FROM Tai_khoan_ngoai WHERE So_tai_khoan = NEW.So_tai_khoan) THEN 
			SIGNAL SQLSTATE '45000'
			SET MESSAGE_TEXT = 'So_tai_khoan khong ton tai trong Tai_khoan_ngoai';
		END IF;
	END IF;
END $$
-- Kiem tra tuoi
CREATE TRIGGER check_age
BEFORE INSERT ON Nguoi
FOR EACH ROW
BEGIN 
	IF TIMESTAMPDIFF(YEAR, NEW.Ngay_sinh, CURDATE()) < 18 THEN
		SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Nguoi dung chua du tuoi';
	END IF;
END $$

CREATE TRIGGER check_age_update
BEFORE UPDATE ON Nguoi
FOR EACH ROW
BEGIN 
	IF TIMESTAMPDIFF(YEAR, NEW.Ngay_sinh, CURDATE()) < 18 THEN
		SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Nguoi dung chua du tuoi';
	END IF;
END $$

-- Kiem tra han muc 
CREATE TRIGGER check_han_muc
BEFORE INSERT ON Giao_dich
FOR EACH ROW
BEGIN 
	DECLARE han_muc DECIMAL(15,2);
    DECLARE loai_tk ENUM('Noi_bo','Ngoai');
    
    SELECT Loai_tk INTO loai_tk
    FROM Tai_khoan_giao_dich
    WHERE So_tai_khoan = NEW.So_tai_khoan_gui;
    
    IF loai_tk = 'Noi_bo' THEN 
		SELECT Han_muc INTO han_muc
        FROM Tai_khoan_thanh_toan 
        WHERE So_tai_khoan = NEW.So_tai_khoan_gui;
        
        IF (NEW.So_tien + NEW.Phi_chuyen_tien) > han_muc THEN
			SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Chuyen tien vuot qua han muc cho phep';
		END IF;
	END IF;
END $$
     
CREATE TRIGGER check_han_muc_update
BEFORE UPDATE ON Giao_dich
FOR EACH ROW
BEGIN 
	DECLARE han_muc DECIMAL(15,2);
    DECLARE loai_tk ENUM('Noi_bo','Ngoai');
    
    SELECT Loai_tk INTO loai_tk
    FROM Tai_khoan_giao_dich
    WHERE So_tai_khoan = NEW.So_tai_khoan_gui;
    
    IF loai_tk = 'Noi_bo' THEN 
		SELECT Han_muc INTO han_muc
        FROM Tai_khoan_thanh_toan 
        WHERE So_tai_khoan = NEW.So_tai_khoan_gui;
        
        IF (NEW.So_tien + NEW.Phi_chuyen_tien) > han_muc THEN
			SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Chuyen tien vuot qua han muc cho phep';
		END IF;
	END IF;
END $$
-- Kiem tra du no
CREATE TRIGGER check_du_no
BEFORE INSERT ON Thanh_toan_khoan_vay
FOR EACH ROW
BEGIN 
	DECLARE tong_vay DECIMAL(15,2);
    DECLARE da_tra_goc DECIMAL(15,2);
    
    SELECT Khoan_vay INTO tong_vay 
    FROM Khoan_vay 
    WHERE Ma_khoan_vay = NEW.Ma_khoan_vay;
    
    SELECT IFNULL(SUM(So_tien_goc_tra),0) INTO da_tra_goc
    FROM Thanh_toan_khoan_vay 
    WHERE Ma_khoan_vay = NEW.Ma_khoan_vay;
    
    IF (da_tra_goc + NEW.So_tien_goc_tra) > tong_vay THEN 
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = 'So tien thanh toan vuot khoan vay';
	END IF;
END $$

 
CREATE TRIGGER check_du_no_update
BEFORE UPDATE ON Thanh_toan_khoan_vay
FOR EACH ROW
BEGIN 
	DECLARE tong_vay DECIMAL(15,2);
    DECLARE da_tra_goc DECIMAL(15,2);
    
    SELECT Khoan_vay INTO tong_vay 
    FROM Khoan_vay 
    WHERE Ma_khoan_vay = NEW.Ma_khoan_vay;
    
    -- Lấy tổng đã trả, KHÔNG tính row hiện tại (dùng Ma_thanh_toan để loại trừ)
    SELECT IFNULL(SUM(So_tien_goc_tra), 0) INTO da_tra_goc
    FROM Thanh_toan_khoan_vay 
    WHERE Ma_khoan_vay = NEW.Ma_khoan_vay
      AND Ma_thanh_toan <> OLD.Ma_thanh_toan;  -- loại row đang UPDATE
    
    -- Cộng NEW value vào để kiểm tra
    IF (da_tra_goc + NEW.So_tien_goc_tra) > tong_vay THEN 
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = 'So tien thanh toan vuot khoan vay';
	END IF;
END $$  
 
-- Kiem tra hieu luc the
CREATE TRIGGER Ngay_het_han_the
BEFORE INSERT ON The
FOR EACH ROW
BEGIN 
    IF TIMESTAMPDIFF(YEAR, NEW.Ngay_mo_the, NEW.Ngay_het_han) < 1 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Ngay mo the va ngay het han phai cach nhau it nhat 1 nam';
    END IF;
END $$

CREATE TRIGGER Ngay_het_han_the_update
BEFORE UPDATE ON The
FOR EACH ROW
BEGIN 
    IF TIMESTAMPDIFF(YEAR, NEW.Ngay_mo_the, NEW.Ngay_het_han) < 1 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Ngay mo the va ngay het han phai cach nhau it nhat 1 nam';
    END IF;
END $$

-- Ngay tra thuc te
CREATE TRIGGER Ngay_tra_thuc_te_update
BEFORE UPDATE ON Thanh_toan_khoan_vay
FOR EACH ROW
BEGIN 
	DECLARE Ngay_tao DATE;
    SELECT Ngay_tao_khoan_vay INTO Ngay_tao
    FROM Khoan_vay
    WHERE NEW.Ma_khoan_vay = Ma_khoan_vay;
	IF ngay_tao IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Khoan vay khong ton tai';
    END IF;

    IF NEW.Ngay_tra_thuc_te IS NOT NULL AND Ngay_tao > NEW.Ngay_tra_thuc_te THEN 
		SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Ngay thanh toan phai lon hon ngay tao khoan vay';
	END IF;
END $$
-- Kiem tra so tien thanh toan hoa don = hoa don 
CREATE TRIGGER Thanh_toan_hoa_don_update
BEFORE UPDATE ON Hoa_don
FOR EACH ROW
BEGIN 
    DECLARE So_tien_gd DECIMAL(15,2);
    DECLARE phan_loai_gd VARCHAR(10);

    IF OLD.Ma_giao_dich IS NULL AND NEW.Ma_giao_dich IS NOT NULL THEN

        SELECT So_tien, Phan_loai 
        INTO So_tien_gd, phan_loai_gd
        FROM Giao_dich
        WHERE Ma_giao_dich = NEW.Ma_giao_dich;

        IF So_tien_gd IS NULL THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Khong tim thay giao dich tuong ung';
        END IF;

        IF phan_loai_gd <> 'Bill' THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Giao dich phan loai khong phai Bill';
        END IF;

        IF NEW.So_tien_thanh_toan < So_tien_gd THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'So tien hoa don phai bang so tien giao dich';
        END IF;

    END IF;
END $$

-- Khong cho mo the khi tai khoan khong hoat dong
CREATE TRIGGER check_trang_thai_tao_the
BEFORE INSERT ON The
FOR EACH ROW
BEGIN
    DECLARE st VARCHAR(50);

    SELECT Trang_thai INTO st
    FROM Tai_khoan
    WHERE So_tai_khoan = NEW.So_tai_khoan;

    IF st <> 'ACTIVE' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Tai khoan khong hoat dong';
    END IF;
END$$

-- Giao dịch chỉ hoạt động khi trong trang thái hoạt động
CREATE TRIGGER check_trang_thai_tai_khoan_giao_dich
BEFORE INSERT ON Giao_dich
FOR EACH ROW
BEGIN
	DECLARE stk VARCHAR(15);
    DECLARE phan_loai VARCHAR(15);
    DECLARE st VARCHAR(15);
    DECLARE sodu DECIMAL(15,2);
	SELECT So_tai_khoan, Loai_tk INTO stk, phan_loai
    FROM Tai_khoan_giao_dich 
    WHERE So_tai_khoan = NEW.So_tai_khoan_gui;
    IF stk IS NULL THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = 'Tai khoan gui khong ton tai';
	END IF;
    IF phan_loai = 'Noi_bo' AND stk IS NOT NULL THEN
		SELECT So_du INTO sodu 
        FROM Tai_khoan_thanh_toan
        WHERE So_tai_khoan = stk;
        IF New.So_tai_khoan_gui = stk AND (NEW.So_tien + NEW.Phi_chuyen_tien) > sodu THEN
			SIGNAL SQLSTATE '45000'
			SET MESSAGE_TEXT = 'So tien lon hon so du';
		END IF;
		SELECT Trang_thai INTO st
		FROM Tai_khoan
		WHERE So_tai_khoan = stk;
		IF st <> 'ACTIVE' THEN
			SIGNAL SQLSTATE '45000'
			SET MESSAGE_TEXT = 'Tai khoan khong hoat dong';
		END IF;
	END IF;
END$$
DELIMITER $$

-- Khoản vay chỉ hoạt động khi trong trang thái hoạt động
CREATE TRIGGER check_trang_thai_tai_khoan_khoan_vay
BEFORE INSERT ON Khoan_vay
FOR EACH ROW
BEGIN
	DECLARE stk VARCHAR(15);
    DECLARE st VARCHAR(15);
	SELECT So_tai_khoan INTO stk
    FROM Tai_khoan 
    WHERE So_tai_khoan = NEW.So_tai_khoan;
    IF stk IS NULL THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = 'Tai khoan gui khong ton tai';
	END IF;
	SELECT Trang_thai INTO st
	FROM Tai_khoan
	WHERE So_tai_khoan = stk;
	IF st <> 'ACTIVE' THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = 'Tai khoan khong hoat dong';
	END IF;
END$$

-- Thanh toan hoa don chỉ hoạt động khi trong trang thái hoạt động
CREATE TRIGGER check_trang_thai_tai_khoan_thanh_toan_hoa_don
BEFORE INSERT ON Hoa_don
FOR EACH ROW
BEGIN
	DECLARE stk VARCHAR(15);
    DECLARE st VARCHAR(15);
	SELECT So_tai_khoan INTO stk
    FROM Tai_khoan 
    WHERE So_tai_khoan = NEW.So_tai_khoan;
    IF stk IS NULL THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = 'Tai khoan gui khong ton tai';
	END IF;
	SELECT Trang_thai INTO st
	FROM Tai_khoan
	WHERE So_tai_khoan = stk;
	IF st <> 'ACTIVE' THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = 'Tai khoan khong hoat dong';
	END IF;
END$$


CREATE TRIGGER check_password
BEFORE INSERT ON Tai_khoan
FOR EACH ROW
BEGIN
    -- độ dài >= 8
    IF CHAR_LENGTH(NEW.Mat_khau) < 8 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Mat khau phai co it nhat 8 ky tu';
    END IF;

    -- có chữ thường
    IF NEW.Mat_khau NOT REGEXP '[a-z]' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Mat khau phai co chu thuong';
    END IF;

    -- có chữ hoa
    IF NEW.Mat_khau NOT REGEXP '[A-Z]' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Mat khau phai co chu hoa';
    END IF;

    -- có số
    IF NEW.Mat_khau NOT REGEXP '[0-9]' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Mat khau phai co chu so';
    END IF;

    -- có ký tự đặc biệt
    IF NEW.Mat_khau NOT REGEXP '[^A-Za-z0-9]' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Mat khau phai co ky tu dac biet';
    END IF;

END$$



CREATE TRIGGER check_trang_thai_khoan_vay
BEFORE INSERT ON Thanh_toan_khoan_vay
FOR EACH ROW
BEGIN
    DECLARE st VARCHAR(20);

    SELECT Trang_thai INTO st
    FROM Khoan_vay
    WHERE Ma_khoan_vay = NEW.Ma_khoan_vay;

    -- không tồn tại khoản vay
    IF st IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Khoan vay khong ton tai';
    END IF;

    -- không cho thanh toán nếu đã hoàn tất
    IF st = 'Da_thanh_toan' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Khoan vay da thanh toan, khong the tra tiep';
    END IF;

END$$

CREATE TRIGGER tinh_so_tien_phai_tra
BEFORE INSERT ON Thanh_toan_khoan_vay
FOR EACH ROW
BEGIN
    SET NEW.So_tien_phai_tra = NEW.So_tien_goc_tra + NEW.So_tien_lai_tra;
END $$

CREATE TRIGGER tinh_so_tien_phai_tra_update
BEFORE UPDATE ON Thanh_toan_khoan_vay
FOR EACH ROW
BEGIN
    SET NEW.So_tien_phai_tra = NEW.So_tien_goc_tra + NEW.So_tien_lai_tra;
END $$




CREATE TRIGGER Tru_tien_tai_khoan
AFTER INSERT ON Giao_dich
FOR EACH ROW
BEGIN
    -- trừ tiền tài khoản gửi
    UPDATE Tai_khoan_thanh_toan
    SET So_du = So_du - (NEW.So_tien + NEW.Phi_chuyen_tien)
    WHERE So_tai_khoan = NEW.So_tai_khoan_gui;

    -- cộng tiền tài khoản nhận (nếu là tài khoản nội bộ)
    UPDATE Tai_khoan_thanh_toan
    SET So_du = So_du + NEW.So_tien
    WHERE So_tai_khoan = NEW.So_tai_khoan_nhan;

END$$

CREATE TRIGGER apply_khuyen_mai
BEFORE INSERT ON Ap_dung
FOR EACH ROW
BEGIN
    DECLARE loai VARCHAR(10);
    DECLARE tien_gd DECIMAL(15,2);
    DECLARE gia_tri_km DECIMAL(15,2);
    DECLARE min_tien DECIMAL(15,2);
    DECLARE ngay_bd DATE;
    DECLARE ngay_kt DATE;

    -- lấy thông tin giao dịch
    SELECT Phan_loai, So_tien
    INTO loai, tien_gd
    FROM Giao_dich
    WHERE Ma_giao_dich = NEW.Ma_giao_dich;

    IF loai IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Giao dich khong ton tai';
    END IF;

    -- chỉ áp dụng cho Bill
    IF loai <> 'Bill' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Chi ap dung khuyen mai cho Bill';
    END IF;

    -- lấy thông tin khuyến mãi
    SELECT Gia_tri, So_tien_toi_thieu, Ngay_bat_dau, Ngay_ket_thuc
    INTO gia_tri_km, min_tien, ngay_bd, ngay_kt
    FROM Khuyen_mai
    WHERE Ma = NEW.Ma;

    IF gia_tri_km IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Khuyen mai khong ton tai';
    END IF;

    -- check điều kiện tiền tối thiểu
    IF tien_gd < min_tien THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Khong du dieu kien ap dung khuyen mai';
    END IF;

    -- check thời gian
    IF CURRENT_DATE NOT BETWEEN ngay_bd AND ngay_kt THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Khuyen mai het han hoac chua bat dau';
    END IF;

    -- không cho giảm quá số tiền
    IF gia_tri_km > tien_gd THEN
        SET gia_tri_km = tien_gd;
    END IF;

    -- giảm tiền giao dịch
    UPDATE Giao_dich
    SET So_tien = So_tien - gia_tri_km
    WHERE Ma_giao_dich = NEW.Ma_giao_dich;
END$$
DELIMITER ;

