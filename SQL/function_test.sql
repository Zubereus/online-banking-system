-- Test script for procedures in procedure.sql.
-- Run this file after creating schema + procedures.

-- 1) Create a new user account
CALL tao_tai_khoan_dang_nhap(
	'Pham',
	'Gia',
	'Bao',
	'099999999999',
	'Nam',
	'Viet Nam',
	'1999-09-09',
	'0910000000',
	'user_bao_test',
	'Password123'
);

SELECT CCCD, Ho, Ten_lot, Ten
FROM Nguoi
WHERE CCCD = '099999999999';

SELECT So_tai_khoan, Ten_khach_hang, Ten_dang_nhap, CCCD, Trang_thai
FROM Tai_khoan
WHERE CCCD = '099999999999';

-- 2) Create a card for the latest account of this user
SET @test_account = (
	SELECT So_tai_khoan
	FROM Tai_khoan
	WHERE CCCD = '099999999999'
	ORDER BY So_tai_khoan DESC
	LIMIT 1
);

CALL tao_the(@test_account, 'Visa');

SELECT Ma_so_the, Ten_chu_the, Ngay_het_han, So_tai_khoan, Ten_the
FROM The
WHERE So_tai_khoan = @test_account
ORDER BY Ngay_het_han DESC;

-- 3) Deposit then transfer money
CALL chuyen_tien_mat_sang_tai_khoan(@test_account, 2000000);
CALL giao_dich_tien(@test_account, '1000000001', 500000);

SELECT So_tai_khoan, So_du, Han_muc
FROM Tai_khoan_thanh_toan
WHERE So_tai_khoan IN (@test_account, '1000000001')
ORDER BY So_tai_khoan;

SELECT gd.So_tai_khoan_gui, gd.Ma_giao_dich, gd.So_tien, gd.Phi_chuyen_tien, gd.Thoi_gian, 'Online' as Hinh_thuc_nhan
FROM Giao_dich gd
WHERE gd.So_tai_khoan_gui = @test_account OR gd.So_tai_khoan_nhan = @test_account
ORDER BY gd.Thoi_gian DESC;

-- 4) Deactivate account (admin any level can deactivate)
CALL vo_hieu_hoa_tai_khoan('QTV003', @test_account);

SELECT So_tai_khoan, Trang_thai
FROM Tai_khoan
WHERE So_tai_khoan = @test_account;

-- 5) These should fail after deactivation
-- Expected: 'Tai khoan khong hoat dong'
CALL giao_dich_tien(@test_account, '1000000001', 100000);

-- Expected: 'Tai khoan khong hoat dong'
CALL tao_the(@test_account, 'Mastercard');

-- 6) Reactivate account
CALL kich_hoat_lai_tai_khoan('QTV002', @test_account);

SELECT So_tai_khoan, Trang_thai
FROM Tai_khoan
WHERE So_tai_khoan = @test_account;

-- 7) These should work again after activation
CALL tao_the(@test_account, 'Mastercard');
CALL giao_dich_tien(@test_account, '1000000001', 100000);