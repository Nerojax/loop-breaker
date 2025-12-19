-- =====================================================
-- Loop Breaker — generate_daily_deck
-- Invariant: MUST always return at least one card
-- =====================================================

create or replace function public.generate_daily_deck(p_user_id uuid)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_cards jsonb := '[]'::jsonb;
begin
  /*
    Primary deck: active, non-system loops for the user
  */
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'loop_id', l.id,
        'title', l.title,
        'description', l.description,
        'difficulty', l.difficulty,
        'is_system', l.is_system
      )
    ),
    '[]'::jsonb
  )
  into v_cards
  from public.loops l
  where l.user_id = p_user_id
    and l.is_active = true
    and l.is_system = false;

  /*
    Fallback: if user has no active loops,
    return the system loop ("Open Loop Breaker")
  */
  if jsonb_array_length(v_cards) = 0 then
    select jsonb_agg(
      jsonb_build_object(
        'loop_id', l.id,
        'title', l.title,
        'description', l.description,
        'difficulty', l.difficulty,
        'is_system', l.is_system
      )
    )
    into v_cards
    from public.loops l
    where l.is_system = true
    limit 1;
  end if;

  /*
    Absolute safety net (should never trigger,
    but guarantees non-empty invariant)
  */
  if v_cards is null or jsonb_array_length(v_cards) = 0 then
    v_cards := jsonb_build_array(
      jsonb_build_object(
        'loop_id', '00000000-0000-0000-0000-000000000001',
        'title', 'Open Loop Breaker',
        'description', 'Showing up counts.',
        'difficulty', 1,
        'is_system', true
      )
    );
  end if;

  return v_cards;
end;
$$;

