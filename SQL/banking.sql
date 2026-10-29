USE banking;
DROP TABLE IF EXISTS Nguoi;
CREATE TABLE Nguoi
(
	CCCD VARCHAR(12) PRIMARY KEY,
	Ho VARCHAR(20),
    Ten_lot VARCHAR(20),
    Ten VARCHAR(20),
    Quoc_tich VARCHAR(50),
    Gioi_tinh ENUM('Nam','Nu') NOT NULL,
    Ngay_sinh DATE NOT NULL
);
DROP TABLE IF EXISTS So_dien_thoai;
CREATE TABLE So_dien_thoai
(
	CCCD VARCHAR(12) NOT NULL,
    So_dien_thoai VARCHAR(15) NOT NULL,
    PRIMARY KEY(CCCD, So_dien_thoai),
    CONSTRAINT fk_sdt_nguoi FOREIGN KEY (CCCD) REFERENCES Nguoi(CCCD)
    ON DELETE CASCADE
);

DROP TABLE IF EXISTS Tai_khoan_email;
CREATE TABLE Tai_khoan_email
(
	CCCD VARCHAR(12) NOT NULL,
    Tk_email VARCHAR(50) NOT NULL,
    PRIMARY KEY(CCCD, Tk_email),
    CONSTRAINT fk_email_nguoi FOREIGN KEY (CCCD) REFERENCES Nguoi(CCCD)
    ON DELETE CASCADE
);

DROP TABLE IF EXISTS Quan_tri_vien;
CREATE TABLE IF NOT EXISTS Quan_tri_vien
(
	Ma_so VARCHAR(20) PRIMARY KEY,
    CCCD VARCHAR(12) NOT NULL UNIQUE,
    Ten_dang_nhap VARCHAR(50) NOT NULL UNIQUE,
    Mat_khau VARCHAR(50) NOT NULL,
    Cap_do_truy_cap ENUM('1','2','3') NOT NULL,
    CONSTRAINT fk_qtv_nguoi FOREIGN KEY (CCCD) REFERENCES Nguoi(CCCD)
    ON DELETE CASCADE
);

DROP TABLE IF EXISTS Nguoi_dung;
CREATE TABLE  Nguoi_dung
(
	CCCD VARCHAR(12) PRIMARY KEY,
    CONSTRAINT fk_user_nguoi FOREIGN KEY (CCCD) REFERENCES Nguoi(CCCD)
    ON DELETE CASCADE
);

DROP TABLE IF EXISTS Gioi_thieu;
CREATE TABLE Gioi_thieu
(
	CCCD_Nguoi_gioi_thieu VARCHAR(12),
    CCCD_Khach_moi VARCHAR(12),
    PRIMARY KEY(CCCD_Nguoi_gioi_thieu, CCCD_Khach_moi),
    CONSTRAINT fk_gioi_thieu_nguoi FOREIGN KEY (CCCD_Nguoi_gioi_thieu) REFERENCES Nguoi(CCCD) ON DELETE CASCADE,
    CONSTRAINT fk_khach_moi_nguoi FOREIGN KEY (CCCD_Khach_moi) REFERENCES Nguoi(CCCD) ON DELETE CASCADE,
    CHECK(CCCD_Nguoi_gioi_thieu <> CCCD_Khach_moi)
);

DROP TABLE IF EXISTS Tai_khoan;
CREATE TABLE Tai_khoan
(
	So_tai_khoan VARCHAR(10) PRIMARY KEY,
    Ten_khach_hang VARCHAR(50) NOT NULL,
    Ten_dang_nhap VARCHAR(50) NOT NULL UNIQUE,
    Mat_khau VARCHAR(50) NOT NULL,
    CCCD VARCHAR(12) NOT NULL,
    Trang_thai ENUM('ACTIVE', 'DEACTIVE', 'REMOVED') NOT NULL,
    Ma_so VARCHAR(20) NOT NULL,
    CONSTRAINT fk_so_huu_tk_user FOREIGN KEY (CCCD) REFERENCES Nguoi(CCCD) ON DELETE CASCADE,
    CONSTRAINT fk_theo_doi_qtv_tk FOREIGN KEY (Ma_so) REFERENCES Quan_tri_vien(Ma_so) ON DELETE CASCADE
    );
    
    DROP TABLE IF EXISTS Tai_khoan_tiet_kiem;
    CREATE TABLE Tai_khoan_tiet_kiem
    (
		So_tai_khoan VARCHAR(10) PRIMARY KEY,
        Lai_suat DECIMAL(2,2) NOT NULL,
        Ky_han INT NOT NULL,
        Hinh_thuc_nhan ENUM('Online', 'Offline') NOT NULL,
        So_tien DECIMAL(15,2) NOT NULL,
        CONSTRAINT fk_tktk_tk FOREIGN KEY (So_tai_khoan) REFERENCES Tai_khoan(So_tai_khoan),
        CHECK(Lai_suat > 0.00 AND Lai_suat <= 0.20),
        CHECK(Ky_han > 0 AND Ky_han <= 36)
	);
    

	DROP TABLE IF EXISTS Tai_khoan_thanh_toan;
    CREATE TABLE Tai_khoan_thanh_toan
    (	
		So_tai_khoan VARCHAR(10) PRIMARY KEY,
        Han_muc DECIMAL(11,2) NOT NULL,
        So_du DECIMAL(15,2) NOT NULL,
        CONSTRAINT fk_tktt_tk FOREIGN KEY (So_tai_khoan) REFERENCES Tai_khoan(So_tai_khoan),
		CHECK(So_du >=0.00)
	);

    DROP TABLE IF EXISTS Tai_khoan_giao_dich;
    CREATE TABLE Tai_khoan_giao_dich
    (
		So_tai_khoan VARCHAR(20) PRIMARY KEY,
        Loai_tk ENUM('Noi_bo', 'Ngoai')
	);

    DROP TABLE IF EXISTS Giao_dich;
    CREATE TABLE Giao_dich
    (
		Ma_giao_dich VARCHAR(10) PRIMARY KEY,
        So_tai_khoan_gui VARCHAR(15) NOT NULL,
        So_tai_khoan_nhan VARCHAR(15) NOT NULL,
        So_tien DECIMAL(15,2) NOT NULL,
        Phi_chuyen_tien DECIMAL(15,2) NOT NULL,
        Thoi_gian DATETIME,
        Phan_loai ENUM('Trans','Bill','Loan') NOT NULL,
        CONSTRAINT fk_tai_khoan_gui FOREIGN KEY (So_tai_khoan_gui) REFERENCES Tai_khoan_giao_dich(So_tai_khoan),
        CONSTRAINT fk_tai_khoan_nhan FOREIGN KEY (So_tai_khoan_nhan) REFERENCES Tai_khoan_giao_dich(So_tai_khoan),
        CHECK(So_tien > 0 AND Phi_chuyen_tien < So_tien),
        CHECK(So_tai_khoan_gui <> So_tai_khoan_nhan)
	);
    
	DROP TABLE IF EXISTS Hoa_don;
    CREATE TABLE Hoa_don
    (
		Ma_hoa_don VARCHAR(10) PRIMARY KEY,
        So_tien_thanh_toan DECIMAL(15,2) NOT NULL,
        Loai_hoa_don ENUM('Dien', 'Nuoc', 'Quan_ly') NOT NULL,
        So_tai_khoan VARCHAR(10) NOT NULL,
		Ma_giao_dich VARCHAR(10),
		CONSTRAINT fk_thanh_toan_tk FOREIGN KEY (So_tai_khoan) REFERENCES Tai_khoan_thanh_toan(So_tai_khoan),
		CONSTRAINT fk_thanh_toan_giao_dich FOREIGN KEY (Ma_giao_dich) REFERENCES Giao_dich(Ma_giao_dich),
		CHECK (So_tien_thanh_toan > 0)
	);
        
	DROP TABLE IF EXISTS The;
	CREATE TABLE The
    (
		Ma_so_the VARCHAR(20) PRIMARY KEY,
        Ngay_mo_the DATE NOT NULL,
        Ngay_het_han DATE NOT NULL,
        So_tai_khoan VARCHAR(10),
        CONSTRAINT fk_lien_ket_the_tk FOREIGN KEY (So_tai_khoan) REFERENCES Tai_khoan_thanh_toan (So_tai_khoan)
	);
    
    DROP TABLE IF EXISTS Loai_the;
    CREATE TABLE Loai_the
    (
		Ten_the VARCHAR(50) NOT NULL,
        Ma_so_the VARCHAR(20) NOT NULL,
        PRIMARY KEY(Ten_the,Ma_so_the),
        CONSTRAINT fk_ma_so_the FOREIGN KEY (Ma_so_the) REFERENCES The(Ma_so_the)
	);

    DROP TABLE IF EXISTS Khoan_vay;
    CREATE TABLE Khoan_vay
    (
		Ma_khoan_vay VARCHAR(10) PRIMARY KEY,
        Lai_suat DECIMAL(2,2) NOT NULL,
        Khoan_vay DECIMAL(15,2) NOT NULL,
        Thoi_han_vay INT NOT NULL,
        Ky_han_tra_goc INT NOT NULL,
        So_tai_khoan VARCHAR(10) NOT NULL,
        Ma_so VARCHAR(20) NOT NULL,
        Trang_thai ENUM('Hoat_dong','Qua_han','Da_thanh_toan') NOT NULL,
        Ngay_tao_khoan_vay DATE NOT NULL,
        CONSTRAINT fk_dang_ki_vay_tk FOREIGN KEY (So_tai_khoan) REFERENCES Tai_khoan(So_tai_khoan),
        CONSTRAINT fk_phe_duyet_vay_qtv FOREIGN KEY (Ma_so) REFERENCES Quan_tri_vien(Ma_so),
        CHECK(Lai_suat BETWEEN 0.00 AND 0.20),
        CHECK(Thoi_han_vay > 0),
        CHECK(Ky_han_tra_goc > 0 AND Ky_han_tra_goc <= 36),
        CHECK(Thoi_han_vay % Ky_han_tra_goc = 0)
	);
    
    DROP TABLE IF EXISTS Thanh_toan_khoan_vay;
    CREATE TABLE Thanh_toan_khoan_vay 
    (
		Ma_thanh_toan VARCHAR(10) NOT NULL,
        Ma_khoan_vay VARCHAR(10) NOT NULL,
        Ngay_tra_thuc_te DATE,
        Ngay_tra_du_kien DATE NOT NULL,
        So_tien_goc_tra DECIMAL(15,2) NOT NULL,
        So_tien_lai_tra DECIMAL(15,2) NOT NULL,
        So_tien_phai_tra DECIMAL(15,2) NOT NULL,
        Ma_giao_dich VARCHAR(10) ,
        -- So tien phai tra (thuoc tinh dan xuat) = so tien goc tra + so tien lai tra
        PRIMARY KEY (Ma_thanh_toan, Ma_khoan_vay),
        CONSTRAINT fk_co_khoan_vay_vay FOREIGN KEY (Ma_khoan_vay) REFERENCES Khoan_vay(Ma_khoan_vay),
        CONSTRAINT fk_tra_GD_khoan_vay FOREIGN KEY (Ma_giao_dich) REFERENCES Giao_dich(Ma_giao_dich),
        CHECK(So_tien_goc_tra >0),
        CHECK(So_tien_lai_tra >= 0)
        
	);

    DROP TABLE IF EXISTS Khuyen_mai;
    CREATE TABLE Khuyen_mai
    (
		Ma VARCHAR(10) PRIMARY KEY,
        Ten_chuong_trinh VARCHAR(50) NOT NULL,
        So_tien_toi_thieu DECIMAL(15,2) NOT NULL,
        Gia_tri DECIMAL(15,2) NOT NULL,
        Ngay_bat_dau DATE NOT NULL,
        Ngay_ket_thuc DATE NOT NULL,
        Loai ENUM('Hoan_tien', 'Giam_gia'),
        CHECK (Ngay_bat_dau < Ngay_ket_thuc)
	);
    
    DROP TABLE IF EXISTS Cap_nhat;
    CREATE TABLE Cap_Nhat
    (
		Ma VARCHAR(10) NOT NULL,
        Ma_so VARCHAR(10) NOT NULL,
        Ngay_cap_nhat DATE,
        PRIMARY KEY(Ma,Ma_so),
        CONSTRAINT fk_cap_nhat_ma FOREIGN KEY (Ma) REFERENCES Khuyen_mai(Ma),
        CONSTRAINT fk_cap_nhat_ma_qtv FOREIGN KEY (Ma_so) REFERENCES Quan_tri_vien(Ma_so)
	);
    
    DROP TABLE IF EXISTS So_huu;
    CREATE TABLE So_huu
    (
		Ma VARCHAR(10) NOT NULL,
        So_tai_khoan VARCHAR(10) NOT NULL,
        PRIMARY KEY(Ma,So_tai_khoan),
        CONSTRAINT fk_so_huu_ma FOREIGN KEY (Ma) REFERENCES Khuyen_mai(Ma),
        CONSTRAINT fk_so_huu_tk_ma FOREIGN KEY (So_tai_khoan) REFERENCES Tai_khoan(So_tai_khoan)
	);
    
    DROP TABLE IF EXISTS Ap_dung;
    CREATE TABLE Ap_dung (
    Ma VARCHAR(10) NOT NULL,
    Ma_giao_dich VARCHAR(10),
    PRIMARY KEY (Ma, Ma_giao_dich),
    CONSTRAINT fk_ap_dung_ma FOREIGN KEY (Ma) REFERENCES Khuyen_mai(Ma),
    CONSTRAINT fk_ap_dung_ma_GD FOREIGN KEY (Ma_giao_dich) REFERENCES Giao_dich(Ma_giao_dich)
	);
    
	DROP TABLE IF EXISTS Tai_khoan_ngoai;
    CREATE TABLE Tai_khoan_ngoai
    (
		So_tai_khoan VARCHAR(18) PRIMARY KEY,
		Ngan_hang_nhan VARCHAR(50) NOT NULL,
		Ten_nguoi_nhan VARCHAR(255) NOT NULL
	);
		