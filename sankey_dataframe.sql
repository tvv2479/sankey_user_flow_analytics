
with  
base_users as (
select id, 
       data_reg
  from users
 where data_reg between '2023-01-01' and '2026-08-31'
   and referrer not in ('3dlutmobile app', '?3dlutmobile app')
   and ipaddr != '91.150.101.73'
       ),
       base_soft as (
       select s.*
         from soft s
         join base_users u on u.id = s.id_user
        where s.status = 1
              ),
              /* ---------- STEP 1 (регистрация) ---------- */
              step1 as (
              select id as user_id,
                     data_reg as dat,
                     1 as step,
                     'Registration' as state,
                     null::int as priority
                from base_users
                     ),
                     /* ---------- STEP 2 (первое действие) ---------- */
                     step2 as (
                     select user_id, 
                            dat, 
                            step, 
                            state, 
                            null::int as priority
                       FROM (
                            select s.id_user as user_id,
                                   s.data_pay AS dat,
                                   2 as step,
                                   case
                                   when s.product = 101 then 'heal'
                                   when s.product = 102 then 'dodge & burn'
                                   when s.product in (1027,1028,1029,1024,1004,1000) then 'Got Free Pack'
                                   end as state,
                                   row_number() over (partition by s.id_user order by s.data_pay) as rn
                              from base_soft s
                             where s.product in (101,102,1027,1028,1029,1024,1004,1000)
                            ) t
                      WHERE rn = 1
                            ),
                            /* ---------- STEP 3: Heal + Dodge (КОМБО) ---------- */
                            step3_heal_dodge as (
                            select s.id_user as user_id,
                                   max(s.data_pay) as dat,
                                   3 as step,
                                   'Heal + Dodge' as state,
                                   1 as priority
                              from base_soft s
                             where s.product IN (101,102)
                             group by s.id_user
                            having count(distinct s.product) = 2
                                   ),
                                   /* ---------- STEP 3: subscription / cloud ---------- */
                                   step3_paid as (
                                   select s.id_user as user_id,
                                          s.data_pay as dat,
                                          3 as step,
                                          case 
	                                      when s.product in (2004,2002,2003,2006,2005,2001) then 'subscription'
                                          when s.product in (1003,1002,1001) then 'cloud'
                                          end as state,
                                          case
                                          when s.product IN (2004,2002,2003,2006,2005,2001) then 2
                                          else 3
                                          end as priority
                                     from base_soft s
                                    where s.product in (2004,2002,2003,2006,2005,2001,
                                                        1003,1002,1001)
                                          ),
                                          /* ---------- STEP 3: выбираем одно состояние ---------- */
                                          step3 as (
                                          select user_id, 
                                                 dat, 
                                                 step, 
                                                 state, 
                                                 priority
                                            from (
                                                 select user_id,
                                                        dat,
                                                        step,
                                                        state,
                                                        priority,
                                                        row_number() over (partition by user_id order by priority, dat) as rn
                                                   from (
                                                        select * from step3_heal_dodge
                                                         union all
                                                        select * from step3_paid
                                                        ) t
                                                 ) x
                                           where rn = 1
                                                 ),
                                                 /* ---------- USER STATES ---------- */
                                                 user_states as (
                                                 select user_id, dat, step, state from step1
                                                  union all
                                                 select user_id, dat, step, state from step2
                                                  union all
                                                 select user_id, dat, step, state from step3
                                                        )
                                                        /* ---------- SANKEY ---------- */
                                                        select s1.state as source,
                                                               s2.state as target,
                                                               count(distinct s1.user_id) as value
                                                          from user_states s1
                                                          join user_states s2
                                                            on s1.user_id = s2.user_id
                                                           and s2.step = s1.step + 1
                                                         group by s1.state, s2.state
                                                         order by value desc;
