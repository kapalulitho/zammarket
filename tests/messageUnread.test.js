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
