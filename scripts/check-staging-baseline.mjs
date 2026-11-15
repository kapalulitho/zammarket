// DDL smoke check in a fresh in-memory database. No connection string or network.
import {PGlite} from '../.validation/node_modules/@electric-sql/pglite/dist/index.js';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
const db=new PGlite();await db.exec('create role anon;create role authenticated;create schema auth;create table auth.users(id uuid primary key);create schema storage;create table storage.buckets(id text primary key,name text,public boolean);');
await db.exec(await fs.readFile('supabase/staging/000_empty_baseline_STAGING_ONLY_HOLD.sql','utf8'));
assert.equal((await db.query('select count(*)::int n from public.listings')).rows[0].n,0);assert.equal((await db.query('select count(*)::int n from public.likes')).rows[0].n,0);assert.equal((await db.query("select count(*)::int n from pg_class where relnamespace='public'::regnamespace and relname in('listings','likes') and relrowsecurity")).rows[0].n,2);await db.close();console.log('Empty staging baseline DDL passed locally: no account/listing/like rows created; new tables have RLS. Not a remote staging validation.');
