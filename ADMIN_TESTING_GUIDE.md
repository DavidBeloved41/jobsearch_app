# Admin System - Quick Start Testing Guide

## Admin Account Credentials

**Email:** `beloveddavid41@gmail.com`  
**Password:** Managed by Supabase Auth (prompt on login)  
**Role:** `admin` (must have account_type='admin' in profiles table)

---

## Pre-Testing Checklist

- [ ] Supabase RLS policies are set to "ON"
- [ ] Admin email is verified in Supabase Auth
- [ ] Admin profile exists with account_type='admin'
- [ ] Flutter app is built and running
- [ ] Network connectivity to Supabase is available

---

## Quick Test Flows

### Test 1: Admin Login & Dashboard
```
1. Launch app → Login screen
2. Enter: beloveddavid41@gmail.com
3. Enter: password (from Supabase)
4. Expected: Admin Dashboard loads
5. Verify: See real statistics (users, jobs, applications)
6. Verify: Pending/Approved/Rejected job counts
```

### Test 2: Job Management - Browse All Jobs
```
1. From Admin Dashboard → Click "Job Postings"
2. Verify: Jobs screen loads with list
3. Click filter "ALL" → Should see all jobs
4. Click filter "PENDING" → Should see pending jobs only
5. Click filter "APPROVED" → Should see approved jobs only
6. Type in search box → Should filter by title/location
```

### Test 3: Job Approval Workflow
```
1. Have an employer create a new job (or use existing pending)
2. Admin: Job Postings → Filter "PENDING"
3. Admin: Click "Review" on a pending job
4. Admin: Dialog shows full job details
5. Admin: Click "Approve"
6. Expected: 
   - Dialog closes
   - Success notification shows "Job approved successfully"
   - List refreshes
   - Job now appears in "APPROVED" filter
```

### Test 4: Job Rejection Workflow
```
1. Admin: Job Postings → Filter "PENDING"
2. Admin: Click "Review" on a pending job
3. Admin: Enter rejection reason in text field
4. Admin: Click "Reject"
5. Expected:
   - Dialog closes
   - Success notification shows "Job rejected successfully"
   - List refreshes
   - Job now appears in "REJECTED" filter
```

### Test 5: Search Functionality
```
1. Admin: Job Postings → all jobs showing
2. Search box: Type job title (e.g., "Engineer")
3. Expected: Results filter to matching jobs
4. Search box: Type location (e.g., "New York")
5. Expected: Results filter to jobs in that location
```

### Test 6: User Management
```
1. Admin: Dashboard → "Users"
2. Verify: All users displayed with real data
3. Click filter "JOB_SEEKER" → Shows only job seekers
4. Click filter "EMPLOYER" → Shows only employers
5. Click filter "ADMIN" → Shows admin accounts
6. Verify: Can see: name, email, role, join date
```

### Test 7: Application Management
```
1. Admin: Dashboard → "Applications"
2. Verify: All applications displayed
3. Click filter "APPLIED" → Shows applications
4. Click filter "ACCEPTED" → Shows accepted (if any)
5. Verify: Can see applicant name, job title, dates
```

### Test 8: Error Handling
```
1. Go to Network settings → Disable network
2. Admin: Try to open Job Postings
3. Expected: Error screen with "Error loading jobs"
4. Expected: "Retry" button appears
5. Enable network → Click "Retry"
6. Expected: Data loads successfully
```

### Test 9: Authorization - Non-Admin Access
```
1. Login as job_seeker or employer account
2. Try to navigate to /admin/dashboard (via URL bar)
3. Expected: Redirected to home/dashboard
4. Expected: Admin routes not accessible
```

### Test 10: Authorization - Wrong Admin Email
```
1. Create new account with account_type='admin'
2. Try to login as different email
3. Expected: Access denied to admin screens
4. Expected: Redirected to home
5. Note: Only beloveddavid41@gmail.com can be admin
```

---

## Job Approval Workflow Verification

### Complete Test Flow

**Step 1: Employer Posts Job**
```
1. Login as employer
2. Click "Post Job"
3. Fill: Title, Location, Description, etc.
4. Click "Post"
5. Expected: Success message
6. Verify in Supabase:
   approval_status = 'pending'
   is_active = false
```

**Step 2: Verify Job Not Visible to Job Seekers**
```
1. Login as job_seeker
2. Browse jobs
3. Expected: NEW pending job NOT in feed
4. (Only approved + active jobs visible)
```

**Step 3: Admin Reviews & Approves**
```
1. Login as admin (beloveddavid41@gmail.com)
2. Dashboard → Job Postings → PENDING
3. Click "Review" on the new job
4. Review details
5. Click "Approve"
6. Verify in Supabase:
   approval_status = 'approved'
   is_active = true
   approved_by = admin user id
   approved_at = current timestamp
```

**Step 4: Verify Job Now Visible to Job Seekers**
```
1. Login as job_seeker
2. Browse jobs
3. Expected: Approved job appears in feed
```

**Step 5: Verify Job Seeker Can Apply**
```
1. Job seeker: Click job
2. Click "Apply"
3. Expected: Application succeeds
4. Verify in Supabase: Application record created
```

---

## Common Issues & Solutions

### Issue: "Admin Dashboard is empty/loading forever"
**Solution:**
- Check Supabase connection
- Verify admin account credentials
- Click Refresh button
- Check browser console for errors

### Issue: "Jobs don't appear in list"
**Solution:**
- Verify jobs exist in Supabase
- Check approval_status and is_active fields
- Try search or filter
- Click Refresh

### Issue: "Can't approve/reject jobs"
**Solution:**
- Verify admin email is beloveddavid41@gmail.com
- Check account_type='admin' in profiles
- Check Supabase auth token validity
- Check browser console for errors

### Issue: "Job seeker can't see approved jobs"
**Solution:**
- Verify admin approved the job (approval_status='approved')
- Verify job is active (is_active=true)
- Check RLS policy SELECT condition
- Refresh job seeker's app

### Issue: "Can't login as admin"
**Solution:**
- Verify account exists in Supabase Auth
- Verify email is beloveddavid41@gmail.com (case-sensitive)
- Verify account_type='admin' in profiles table
- Check email is verified in Supabase

---

## Dashboard Statistics Reference

The Admin Dashboard shows:

**System Overview:**
- Total Users: Count of all profiles
- Total Jobs: Count of all jobs (any status)
- Applications: Count of all applications

**Job Approvals:**
- Pending: Jobs with approval_status='pending'
- Approved: Jobs with approval_status='approved'
- Rejected: Jobs with approval_status='rejected'

---

## Performance Notes

- Job list loads ALL jobs client-side
- Search and filtering happens in Flutter
- Good performance up to ~1000 jobs
- For larger datasets, implement server-side pagination

---

## Data Verification Queries

Run these in Supabase SQL Editor to verify data:

### Check Admin Profile
```sql
SELECT id, email, account_type FROM profiles 
WHERE email = 'beloveddavid41@gmail.com';
```

### Check Job Statuses
```sql
SELECT approval_status, COUNT(*) FROM jobs GROUP BY approval_status;
```

### Check Pending Jobs
```sql
SELECT id, title, approval_status, is_active FROM jobs 
WHERE approval_status = 'pending'
ORDER BY created_at DESC LIMIT 10;
```

### Check Approved Jobs
```sql
SELECT id, title, approval_status, is_active, approved_at, approved_by FROM jobs 
WHERE approval_status = 'approved'
ORDER BY approved_at DESC LIMIT 10;
```

### Check Applications
```sql
SELECT id, user_id, job_id, status, applied_at FROM applications 
ORDER BY applied_at DESC LIMIT 10;
```

---

## Support Contact

If issues persist:
1. Check console logs (Flutter DevTools)
2. Verify Supabase connection
3. Check RLS policies are ON
4. Verify data exists in correct tables
5. Try clearing app cache and restart
