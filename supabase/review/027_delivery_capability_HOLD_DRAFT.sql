-- HOLD 027. Depends on held 019. Read-only capability; never enables dispatch.
begin;
create function public.delivery_workflow_capabilities() returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('version',1,'operations_enabled',coalesce((select enabled from public.delivery_operation_settings where singleton),false),'courier_approved',exists(select 1 from public.delivery_courier_approvals where courier_id=auth.uid() and approved));
$$;
revoke all on function public.delivery_workflow_capabilities() from public,anon,authenticated,service_role;
grant execute on function public.delivery_workflow_capabilities() to authenticated;
commit;
