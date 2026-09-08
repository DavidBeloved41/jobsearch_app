-- SUPABASE DATABASE CLEANUP SCRIPT
-- 
-- PURPOSE: Remove all job and application data while preserving user accounts
-- This allows starting fresh with job creation from a clean state
--
-- IMPORTANT NOTES:
-- 1. This script ONLY deletes jobs and applications
-- 2. All user profiles are PRESERVED
-- 3. All authentication data is PRESERVED
-- 4. Run this in Supabase SQL Editor
-- 5. Foreign key constraints are respected - deletions happen in correct order
-- 6. BACKUP YOUR DATABASE FIRST before running this script
--
-- ================================================================================
-- STEP 1: Delete dependent records first (applications, then jobs)
-- ================================================================================

-- Delete all applications (dependent on jobs)
DELETE FROM public.applications
WHERE TRUE;

-- Delete all saved jobs (if this table exists and depends on jobs)
DELETE FROM public.saved_jobs
WHERE TRUE;

-- ================================================================================
-- STEP 2: Delete jobs (after all dependent records are deleted)
-- ================================================================================

-- Delete all jobs
DELETE FROM public.jobs
WHERE TRUE;

-- ================================================================================
-- VERIFICATION QUERIES (run these to confirm cleanup)
-- ================================================================================

-- Verify jobs count is 0
SELECT COUNT(*) as total_jobs FROM public.jobs;

-- Verify applications count is 0
SELECT COUNT(*) as total_applications FROM public.applications;

-- Verify profiles still exist (should match pre-cleanup count)
SELECT COUNT(*) as total_profiles FROM public.profiles;

-- Verify employer_profiles still exist
SELECT COUNT(*) as total_employer_profiles FROM public.employer_profiles;

-- Verify job_seeker_profiles still exist (if applicable)
SELECT COUNT(*) as total_job_seeker_profiles FROM public.job_seeker_profiles;

-- ================================================================================
-- POST-CLEANUP STATE
-- ================================================================================
-- Expected result after cleanup:
--
-- total_jobs: 0
-- total_applications: 0
-- total_profiles: [original count - should not change]
-- total_employer_profiles: [original count - should not change]
--
-- Users can now create new jobs from a clean state
-- ================================================================================
