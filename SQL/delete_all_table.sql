
DROP TABLE IF EXISTS
Thanh_toan_khoan_vay,
Khoan_vay,
So_huu,
Cap_nhat,
Ap_dung,
Khuyen_mai,
Hoa_don,
Loai_the,
The,
Giao_dich,
Tai_khoan_thanh_toan,
Tai_khoan_ngoai,
Tai_khoan_giao_dich,
Tai_khoan_tiet_kiem,
Tai_khoan,
Gioi_thieu,
Nguoi_dung,
Quan_tri_vien,
Tai_khoan_email,
So_dien_thoai,
Nguoi;

DROP PROCEDURE IF EXISTS tao_tai_khoan_dang_nhap;
DROP PROCEDURE IF EXISTS tao_the;
DROP PROCEDURE IF EXISTS chuyen_tien_mat_sang_tai_khoan;
DROP PROCEDURE IF EXISTS giao_dich_tien;
DROP PROCEDURE IF EXISTS vo_hieu_hoa_tai_khoan;
DROP PROCEDURE IF EXISTS kich_hoat_lai_tai_khoan;
DROP PROCEDURE IF EXISTS tao_tai_khoan_tiet_kiem;
DROP PROCEDURE IF EXISTS migrate_hoa_don_columns;
DROP PROCEDURE IF EXISTS GenerateLoanRepayments;
DROP PROCEDURE IF EXISTS delete_tai_khoan;
DROP PROCEDURE IF EXISTS get_account_transactions;
DROP PROCEDURE IF EXISTS get_loan_summary_by_admin;

DROP FUNCTION IF EXISTS calculate_total_interest;
DROP FUNCTION IF EXISTS check_loan_eligibility;