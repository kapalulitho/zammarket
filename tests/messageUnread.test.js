import test from 'node:test';
import assert from 'node:assert/strict';
import {loadReads,markConversationRead,unreadByConversation} from '../src/lib/messageUnread.js';

test('unread counts skip own messages and conversations read since the message arrived',()=>{
  const now=new Date().toISOString();
  const rows=[
    {conversation_id:'a',sender_id:'me',created_at:now},
    {conversation_id:'a',sender_id:'other',created_at:now},
    {conversation_id:'b',sender_id:'other',created_at:now},
    {conversation_id:'b',sender_id:'other',created_at:now},
  ];
  const reads=markConversationRead('a',loadReads());
  assert.deepEqual(unreadByConversation(rows,'me',reads),{b:2});
  const allRead=markConversationRead('b',reads);
  assert.deepEqual(unreadByConversation(rows,'me',allRead),{});
  assert.deepEqual(unreadByConversation(rows,'other',{}),{a:1},'the sender does not count their own messages');
});

test('marking read stamps the newest displayed message time, so seen messages stay read',()=>{
  const rows=[
    {conversation_id:'a',sender_id:'other',created_at:'2026-11-17T10:00:00Z'},
    {conversation_id:'a',sender_id:'other',created_at:'2026-11-17T09:00:00Z'},
  ];
  // Device clock slightly behind the server: "now" is before the newest message.
  const reads=markConversationRead('a',{},rows[0].created_at);
  assert.deepEqual(unreadByConversation(rows,'me',reads),{},'messages shown on screen are not recounted');
});

test('the read cutoff never moves backwards when an older stamp is written',()=>{
  const later='2026-11-17T11:00:00Z';
  const reads=markConversationRead('a',{},later);
  const kept=markConversationRead('a',reads,'2026-11-17T10:00:00Z');
  assert.equal(kept['a'],later,'an older read stamp must not erase a newer one');
});

test('marking with no messages falls back to the current time',()=>{
  const reads=markConversationRead('a',{});
  assert.ok(Date.parse(reads['a'])<=Date.now()+1000,'the fallback stamp is a valid recent time');
});
