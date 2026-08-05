-- ============================================================
-- Label Verify v3 — Supabase 설정 SQL
-- 실행: Supabase Dashboard → SQL Editor에 전체 붙여넣고 Run
-- 실행 후: Settings → API → "Exposed schemas"에 label 추가 (paint와 동일)
-- ============================================================

create schema if not exists label;

-- 1) 작업자 (회원가입 → 관리자 승인)
create table if not exists label.workers (
  emp_no     text primary key,          -- 사번
  name       text not null,
  pin_hash   text not null,             -- SHA-256(PIN)
  role       text not null default 'worker',   -- worker | supervisor | admin
  approved   boolean not null default false,
  created_at timestamptz not null default now()
);

-- 관리자 계정 시드 (사번 20120512, 초기 PIN: 0000 — 로그인 후 반드시 변경)
insert into label.workers (emp_no, name, pin_hash, role, approved)
values ('20120512', 'ADMIN',
        '9af15b336e6a9619928537df30b2e6a2376569fcf9d7e773eccede65606529a0',
        'admin', true)
on conflict (emp_no) do nothing;

-- 2) 라벨 매핑 마스터 (품목당 1행: 제품/폴리백/박스 QR 11자리 키)
create table if not exists label.master (
  id         bigint generated always as identity primary key,
  name       text not null,             -- 대표 품번/품명
  product    text not null unique,      -- 제품QR 키
  polybag    text not null unique,      -- 폴리백QR 키
  box        text not null unique,      -- 박스QR 키
  created_at timestamptz not null default now()
);

-- 3) 스캔 이력
create table if not exists label.scan_log (
  id          bigint generated always as identity primary key,
  scanned_at  timestamptz not null default now(),
  work_date   date not null,            -- 근무일 (야간은 시작일 기준 귀속)
  shift       text not null,            -- day | night
  emp_no      text,
  emp_name    text,
  part_name   text,                     -- 마스터 대표 품번 (OK 시)
  product_key text,
  polybag_key text,
  box_key     text,
  lot_polybag text,
  lot_box     text,
  result      text not null,            -- OK | NG
  reason      text
);

create index if not exists idx_scanlog_workdate on label.scan_log (work_date, shift);
create index if not exists idx_scanlog_emp      on label.scan_log (emp_no);

-- 4) 권한 (사내 도구: anon 키로 접근 — paint 스키마와 동일 방식)
grant usage on schema label to anon, authenticated;
grant all on all tables    in schema label to anon, authenticated;
grant all on all sequences in schema label to anon, authenticated;
alter default privileges in schema label grant all on tables    to anon, authenticated;
alter default privileges in schema label grant all on sequences to anon, authenticated;

alter table label.workers  enable row level security;
alter table label.master   enable row level security;
alter table label.scan_log enable row level security;

drop policy if exists workers_all  on label.workers;
drop policy if exists master_all   on label.master;
drop policy if exists scanlog_all  on label.scan_log;
create policy workers_all on label.workers  for all using (true) with check (true);
create policy master_all  on label.master   for all using (true) with check (true);
create policy scanlog_all on label.scan_log for all using (true) with check (true);
