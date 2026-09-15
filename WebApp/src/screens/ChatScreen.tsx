import React, { useEffect, useRef, useState } from 'react';
import { ConversationDTO, MessageDTO, OrgMemberDTO, ThreadMessageBundleDTO } from '../types';
import { api } from '../services/api';
import { 
  Hash, 
  User, 
  Lock,
  Send, 
  Video, 
  Smile, 
  Pin, 
  Bookmark, 
  MessageSquare, 
  CheckSquare, 
  X, 
  Plus, 
  ChevronRight, 
  Sparkles,
  RefreshCw,
  MoreHorizontal
} from 'lucide-react';

interface ChatScreenProps {
  onStartCall?: (conversationId: string) => void;
}

const EMOJI_PICKER = ['👍', '❤️', '🎉', '🚀', '👀', '🔥', '💡'];
const SLASH_COMMANDS = [
  { cmd: '/status', desc: 'Set your user status message' },
  { cmd: '/task', desc: 'Create a new task directly from chat' },
  { cmd: '/remind', desc: 'Set a quick reminder' },
  { cmd: '/me', desc: 'Display action text' },
  { cmd: '/help', desc: 'Show chat command guide' },
];

export const ChatScreen: React.FC<ChatScreenProps> = ({ onStartCall }) => {
  const [conversations, setConversations] = useState<ConversationDTO[]>([]);
  const [selectedConv, setSelectedConv] = useState<ConversationDTO | null>(null);
  const [messages, setMessages] = useState<MessageDTO[]>([]);
  const [loading, setLoading] = useState(true);
  const [messagesLoading, setMessagesLoading] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const lastMarkedReadRef = useRef<Record<string, string>>({});

  // Input
  const [inputText, setInputText] = useState('');
  const [showSlashHints, setShowSlashHints] = useState(false);

  // Thread Drawer
  const [activeThreadBundle, setActiveThreadBundle] = useState<ThreadMessageBundleDTO | null>(null);
  const [threadInputText, setThreadInputText] = useState('');
  const [threadLoading, setThreadLoading] = useState(false);

  // Convert to Task Modal
  const [convertingMessage, setConvertingMessage] = useState<MessageDTO | null>(null);
  const [taskTitle, setTaskTitle] = useState('');
  const [targetListId, setTargetListId] = useState('list-1');

  // New Conversation Modal State
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [createType, setCreateType] = useState<'channel' | 'group' | 'direct'>('channel');
  const [createName, setCreateName] = useState('');
  const [createTopic, setCreateTopic] = useState('');
  const [orgMembers, setOrgMembers] = useState<OrgMemberDTO[]>([]);
  const [selectedMemberIds, setSelectedMemberIds] = useState<string[]>([]);
  const [creatingConv, setCreatingConv] = useState(false);

  const handleOpenCreateModal = async (defaultType: 'channel' | 'group' | 'direct' = 'channel') => {
    setCreateType(defaultType);
    setCreateName('');
    setCreateTopic('');
    setSelectedMemberIds([]);
    setShowCreateModal(true);
    try {
      const members = await api.getOrgMembers();
      const currentId = api.currentUser?.id;
      setOrgMembers(members.filter(m => m.userId !== currentId));
    } catch (err) {
      console.error('Failed to load org members:', err);
    }
  };

  const handleCreateConversation = async (e: React.FormEvent) => {
    e.preventDefault();
    if (createType === 'direct' && selectedMemberIds.length !== 1) {
      alert('Please select exactly one team member for a direct message.');
      return;
    }
    if ((createType === 'channel' || createType === 'group') && !createName.trim()) {
      alert('Please enter a name for the conversation.');
      return;
    }

    setCreatingConv(true);
    try {
      const newConv = await api.createConversation({
        type: createType,
        name: createName.trim() || undefined,
        topic: createTopic.trim() || undefined,
        memberIds: selectedMemberIds,
      });
      setShowCreateModal(false);
      await fetchConversations(true);
      setSelectedConv(newConv);
    } catch (err: any) {
      alert(`Failed to create conversation: ${err.message || err}`);
    } finally {
      setCreatingConv(false);
    }
  };

  const toggleMemberSelection = (userId: string) => {
    if (createType === 'direct') {
      setSelectedMemberIds([userId]);
    } else {
      setSelectedMemberIds(prev =>
        prev.includes(userId) ? prev.filter(id => id !== userId) : [...prev, userId]
      );
    }
  };

  // Load Conversations
  const fetchConversations = async (silent = false) => {
    if (!silent) setLoading(true);
    try {
      const data = await api.getConversations();
      setConversations(data);
      if (data.length > 0 && !selectedConv) {
        setSelectedConv(data[0]);
      }
    } catch (err: any) {
      console.error(err);
    } finally {
      if (!silent) setLoading(false);
    }
  };

  // Load Messages for active conversation
  const fetchMessages = async (convId: string, silent = false) => {
    if (!silent) setMessagesLoading(true);
    try {
      const data = await api.getMessages(convId);
      setMessages(data);
      const lastMessage = data[data.length - 1];
      if (lastMessage && lastMarkedReadRef.current[convId] !== lastMessage.id) {
        await api.markConversationRead(convId, lastMessage.id);
        lastMarkedReadRef.current[convId] = lastMessage.id;
      }
      setConversations(prev => prev.map(conversation =>
        conversation.id === convId ? { ...conversation, unreadCount: 0 } : conversation
      ));
    } catch (err: any) {
      console.error(err);
    } finally {
      if (!silent) setMessagesLoading(false);
    }
  };

  useEffect(() => {
    fetchConversations();
  }, []);

  useEffect(() => {
    if (selectedConv) {
      fetchMessages(selectedConv.id);

      // Real-time polling loop every 2.5 seconds so incoming messages arrive immediately
      const timer = setInterval(() => {
        fetchMessages(selectedConv.id, true);
        fetchConversations(true);
      }, 2500);

      return () => clearInterval(timer);
    }
  }, [selectedConv]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  // Handle Start Call with Backend Call Initiation
  const handleStartCall = async () => {
    if (!selectedConv) return;
    try {
      await api.initiateCall(selectedConv.id, true);
    } catch (err: any) {
      console.warn('Call initiate API note:', err);
    }
    if (onStartCall) {
      onStartCall(selectedConv.id);
    }
  };

  // Handle Send Main Message
  const handleSendMessage = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    if (!inputText.trim() || !selectedConv) return;

    const textToSend = inputText;
    setInputText('');
    setShowSlashHints(false);

    try {
      const newMsg = await api.sendMessage(selectedConv.id, textToSend);
      setMessages(prev => [...prev, newMsg]);
      fetchConversations(true);
    } catch (err: any) {
      alert(`Failed to send message: ${err.message}`);
    }
  };

  // Handle Send Thread Reply
  const handleSendThreadReply = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    if (!threadInputText.trim() || !activeThreadBundle || !selectedConv) return;

    const text = threadInputText;
    setThreadInputText('');

    try {
      const reply = await api.sendMessage(selectedConv.id, text, activeThreadBundle.rootMessage.id);
      setActiveThreadBundle(prev => prev ? {
        ...prev,
        replies: [...prev.replies, reply]
      } : null);
      
      // Update reply count in main feed
      setMessages(prev => prev.map(m => m.id === activeThreadBundle.rootMessage.id ? {
        ...m,
        replyCount: (m.replyCount || 0) + 1
      } : m));
    } catch (err: any) {
      alert(`Failed to send reply: ${err.message}`);
    }
  };

  // Handle Add Reaction
  const handleAddReaction = async (messageId: string, emoji: string) => {
    try {
      const updated = await api.addReaction(messageId, emoji);
      setMessages(prev => prev.map(m => m.id === messageId ? updated : m));
      if (activeThreadBundle && activeThreadBundle.rootMessage.id === messageId) {
        setActiveThreadBundle(prev => prev ? { ...prev, rootMessage: updated } : null);
      }
    } catch (err: any) {
      console.error(err);
    }
  };

  // Handle Pin / Bookmark
  const handlePin = async (messageId: string) => {
    try {
      const updated = await api.pinMessage(messageId);
      setMessages(prev => prev.map(m => m.id === messageId ? updated : m));
    } catch (err: any) {
      console.error(err);
    }
  };

  const handleBookmark = async (messageId: string) => {
    try {
      const updated = await api.bookmarkMessage(messageId);
      setMessages(prev => prev.map(m => m.id === messageId ? updated : m));
    } catch (err: any) {
      console.error(err);
    }
  };

  // Open Thread Drawer
  const openThread = async (messageId: string) => {
    setThreadLoading(true);
    try {
      const bundle = await api.getThread(messageId);
      setActiveThreadBundle(bundle);
    } catch (err: any) {
      alert(`Failed to load thread: ${err.message}`);
    } finally {
      setThreadLoading(false);
    }
  };

  // Convert Message to Task
  const handleConvertToTask = async () => {
    if (!convertingMessage) return;
    try {
      await api.convertMessageToTask(convertingMessage.id, targetListId, taskTitle || convertingMessage.body);
      alert('Message successfully converted to task!');
      setConvertingMessage(null);
    } catch (err: any) {
      alert(`Failed to convert: ${err.message}`);
    }
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const val = e.target.value;
    setInputText(val);
    setShowSlashHints(val.startsWith('/'));
  };

  return (
    <div className="flex-1 flex h-full overflow-hidden bg-slate-950 text-slate-100">
      {/* Channels & DMs Sidebar */}
      <div className="w-64 border-r border-slate-800/80 bg-slate-900/60 flex flex-col h-full shrink-0">
        <div className="p-4 border-b border-slate-800 flex items-center justify-between">
          <h2 className="font-bold text-slate-100 text-sm flex items-center gap-2">
            <MessageSquare className="w-4 h-4 text-indigo-400" />
            Channels & DMs
          </h2>
          <button 
            onClick={() => fetchConversations()}
            className="p-1 rounded-md text-slate-400 hover:text-slate-200 hover:bg-slate-800"
            title="Refresh conversations"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto p-3 space-y-4">
          {/* Channels Section */}
          <div>
            <div className="px-2 pb-2 flex items-center justify-between">
              <span className="text-[11px] font-semibold uppercase tracking-wider text-slate-400">
                Channels
              </span>
              <button
                onClick={() => handleOpenCreateModal('channel')}
                className="p-1 rounded hover:bg-slate-800 text-slate-400 hover:text-indigo-400 transition"
                title="Create Channel"
              >
                <Plus className="w-3.5 h-3.5" />
              </button>
            </div>
            <div className="space-y-1">
              {conversations.filter(c => c.type === 'channel').map(channel => (
                <button
                  key={channel.id}
                  onClick={() => setSelectedConv(channel)}
                  className={`w-full flex items-center justify-between px-3 py-2 rounded-xl text-xs font-medium transition ${
                    selectedConv?.id === channel.id
                      ? 'bg-indigo-600/20 text-indigo-300 border border-indigo-500/30'
                      : 'hover:bg-slate-800/60 text-slate-300'
                  }`}
                >
                  <div className="flex items-center gap-2 truncate">
                    <Hash className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                    <span className="truncate">{channel.name}</span>
                  </div>
                  {channel.messageCount !== undefined && channel.messageCount > 0 && (
                    <span className="text-[10px] bg-slate-800 text-slate-400 px-1.5 py-0.5 rounded-md">
                      {channel.messageCount}
                    </span>
                  )}
                  {(channel.unreadCount || 0) > 0 && (
                    <span className="ml-1 min-w-4 rounded-full bg-indigo-600 px-1.5 py-0.5 text-center text-[10px] font-bold text-white">
                      {channel.unreadCount}
                    </span>
                  )}
                </button>
              ))}
            </div>
          </div>

          {/* Private Groups Section */}
          <div>
            <div className="px-2 pb-2 flex items-center justify-between">
              <span className="text-[11px] font-semibold uppercase tracking-wider text-slate-400">
                Private Groups
              </span>
              <button
                onClick={() => handleOpenCreateModal('group')}
                className="p-1 rounded hover:bg-slate-800 text-slate-400 hover:text-indigo-400 transition"
                title="Create Group"
              >
                <Plus className="w-3.5 h-3.5" />
              </button>
            </div>
            <div className="space-y-1">
              {conversations.filter(c => c.type === 'group').map(group => (
                <button
                  key={group.id}
                  onClick={() => setSelectedConv(group)}
                  className={`w-full flex items-center justify-between px-3 py-2 rounded-xl text-xs font-medium transition ${
                    selectedConv?.id === group.id
                      ? 'bg-indigo-600/20 text-indigo-300 border border-indigo-500/30'
                      : 'hover:bg-slate-800/60 text-slate-300'
                  }`}
                >
                  <div className="flex items-center gap-2 truncate">
                    <Lock className="w-3.5 h-3.5 text-amber-400 shrink-0" />
                    <span className="truncate">{group.name || 'Private Group'}</span>
                  </div>
                  {(group.unreadCount || 0) > 0 && (
                    <span className="min-w-4 rounded-full bg-indigo-600 px-1.5 py-0.5 text-center text-[10px] font-bold text-white">
                      {group.unreadCount}
                    </span>
                  )}
                </button>
              ))}
            </div>
          </div>

          {/* Direct Messages Section */}
          <div>
            <div className="px-2 pb-2 flex items-center justify-between">
              <span className="text-[11px] font-semibold uppercase tracking-wider text-slate-400">
                Direct Messages
              </span>
              <button
                onClick={() => handleOpenCreateModal('direct')}
                className="p-1 rounded hover:bg-slate-800 text-slate-400 hover:text-indigo-400 transition"
                title="New Direct Message"
              >
                <Plus className="w-3.5 h-3.5" />
              </button>
            </div>
            <div className="space-y-1">
              {conversations.filter(c => c.type === 'direct').map(dm => (
                <button
                  key={dm.id}
                  onClick={() => setSelectedConv(dm)}
                  className={`w-full flex items-center justify-between px-3 py-2 rounded-xl text-xs font-medium transition ${
                    selectedConv?.id === dm.id
                      ? 'bg-indigo-600/20 text-indigo-300 border border-indigo-500/30'
                      : 'hover:bg-slate-800/60 text-slate-300'
                  }`}
                >
                  <div className="flex items-center gap-2 truncate">
                    <User className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                    <span className="truncate">{dm.name || 'Direct Message'}</span>
                  </div>
                  {(dm.unreadCount || 0) > 0 && (
                    <span className="min-w-4 rounded-full bg-indigo-600 px-1.5 py-0.5 text-center text-[10px] font-bold text-white">
                      {dm.unreadCount}
                    </span>
                  )}
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* Main Chat Feed */}
      <div className="flex-1 flex flex-col h-full min-w-0 bg-slate-950">
        {selectedConv ? (
          <>
            {/* Conversation Header */}
            <div className="p-4 border-b border-slate-800 bg-slate-900/60 backdrop-blur-md flex items-center justify-between gap-4">
              <div>
                <div className="flex items-center gap-2">
                  {selectedConv.type === 'channel' ? (
                    <Hash className="w-5 h-5 text-indigo-400" />
                  ) : selectedConv.type === 'group' ? (
                    <Lock className="w-5 h-5 text-amber-400" />
                  ) : (
                    <User className="w-5 h-5 text-indigo-400" />
                  )}
                  <h1 className="text-lg font-bold text-slate-100">
                    {selectedConv.name}
                  </h1>
                </div>
                {selectedConv.topic && (
                  <p className="text-xs text-slate-400 mt-0.5 line-clamp-1">
                    {selectedConv.topic}
                  </p>
                )}
              </div>

              <div className="flex items-center gap-3">
                {onStartCall && (
                  <button
                    onClick={handleStartCall}
                    className="px-3.5 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white transition flex items-center gap-2 text-xs font-semibold shadow-lg shadow-indigo-600/30"
                  >
                    <Video className="w-4 h-4" />
                    Start Video Call
                  </button>
                )}
              </div>
            </div>

            {/* Message Stream */}
            <div className="flex-1 overflow-y-auto p-6 space-y-4">
              {messagesLoading && messages.length === 0 ? (
                <div className="flex items-center justify-center h-48 text-slate-400 gap-2">
                  <RefreshCw className="w-5 h-5 animate-spin text-indigo-400" />
                  <span className="text-sm">Loading messages...</span>
                </div>
              ) : messages.length === 0 ? (
                <div className="text-center text-slate-500 py-12 text-sm">
                  No messages yet. Send a message to start the conversation!
                </div>
              ) : (
                messages.map(msg => {
                  const currentUserId = api.currentUser?.id;
                  const isMe = currentUserId ? (msg.senderId === currentUserId) : false;

                  return (
                    <div
                      key={msg.id}
                      className={`group relative flex items-start gap-3.5 p-3 rounded-2xl hover:bg-slate-900/60 transition border border-transparent hover:border-slate-800 ${
                        isMe ? 'flex-row-reverse justify-start' : 'flex-row justify-start'
                      }`}
                    >
                      {/* User Avatar */}
                      <div className={`w-9 h-9 rounded-full flex items-center justify-center font-bold text-xs shrink-0 shadow-md ${
                        isMe 
                          ? 'bg-gradient-to-br from-indigo-500 to-purple-600 text-white'
                          : 'bg-gradient-to-br from-slate-700 to-slate-800 text-slate-200 border border-slate-700'
                      }`}>
                        {(msg.senderDisplayName || msg.senderId || 'TM').slice(0, 2).toUpperCase()}
                      </div>

                      {/* Content */}
                      <div className={`flex-1 min-w-0 flex flex-col ${isMe ? 'items-end text-right' : 'items-start text-left'}`}>
                        <div className={`flex items-center gap-2 mb-1 ${isMe ? 'flex-row-reverse' : 'flex-row'}`}>
                          <span className="text-xs font-bold text-slate-200">
                            {isMe ? 'You' : (msg.senderDisplayName || `User ${msg.senderId.slice(0, 4)}`)}
                          </span>
                          <span className="text-[10px] text-slate-500">
                            {msg.createdAt ? new Date(msg.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : 'Just now'}
                          </span>
                          {msg.isPinned && (
                            <span className="flex items-center gap-1 text-[10px] font-semibold text-amber-400 bg-amber-500/10 px-1.5 py-0.5 rounded border border-amber-500/20">
                              <Pin className="w-3 h-3" /> Pinned
                            </span>
                          )}
                          {msg.isBookmarkedByMe && (
                            <span className="flex items-center gap-1 text-[10px] font-semibold text-indigo-400 bg-indigo-500/10 px-1.5 py-0.5 rounded border border-indigo-500/20">
                              <Bookmark className="w-3 h-3" /> Bookmarked
                            </span>
                          )}
                        </div>

                        {/* Message Bubble */}
                        <div className={`p-3 rounded-2xl text-xs leading-relaxed whitespace-pre-wrap shadow-md max-w-[80%] text-left ${
                          isMe
                            ? 'bg-indigo-600 text-white rounded-tr-none border border-indigo-500/40'
                            : 'bg-slate-900 text-slate-200 rounded-tl-none border border-slate-800'
                        }`}>
                          {msg.body}
                        </div>

                        {/* Reaction Pills */}
                        {msg.reactions && msg.reactions.length > 0 && (
                          <div className={`flex flex-wrap items-center gap-1.5 mt-2 ${isMe ? 'justify-end' : 'justify-start'}`}>
                            {msg.reactions.map((r, i) => (
                              <button
                                key={i}
                                onClick={() => handleAddReaction(msg.id, r.emoji)}
                                className={`flex items-center gap-1 px-2 py-0.5 rounded-full text-[11px] font-medium border transition ${
                                  r.didReact
                                    ? 'bg-indigo-500/20 border-indigo-500/40 text-indigo-300'
                                    : 'bg-slate-900 border-slate-800 text-slate-400 hover:text-slate-200'
                                }`}
                              >
                                <span>{r.emoji}</span>
                                <span>{r.count}</span>
                              </button>
                            ))}
                          </div>
                        )}

                        {/* Reply Thread Button */}
                        {msg.replyCount !== undefined && msg.replyCount > 0 && (
                          <button
                            onClick={() => openThread(msg.id)}
                            className="mt-2 text-[11px] font-semibold text-indigo-400 hover:underline flex items-center gap-1"
                          >
                            <MessageSquare className="w-3 h-3" />
                            {msg.replyCount} {msg.replyCount === 1 ? 'reply' : 'replies'}
                          </button>
                        )}
                      </div>

                      {/* Quick Hover Actions Toolbar */}
                      <div className={`absolute top-3 hidden group-hover:flex items-center gap-1 bg-slate-900 border border-slate-800 rounded-xl p-1 shadow-lg backdrop-blur-md z-10 ${
                        isMe ? 'left-3' : 'right-3'
                      }`}>
                        {/* Emoji Quick Bar */}
                        {EMOJI_PICKER.slice(0, 3).map(emoji => (
                          <button
                            key={emoji}
                            onClick={() => handleAddReaction(msg.id, emoji)}
                            className="p-1 rounded hover:bg-slate-800 text-xs"
                            title={`React ${emoji}`}
                          >
                            {emoji}
                          </button>
                        ))}

                        <div className="w-px h-4 bg-slate-800 mx-0.5" />

                        <button
                          onClick={() => openThread(msg.id)}
                          className="p-1 rounded hover:bg-slate-800 text-slate-400 hover:text-slate-200"
                          title="Reply in thread"
                        >
                          <MessageSquare className="w-3.5 h-3.5" />
                        </button>

                        <button
                          onClick={() => handlePin(msg.id)}
                          className="p-1 rounded hover:bg-slate-800 text-slate-400 hover:text-amber-400"
                          title="Pin message"
                        >
                          <Pin className="w-3.5 h-3.5" />
                        </button>

                        <button
                          onClick={() => handleBookmark(msg.id)}
                          className="p-1 rounded hover:bg-slate-800 text-slate-400 hover:text-indigo-400"
                          title="Bookmark message"
                        >
                          <Bookmark className="w-3.5 h-3.5" />
                        </button>

                        <button
                          onClick={() => {
                            setConvertingMessage(msg);
                            setTaskTitle(msg.body);
                          }}
                          className="p-1 rounded hover:bg-slate-800 text-slate-400 hover:text-emerald-400"
                          title="Convert to Task"
                        >
                          <CheckSquare className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </div>
                  );
                })
              )}
              <div ref={messagesEndRef} />
            </div>

            {/* Input Bar */}
            <div className="p-4 border-t border-slate-800 bg-slate-900/40 relative">
              {/* Slash Command Hints Overlay */}
              {showSlashHints && (
                <div className="absolute bottom-full left-4 mb-2 w-72 bg-slate-900 border border-slate-800 rounded-2xl p-2 shadow-xl z-20 space-y-1">
                  <div className="px-2 py-1 text-[10px] font-semibold text-slate-500 uppercase tracking-wider">
                    Slash Commands
                  </div>
                  {SLASH_COMMANDS.map(sc => (
                    <button
                      key={sc.cmd}
                      onClick={() => {
                        setInputText(`${sc.cmd} `);
                        setShowSlashHints(false);
                      }}
                      className="w-full text-left px-2.5 py-1.5 rounded-xl hover:bg-slate-800 flex items-center justify-between text-xs transition"
                    >
                      <span className="font-mono font-bold text-indigo-400">{sc.cmd}</span>
                      <span className="text-[10px] text-slate-400">{sc.desc}</span>
                    </button>
                  ))}
                </div>
              )}

              <form onSubmit={handleSendMessage} className="flex items-center gap-2">
                <input
                  type="text"
                  placeholder={`Message #${selectedConv.name} (type / for commands)...`}
                  value={inputText}
                  onChange={handleInputChange}
                  className="flex-1 bg-slate-950 border border-slate-800 rounded-xl px-4 py-2.5 text-xs text-slate-200 focus:outline-none focus:border-indigo-500 transition"
                />
                <button
                  type="submit"
                  disabled={!inputText.trim()}
                  className="p-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white transition shadow-lg shadow-indigo-600/30"
                >
                  <Send className="w-4 h-4" />
                </button>
              </form>
            </div>
          </>
        ) : (
          <div className="flex-1 flex items-center justify-center text-slate-500 text-sm">
            Select a channel or direct message to start chatting
          </div>
        )}
      </div>

      {/* Thread Drawer (Right Pane) */}
      {activeThreadBundle && (
        <div className="w-80 border-l border-slate-800 bg-slate-900/80 flex flex-col h-full shrink-0">
          <div className="p-4 border-b border-slate-800 flex items-center justify-between">
            <h3 className="font-bold text-sm text-slate-100 flex items-center gap-2">
              <MessageSquare className="w-4 h-4 text-indigo-400" />
              Thread Reply
            </h3>
            <button
              onClick={() => setActiveThreadBundle(null)}
              className="p-1 rounded-md text-slate-400 hover:text-slate-200 hover:bg-slate-800"
            >
              <X className="w-4 h-4" />
            </button>
          </div>

          <div className="flex-1 overflow-y-auto p-4 space-y-4">
            {/* Root Message */}
            <div className="bg-slate-950/80 border border-slate-800 rounded-2xl p-3">
              <span className="text-xs font-bold text-slate-300">
                {activeThreadBundle.rootMessage.senderDisplayName || activeThreadBundle.rootMessage.senderId}
              </span>
              <p className="text-xs text-slate-400 mt-1">
                {activeThreadBundle.rootMessage.body}
              </p>
            </div>

            <div className="px-2 text-[10px] font-semibold uppercase tracking-wider text-slate-500">
              Replies ({activeThreadBundle.replies.length})
            </div>

            {/* Replies List */}
            {activeThreadBundle.replies.map(reply => (
              <div key={reply.id} className="bg-slate-900/60 border border-slate-800/60 rounded-xl p-3">
                <span className="text-xs font-bold text-slate-300">
                  {reply.senderDisplayName || reply.senderId}
                </span>
                <p className="text-xs text-slate-300 mt-1">
                  {reply.body}
                </p>
              </div>
            ))}
          </div>

          {/* Reply Input */}
          <div className="p-3 border-t border-slate-800 bg-slate-950">
            <form onSubmit={handleSendThreadReply} className="flex items-center gap-2">
              <input
                type="text"
                placeholder="Reply in thread..."
                value={threadInputText}
                onChange={(e) => setThreadInputText(e.target.value)}
                className="flex-1 bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
              />
              <button
                type="submit"
                disabled={!threadInputText.trim()}
                className="p-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white transition"
              >
                <Send className="w-3.5 h-3.5" />
              </button>
            </form>
          </div>
        </div>
      )}

      {/* Convert to Task Modal */}
      {convertingMessage && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6 w-full max-w-md shadow-2xl space-y-4">
            <h2 className="text-lg font-bold text-slate-100 flex items-center gap-2">
              <CheckSquare className="w-5 h-5 text-emerald-400" />
              Convert Message to Task
            </h2>

            <div className="space-y-3">
              <div>
                <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                  Task Title
                </label>
                <input
                  type="text"
                  value={taskTitle}
                  onChange={(e) => setTaskTitle(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs text-slate-200 focus:outline-none focus:border-indigo-500 mt-1"
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                  Target Task List ID
                </label>
                <input
                  type="text"
                  value={targetListId}
                  onChange={(e) => setTargetListId(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs text-slate-200 focus:outline-none focus:border-indigo-500 mt-1"
                />
              </div>
            </div>

            <div className="flex items-center justify-end gap-3 pt-4 border-t border-slate-800">
              <button
                onClick={() => setConvertingMessage(null)}
                className="px-4 py-2 rounded-xl text-xs font-medium bg-slate-800 text-slate-300 hover:bg-slate-700"
              >
                Cancel
              </button>
              <button
                onClick={handleConvertToTask}
                className="px-4 py-2 rounded-xl text-xs font-medium bg-emerald-600 text-white hover:bg-emerald-500 shadow-lg shadow-emerald-600/30"
              >
                Create Task
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Create Conversation / Channel / Group Modal */}
      {showCreateModal && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6 w-full max-w-lg shadow-2xl space-y-4">
            <div className="flex items-center justify-between pb-3 border-b border-slate-800">
              <h2 className="text-lg font-bold text-slate-100 flex items-center gap-2">
                <Plus className="w-5 h-5 text-indigo-400" />
                Create New {createType === 'channel' ? 'Channel' : createType === 'group' ? 'Private Group' : 'Direct Message'}
              </h2>
              <button
                onClick={() => setShowCreateModal(false)}
                className="p-1 rounded-lg text-slate-400 hover:text-slate-200 hover:bg-slate-800"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleCreateConversation} className="space-y-4">
              {/* Type Switcher */}
              <div>
                <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider block mb-1">
                  Type
                </label>
                <div className="grid grid-cols-3 gap-2 bg-slate-950 p-1 rounded-xl border border-slate-800">
                  <button
                    type="button"
                    onClick={() => setCreateType('channel')}
                    className={`py-1.5 rounded-lg text-xs font-semibold flex items-center justify-center gap-1.5 transition ${
                      createType === 'channel'
                        ? 'bg-indigo-600 text-white shadow-md'
                        : 'text-slate-400 hover:text-slate-200'
                    }`}
                  >
                    <Hash className="w-3.5 h-3.5" /> Channel
                  </button>
                  <button
                    type="button"
                    onClick={() => setCreateType('group')}
                    className={`py-1.5 rounded-lg text-xs font-semibold flex items-center justify-center gap-1.5 transition ${
                      createType === 'group'
                        ? 'bg-indigo-600 text-white shadow-md'
                        : 'text-slate-400 hover:text-slate-200'
                    }`}
                  >
                    <Lock className="w-3.5 h-3.5" /> Group
                  </button>
                  <button
                    type="button"
                    onClick={() => setCreateType('direct')}
                    className={`py-1.5 rounded-lg text-xs font-semibold flex items-center justify-center gap-1.5 transition ${
                      createType === 'direct'
                        ? 'bg-indigo-600 text-white shadow-md'
                        : 'text-slate-400 hover:text-slate-200'
                    }`}
                  >
                    <User className="w-3.5 h-3.5" /> Direct
                  </button>
                </div>
              </div>

              {/* Name (for channel/group) */}
              {createType !== 'direct' && (
                <div>
                  <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider block mb-1">
                    {createType === 'channel' ? 'Channel Name' : 'Group Name'}
                  </label>
                  <input
                    type="text"
                    placeholder={createType === 'channel' ? 'e.g. announcements' : 'e.g. Project Mobile Sync'}
                    value={createName}
                    onChange={(e) => setCreateName(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
                    required
                  />
                </div>
              )}

              {/* Topic / Description (for channel/group) */}
              {createType !== 'direct' && (
                <div>
                  <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider block mb-1">
                    Topic / Description (Optional)
                  </label>
                  <input
                    type="text"
                    placeholder="What is this conversation about?"
                    value={createTopic}
                    onChange={(e) => setCreateTopic(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
                  />
                </div>
              )}

              {/* Team Member Picker */}
              <div>
                <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider block mb-1">
                  {createType === 'direct' ? 'Select Team Member' : 'Add Members from Organization'}
                </label>
                {orgMembers.length === 0 ? (
                  <p className="text-xs text-slate-500 italic py-2">Loading organization members...</p>
                ) : (
                  <div className="max-h-40 overflow-y-auto space-y-1 bg-slate-950 border border-slate-800 rounded-xl p-2">
                    {orgMembers.map(member => {
                      const isSelected = selectedMemberIds.includes(member.userId);
                      return (
                        <div
                          key={member.id}
                          onClick={() => toggleMemberSelection(member.userId)}
                          className={`flex items-center justify-between p-2 rounded-lg cursor-pointer transition ${
                            isSelected
                              ? 'bg-indigo-600/20 border border-indigo-500/40 text-indigo-200'
                              : 'hover:bg-slate-900 text-slate-300'
                          }`}
                        >
                          <div className="flex items-center gap-2">
                            <div className="w-6 h-6 rounded-full bg-indigo-600/40 flex items-center justify-center text-[10px] font-bold text-indigo-200">
                              {member.displayName.slice(0, 2).toUpperCase()}
                            </div>
                            <div>
                              <p className="text-xs font-semibold">{member.displayName}</p>
                              <p className="text-[10px] text-slate-500">{member.email}</p>
                            </div>
                          </div>
                          <input
                            type={createType === 'direct' ? 'radio' : 'checkbox'}
                            checked={isSelected}
                            onChange={() => {}}
                            className="accent-indigo-500 pointer-events-none"
                          />
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>

              {/* Actions */}
              <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setShowCreateModal(false)}
                  className="px-4 py-2 rounded-xl text-xs font-medium bg-slate-800 text-slate-300 hover:bg-slate-700 transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={creatingConv}
                  className="px-4 py-2 rounded-xl text-xs font-medium bg-indigo-600 text-white hover:bg-indigo-500 disabled:opacity-50 transition shadow-lg shadow-indigo-600/30 flex items-center gap-2"
                >
                  {creatingConv && <RefreshCw className="w-3.5 h-3.5 animate-spin" />}
                  Create {createType === 'channel' ? 'Channel' : createType === 'group' ? 'Group' : 'DM'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
