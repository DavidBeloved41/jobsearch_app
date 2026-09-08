-- RPCs expose protected identity data and must never be callable by anon/public.
-- The functions still enforce row-level authorization for authenticated callers.

revoke execute on function public.get_admin_user_directory() from public, anon;
revoke execute on function public.get_messaging_participant(uuid) from public, anon;

grant execute on function public.get_admin_user_directory() to authenticated;
grant execute on function public.get_messaging_participant(uuid) to authenticated;
