create or replace function public.delete_user()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.profiles where id = auth.uid();
  delete from public.expenses where user_id = auth.uid();
  delete from public.budget_settings where user_id = auth.uid();
  delete from public.budget_histories where user_id = auth.uid();

  delete from auth.users where id = auth.uid();
end;
$$;