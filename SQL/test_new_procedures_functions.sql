-- ============================================================================
-- Test script for NEW procedures and functions added for Part 2
-- Run this file after creating schema + all procedures
-- ============================================================================

-- ===================================================================================
-- TEST 1: DELETE PROCEDURE - delete_tai_khoan
-- ===================================================================================
-- Purpose: Test account deletion with validation logic
-- Preconditions: Account must have 0 balance, no active loans, no unpaid bills

-- Step 1: Create a temporary test account for deletion
-- First create test person and admin account
INSERT INTO Nguoi (CCCD, Ho, Ten_lot, Ten, Quoc_tich, Gioi_tinh, Ngay_sinh)
VALUES ('999999999999', 'Test', 'Delete', 'Account', 'Viet Nam', 'Nam', '2000-05-15');

INSERT INTO Nguoi_dung (CCCD) VALUES ('999999999999');

INSERT INTO So_dien_thoai (CCCD, Sdt) VALUES ('999999999999', '0900000099');

INSERT INTO Tai_khoan (So_tai_khoan, Ten_khach_hang, Ten_dang_nhap, Mat_khau, CCCD, Trang_thai, Ma_so)
VALUES ('9999999999', 'Test Delete Account', 'test_delete_user', 'TempPassword123', '999999999999', 'Hoat_dong', 'QTV001');

INSERT INTO Tai_khoan_thanh_toan (So_tai_khoan, Han_muc, So_du, ID)
VALUES ('9999999999', 10000000.00, 0.00, 99);

INSERT INTO Tai_khoan_giao_dich (ID) VALUES (99);

-- Step 2: Try deletion - should FAIL because account needs So_du = 0
-- (Already has 0, so this should work)
CALL delete_tai_khoan('QTV001', '9999999999');

-- Verify account is deleted
SELECT 'Account deleted successfully' AS Result;
SELECT COUNT(*) AS Account_count FROM Tai_khoan WHERE So_tai_khoan = '9999999999';

-- Step 3: Try to delete non-existent account - should FAIL
-- CALL delete_tai_khoan('QTV001', '1111111111');  -- Error: So tai khoan khong ton tai

-- Step 4: Try with insufficient admin level - should FAIL
-- CALL delete_tai_khoan('QTV004', '1000000001');  -- Error: Ban khong du quyen han


-- ===================================================================================
-- TEST 2: SELECT PROCEDURE 1 - get_account_transactions
-- ===================================================================================
-- Purpose: Retrieve all transactions for an account with details (JOIN 3+ tables)
-- Features: WHERE clause, ORDER BY, JOIN with transaction history

-- Step 1: Call with ascending order
SELECT '=== Transaction History (Ascending) ===' AS Test_Case;
CALL get_account_transactions('1000000001', 'ASC');

-- Step 2: Call with descending order
SELECT '=== Transaction History (Descending) ===' AS Test_Case;
CALL get_account_transactions('1000000001', 'DESC');

-- Step 3: Call for different account
SELECT '=== Transaction History for Account 2 ===' AS Test_Case;
CALL get_account_transactions('1000000002', 'DESC');

-- Step 4: Try with invalid account - should error
-- CALL get_account_transactions('9999999999', 'DESC');  -- Error: So tai khoan khong ton tai

-- Expected Output Columns:
-- - Ma_giao_dich
-- - So_tai_khoan
-- - So_tien
-- - Phi_chuyen_tien
-- - Tong_chi_phi (calculated)
-- - Ngay_gio (ordered)
-- - Hinh_thuc_nhan
-- - Ten_khach_hang
-- - Ma_hoa_don (LEFT JOIN result)
-- - Loai_hoa_don


-- ===================================================================================
-- TEST 3: SELECT PROCEDURE 2 - get_loan_summary_by_admin
-- ===================================================================================
-- Purpose: Complex query with GROUP BY, HAVING, aggregate functions
-- Features: Admin loan supervision, total amounts, average rates, status counts

-- Step 1: Get loan summary for admin 1 with minimum amount
SELECT '=== Loan Summary for Admin 1 (Min 50,000,000) ===' AS Test_Case;
CALL get_loan_summary_by_admin('QTV001', 50000000.00);

-- Step 2: Get loan summary for admin 2 with lower minimum
SELECT '=== Loan Summary for Admin 2 (Min 10,000,000) ===' AS Test_Case;
CALL get_loan_summary_by_admin('QTV002', 10000000.00);

-- Step 3: Get loan summary with very high minimum (should show fewer results if any)
SELECT '=== Loan Summary for Admin 1 (Min 200,000,000 - High threshold) ===' AS Test_Case;
CALL get_loan_summary_by_admin('QTV001', 200000000.00);

-- Expected Output Columns:
-- - Ma_so (Admin ID)
-- - Ho, Ten_lot, Ten (Admin Name)
-- - So_khoan_vay (COUNT)
-- - Tong_tien_vay (SUM)
-- - Lai_suat_trung_binh (AVG)
-- - So_khoan_dang_hoat_dong (CASE WHEN COUNT)
-- - So_khoan_da_tat_toan (CASE WHEN COUNT)
-- - Ngay_phe_duyet_gan_nhat (MAX)


-- ===================================================================================
-- TEST 4: FUNCTION 1 - calculate_total_interest
-- ===================================================================================
-- Purpose: Calculate total interest due for pending loan repayments using cursor
-- Features: CURSOR to iterate records, IF conditions, calculation logic

-- Step 1: Call function for account with pending loans
SELECT '=== Total Interest for Account 1 ===' AS Test_Case;
SELECT 
    '1000000001' AS So_tai_khoan,
    calculate_total_interest('1000000001') AS Total_Interest_VND;

-- Step 2: Call function for another account
SELECT '=== Total Interest for Account 2 ===' AS Test_Case;
SELECT 
    '1000000002' AS So_tai_khoan,
    calculate_total_interest('1000000002') AS Total_Interest_VND;

-- Step 3: Call function for account with no loans
SELECT '=== Total Interest for Account 6 (No loans) ===' AS Test_Case;
SELECT 
    '1000000006' AS So_tai_khoan,
    calculate_total_interest('1000000006') AS Total_Interest_VND;

-- Step 4: Call with non-existent account (should return -1)
SELECT '=== Total Interest for Non-existent Account ===' AS Test_Case;
SELECT 
    '9999999999' AS So_tai_khoan,
    calculate_total_interest('9999999999') AS Total_Interest_VND;

-- Expected Output:
-- - Positive decimal: Total interest amount in VND
-- - 0: No pending repayments
-- - -1: Account not found


-- ===================================================================================
-- TEST 5: FUNCTION 2 - check_loan_eligibility
-- ===================================================================================
-- Purpose: Check if customer qualifies for new loan based on multiple conditions
-- Features: IF conditions, age validation, account status, overdue checks, max loans

-- Step 1: Check eligibility for eligible customer
SELECT '=== Loan Eligibility Check for CCCD 012345678901 ===' AS Test_Case;
SELECT 
    '012345678901' AS CCCD,
    (SELECT CONCAT(Ho, ' ', Ten_lot, ' ', Ten) FROM Nguoi WHERE CCCD = '012345678901') AS Customer_Name,
    check_loan_eligibility('012345678901') AS Eligibility_Status;

-- Step 2: Check eligibility for another customer
SELECT '=== Loan Eligibility Check for CCCD 012345678902 ===' AS Test_Case;
SELECT 
    '012345678902' AS CCCD,
    (SELECT CONCAT(Ho, ' ', Ten_lot, ' ', Ten) FROM Nguoi WHERE CCCD = '012345678902') AS Customer_Name,
    check_loan_eligibility('012345678902') AS Eligibility_Status;

-- Step 3: Check for customer without active account (if exists)
SELECT '=== Loan Eligibility Check for CCCD 012345678905 ===' AS Test_Case;
SELECT 
    '012345678905' AS CCCD,
    (SELECT CONCAT(Ho, ' ', Ten_lot, ' ', Ten) FROM Nguoi WHERE CCCD = '012345678905') AS Customer_Name,
    check_loan_eligibility('012345678905') AS Eligibility_Status;

-- Step 4: Check for non-existent CCCD
SELECT '=== Loan Eligibility Check for Non-existent CCCD ===' AS Test_Case;
SELECT 
    '000000000000' AS CCCD,
    check_loan_eligibility('000000000000') AS Eligibility_Status;

-- Expected Output:
-- - 'Du dieu kien vay': Eligible for loan
-- - 'Tuoi khong du (phai >= 18 nam)': Under 18 years old
-- - 'Tai khoan khong hoat dong': Account inactive
-- - 'Co khoan vay qua han - khong du dieu kien vay moi': Has overdue loan
-- - 'Da dat so khoan vay toi da (3 khoan)': Already has 3 active loans
-- - 'Khong tim thay nguoi dung': CCCD not found


-- ===================================================================================
-- TEST SUMMARY
-- ===================================================================================
SELECT '
========================================
Test Execution Complete
========================================
Components tested:
1. DELETE PROCEDURE - delete_tai_khoan
2. SELECT PROCEDURE 1 - get_account_transactions
3. SELECT PROCEDURE 2 - get_loan_summary_by_admin
4. FUNCTION 1 - calculate_total_interest
5. FUNCTION 2 - check_loan_eligibility

All procedures include:
- Parameter validation
- Meaningful error messages
- Proper JOIN operations
- Aggregate functions (COUNT, SUM, AVG, MAX)
- Cursor loops where appropriate
- IF/CASE conditions
========================================
' AS Test_Complete_Message;
