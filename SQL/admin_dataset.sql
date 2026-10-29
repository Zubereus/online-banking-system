INSERT INTO Nguoi (CCCD, Ho, Ten_lot, Ten, Quoc_tich, Gioi_tinh, Ngay_sinh)
VALUES ('112345678901', 'Le', 'Duc', 'Quan', 'Viet Nam', 'Nam', '1988-04-12')
ON DUPLICATE KEY UPDATE Ho = VALUES(Ho), Ten_lot = VALUES(Ten_lot), Ten = VALUES(Ten), Quoc_tich = VALUES(Quoc_tich), Gioi_tinh = VALUES(Gioi_tinh), Ngay_sinh = VALUES(Ngay_sinh);

INSERT INTO Nguoi (CCCD, Ho, Ten_lot, Ten, Quoc_tich, Gioi_tinh, Ngay_sinh)
VALUES ('112345678902', 'Vo', 'Thanh', 'Mai', 'Viet Nam', 'Nu', '1990-09-23')
ON DUPLICATE KEY UPDATE Ho = VALUES(Ho), Ten_lot = VALUES(Ten_lot), Ten = VALUES(Ten), Quoc_tich = VALUES(Quoc_tich), Gioi_tinh = VALUES(Gioi_tinh), Ngay_sinh = VALUES(Ngay_sinh);

INSERT INTO Nguoi (CCCD, Ho, Ten_lot, Ten, Quoc_tich, Gioi_tinh, Ngay_sinh)
VALUES ('112345678903', 'Bui', 'Ngoc', 'Phuc', 'Viet Nam', 'Nam', '1987-12-05')
ON DUPLICATE KEY UPDATE Ho = VALUES(Ho), Ten_lot = VALUES(Ten_lot), Ten = VALUES(Ten), Quoc_tich = VALUES(Quoc_tich), Gioi_tinh = VALUES(Gioi_tinh), Ngay_sinh = VALUES(Ngay_sinh);

INSERT INTO Nguoi (CCCD, Ho, Ten_lot, Ten, Quoc_tich, Gioi_tinh, Ngay_sinh)
VALUES ('112345678904', 'Do', 'Lan', 'Huong', 'Viet Nam', 'Nu', '1992-02-17')
ON DUPLICATE KEY UPDATE Ho = VALUES(Ho), Ten_lot = VALUES(Ten_lot), Ten = VALUES(Ten), Quoc_tich = VALUES(Quoc_tich), Gioi_tinh = VALUES(Gioi_tinh), Ngay_sinh = VALUES(Ngay_sinh);

INSERT INTO Nguoi (CCCD, Ho, Ten_lot, Ten, Quoc_tich, Gioi_tinh, Ngay_sinh)
VALUES ('112345678905', 'Phan', 'Minh', 'Khai', 'Viet Nam', 'Nam', '1989-07-30')
ON DUPLICATE KEY UPDATE Ho = VALUES(Ho), Ten_lot = VALUES(Ten_lot), Ten = VALUES(Ten), Quoc_tich = VALUES(Quoc_tich), Gioi_tinh = VALUES(Gioi_tinh), Ngay_sinh = VALUES(Ngay_sinh);

INSERT INTO So_dien_thoai (CCCD, So_dien_thoai) VALUES ('112345678901', '0917000001') ON DUPLICATE KEY UPDATE CCCD = VALUES(CCCD);
INSERT INTO So_dien_thoai (CCCD, So_dien_thoai) VALUES ('112345678902', '0917000002') ON DUPLICATE KEY UPDATE CCCD = VALUES(CCCD);
INSERT INTO So_dien_thoai (CCCD, So_dien_thoai) VALUES ('112345678903', '0917000003') ON DUPLICATE KEY UPDATE CCCD = VALUES(CCCD);
INSERT INTO So_dien_thoai (CCCD, So_dien_thoai) VALUES ('112345678904', '0917000004') ON DUPLICATE KEY UPDATE CCCD = VALUES(CCCD);
INSERT INTO So_dien_thoai (CCCD, So_dien_thoai) VALUES ('112345678905', '0917000005') ON DUPLICATE KEY UPDATE CCCD = VALUES(CCCD);

INSERT INTO Tai_khoan_email (CCCD, Tk_email) VALUES ('112345678901', 'quan.le@bank-admin.vn') ON DUPLICATE KEY UPDATE CCCD = VALUES(CCCD);
INSERT INTO Tai_khoan_email (CCCD, Tk_email) VALUES ('112345678902', 'mai.vo@bank-admin.vn') ON DUPLICATE KEY UPDATE CCCD = VALUES(CCCD);
INSERT INTO Tai_khoan_email (CCCD, Tk_email) VALUES ('112345678903', 'phuc.bui@bank-admin.vn') ON DUPLICATE KEY UPDATE CCCD = VALUES(CCCD);
INSERT INTO Tai_khoan_email (CCCD, Tk_email) VALUES ('112345678904', 'huong.do@bank-admin.vn') ON DUPLICATE KEY UPDATE CCCD = VALUES(CCCD);
INSERT INTO Tai_khoan_email (CCCD, Tk_email) VALUES ('112345678905', 'khai.phan@bank-admin.vn') ON DUPLICATE KEY UPDATE CCCD = VALUES(CCCD);

UPDATE Quan_tri_vien SET CCCD = '112345678901', Ten_dang_nhap = 'admin_console_1', Mat_khau = 'AdminPortal#1001', Cap_do_truy_cap = '3' WHERE Ma_so = 'QTV001';
UPDATE Quan_tri_vien SET CCCD = '112345678902', Ten_dang_nhap = 'admin_console_2', Mat_khau = 'AdminPortal#1002', Cap_do_truy_cap = '2' WHERE Ma_so = 'QTV002';
UPDATE Quan_tri_vien SET CCCD = '112345678903', Ten_dang_nhap = 'admin_console_3', Mat_khau = 'AdminPortal#1003', Cap_do_truy_cap = '2' WHERE Ma_so = 'QTV003';
UPDATE Quan_tri_vien SET CCCD = '112345678904', Ten_dang_nhap = 'admin_console_4', Mat_khau = 'AdminPortal#1004', Cap_do_truy_cap = '1' WHERE Ma_so = 'QTV004';
UPDATE Quan_tri_vien SET CCCD = '112345678905', Ten_dang_nhap = 'admin_console_5', Mat_khau = 'AdminPortal#1005', Cap_do_truy_cap = '1' WHERE Ma_so = 'QTV005';
