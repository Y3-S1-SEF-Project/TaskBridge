import React, { useState, useEffect, useRef, useCallback } from 'react';
import * as signalR from '@microsoft/signalr';
import type { AdminConversation, AdminChatMessage } from '../types';
import {
  fetchAdminConversations,
  fetchAdminMessages,
  sendAdminMessage,
  deleteAdminMessage,
} from '../api';

const QUICK_RESPONSES = [
  '👋 Hello! How can I assist you today?',
  '🔍 Thank you for the details. I am reviewing this right now.',
  '✅ We have flagged this inquiry for review and updated your ticket status.',
  '⚠️ Friendly reminder: All communications and payments must stay inside TaskBridge.',
  '🎉 Your inquiry has been resolved. Is there anything else I can help with?',
];

export const ChatsView: React.FC = () => {
  const [conversations, setConversations] = useState<AdminConversation[]>([]);
  const [selectedConv, setSelectedConv] = useState<AdminConversation | null>(null);
  const [messages, setMessages] = useState<AdminChatMessage[]>([]);
  const [loadingConvs, setLoadingConvs] = useState<boolean>(true);
  const [loadingMessages, setLoadingMessages] = useState<boolean>(false);
  const [replyText, setReplyText] = useState<string>('');
  const [sending, setSending] = useState<boolean>(false);
  const [search, setSearch] = useState<string>('');
  const [activeTab, setActiveTab] = useState<'all' | 'support' | 'jobs'>('all');
  const [hubStatus, setHubStatus] = useState<'connected' | 'connecting' | 'disconnected'>('connecting');
  const [errorMsg, setErrorMsg] = useState<string>('');
  const [mobileView, setMobileView] = useState<'list' | 'chat'>('list');

  const hubConnectionRef = useRef<signalR.HubConnection | null>(null);
  const streamEndRef = useRef<HTMLDivElement | null>(null);
  const selectedConvRef = useRef<AdminConversation | null>(null);
  selectedConvRef.current = selectedConv;

  const scrollToBottom = useCallback((smooth = true) => {
    setTimeout(() => {
      streamEndRef.current?.scrollIntoView({ behavior: smooth ? 'smooth' : 'auto' });
    }, 50);
  }, []);

  // ── Load Initial Conversations ──
  const loadConversations = useCallback(async () => {
    try {
      setLoadingConvs(true);
      setErrorMsg('');
      const data = await fetchAdminConversations();
      setConversations(data);

      // Auto-select first conversation on desktop if none selected
      if (!selectedConvRef.current && data.length > 0 && typeof window !== 'undefined' && window.innerWidth > 900) {
        setSelectedConv(data[0]);
      }
    } catch (err: any) {
      setErrorMsg(err.message || 'Failed to load conversations.');
    } finally {
      setLoadingConvs(false);
    }
  }, []);

  // ── Load Messages for Selected Conversation ──
  const loadMessages = useCallback(async (convId: string) => {
    try {
      setLoadingMessages(true);
      const data = await fetchAdminMessages(convId);
      setMessages(data);
      scrollToBottom(false);
    } catch (err: any) {
      console.error('[ChatsView] Load messages error:', err);
    } finally {
      setLoadingMessages(false);
    }
  }, [scrollToBottom]);

  // When selected conversation changes
  useEffect(() => {
    if (selectedConv) {
      loadMessages(selectedConv.id);
    } else {
      setMessages([]);
    }
  }, [selectedConv, loadMessages]);

  // ── Load Conversations immediately on mount ──
  useEffect(() => {
    loadConversations();
  }, [loadConversations]);

  // ── Setup SignalR Real-Time Hub ──
  useEffect(() => {
    let isMounted = true;
    const connection = new signalR.HubConnectionBuilder()
      .withUrl('/hubs/chat', {
        accessTokenFactory: () => localStorage.getItem('taskbridge_admin_token') || '',
      })
      .withAutomaticReconnect([0, 2000, 5000, 10000])
      .configureLogging(signalR.LogLevel.Warning)
      .build();

    hubConnectionRef.current = connection;

    connection.onreconnecting(() => {
      if (isMounted) setHubStatus('connecting');
    });
    connection.onreconnected(() => {
      if (isMounted) setHubStatus('connected');
    });
    connection.onclose(() => {
      if (isMounted) setHubStatus('disconnected');
    });

    // Real-time message receiver
    connection.on('ReceiveMessage', (newMsg: AdminChatMessage) => {
      // If belongs to currently open conversation, append to stream
      if (selectedConvRef.current && selectedConvRef.current.id === newMsg.conversationId) {
        setMessages(prev => {
          if (prev.some(m => m.id === newMsg.id)) return prev;
          return [...prev, newMsg];
        });
        scrollToBottom(true);
      }

      // Update conversation in list (snippet and timestamp)
      setConversations(prev => {
        const idx = prev.findIndex(c => c.id === newMsg.conversationId);
        if (idx !== -1) {
          const updated = {
            ...prev[idx],
            lastMessageSnippet: newMsg.content,
            lastMessageAt: newMsg.createdAt,
            unreadCustomer:
              selectedConvRef.current?.id === newMsg.conversationId
                ? prev[idx].unreadCustomer
                : prev[idx].unreadCustomer + 1,
          };
          const next = [...prev];
          next.splice(idx, 1);
          return [updated, ...next];
        }
        return prev;
      });
    });

    // Real-time message deletion
    connection.on('MessageDeleted', (data: { conversationId: string; messageId: string }) => {
      if (selectedConvRef.current && selectedConvRef.current.id === data.conversationId) {
        setMessages(prev => prev.filter(m => m.id !== data.messageId));
      }
    });

    // New support conversation initiated by customer or provider
    connection.on('NewSupportConversation', (newConv: AdminConversation) => {
      setConversations(prev => {
        if (prev.some(c => c.id === newConv.id)) return prev;
        return [newConv, ...prev];
      });
    });

    // Start connection non-blockingly
    connection
      .start()
      .then(() => {
        if (isMounted) setHubStatus('connected');
      })
      .catch(err => {
        if (isMounted) {
          console.warn('[ChatsView] SignalR connection warning:', err);
          setHubStatus('disconnected');
        }
      });

    return () => {
      isMounted = false;
      try {
        if (connection.state === signalR.HubConnectionState.Connected) {
          connection.stop();
        }
      } catch (_) {}
    };
  }, [scrollToBottom]);

  // ── Send Admin Message ──
  const handleSendMessage = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    const text = replyText.trim();
    if (!text || !selectedConv || sending) return;

    try {
      setSending(true);
      const sentMsg = await sendAdminMessage(selectedConv.id, text);
      setMessages(prev => {
        if (prev.some(m => m.id === sentMsg.id)) return prev;
        return [...prev, sentMsg];
      });
      setReplyText('');
      scrollToBottom(true);

      // Update snippet in list
      setConversations(prev =>
        prev.map(c =>
          c.id === selectedConv.id
            ? { ...c, lastMessageSnippet: text, lastMessageAt: new Date().toISOString() }
            : c
        )
      );
    } catch (err: any) {
      alert(err.message || 'Failed to send message.');
    } finally {
      setSending(false);
    }
  };

  // ── Delete Message ──
  const handleDeleteMessage = async (messageId: string) => {
    if (!window.confirm('Are you sure you want to delete this message? This action will remove it in real-time for all parties.')) {
      return;
    }

    try {
      await deleteAdminMessage(messageId);
      setMessages(prev => prev.filter(m => m.id !== messageId));
    } catch (err: any) {
      alert(err.message || 'Failed to delete message.');
    }
  };

  // ── Filter and Search Logic ──
  const filteredConversations = conversations.filter(c => {
    if (activeTab === 'support' && !c.isSupportChat) return false;
    if (activeTab === 'jobs' && c.isSupportChat) return false;

    if (search.trim()) {
      const q = search.toLowerCase();
      const matchName = c.customerName.toLowerCase().includes(q) || c.providerName.toLowerCase().includes(q);
      const matchRef = (c.bookingReference || '').toLowerCase().includes(q);
      const matchSnippet = (c.lastMessageSnippet || '').toLowerCase().includes(q);
      return matchName || matchRef || matchSnippet;
    }

    return true;
  });

  const supportCount = conversations.filter(c => c.isSupportChat).length;
  const jobCount = conversations.filter(c => !c.isSupportChat).length;

  const formatChatTime = (isoString?: string | null) => {
    if (!isoString) return '';
    try {
      const date = new Date(isoString);
      const now = new Date();
      const diffMs = now.getTime() - date.getTime();
      const diffMins = Math.floor(diffMs / 60000);

      if (diffMins < 1) return 'Just now';
      if (diffMins < 60) return `${diffMins}m ago`;
      if (diffMins < 1440) {
        return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
      }
      return date.toLocaleDateString([], { month: 'short', day: 'numeric' });
    } catch {
      return '';
    }
  };

  return (
    <div className="admin-content">
      {/* ── Page Header ── */}
      <div className="admin-page-header admin-chat-page-header">
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <h1 className="admin-page-title" style={{ margin: 0 }}>
              Live Support &amp; Communications Desk
            </h1>
            <div
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: '6px',
                padding: '4px 10px',
                borderRadius: '12px',
                fontSize: '11px',
                fontWeight: 600,
                background:
                  hubStatus === 'connected'
                    ? '#dcfce7'
                    : hubStatus === 'connecting'
                    ? '#fef3c7'
                    : '#fee2e2',
                color:
                  hubStatus === 'connected'
                    ? '#15803d'
                    : hubStatus === 'connecting'
                    ? '#b45309'
                    : '#b91c1c',
                border:
                  hubStatus === 'connected'
                    ? '1px solid #bbf7d0'
                    : hubStatus === 'connecting'
                    ? '1px solid #fde68a'
                    : '1px solid #fecaca',
              }}
            >
              <span
                style={{
                  width: '7px',
                  height: '7px',
                  borderRadius: '50%',
                  background:
                    hubStatus === 'connected'
                      ? '#16a34a'
                      : hubStatus === 'connecting'
                      ? '#d97706'
                      : '#dc2626',
                }}
              />
              {hubStatus === 'connected'
                ? 'WebSocket Live'
                : hubStatus === 'connecting'
                ? 'Connecting...'
                : 'Offline'}
            </div>
          </div>
          <p className="admin-page-subtitle">
            Real-time agent chat desk for customer &amp; provider support inquiries, dispute transcript oversight, and instant message deletion.
          </p>
        </div>

        <button
          type="button"
          className="admin-export-btn"
          onClick={() => {
            if (!selectedConv) return;
            const content = messages
              .map(
                m =>
                  `[${new Date(m.createdAt).toLocaleString()}] ${m.senderName} (${m.isSupportSender ? 'Support Agent' : 'User'}): ${m.content}`
              )
              .join('\n');
            const blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `Transcript-${selectedConv.customerName.replace(/\s+/g, '_')}-${selectedConv.id.substring(0, 8)}.txt`;
            a.click();
            URL.revokeObjectURL(url);
          }}
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
            <polyline points="7 10 12 15 17 10" />
            <line x1="12" y1="15" x2="12" y2="3" />
          </svg>
          Export Active Transcript
        </button>
      </div>

      {/* ── Metric Cards ── */}
      <div className="admin-metrics-grid admin-chat-metrics">
        <div className="admin-metric-card">
          <p className="admin-metric-label">Live Support Chats 🛡️</p>
          <div className="admin-metric-value" style={{ color: '#166534' }}>
            {supportCount}
          </div>
          <p className="admin-metric-note positive">Real-time Admin Agent Connected</p>
        </div>

        <div className="admin-metric-card">
          <p className="admin-metric-label">Service Job Audits</p>
          <div className="admin-metric-value">{jobCount}</div>
          <p className="admin-metric-note">Customer ↔ Provider direct chats</p>
        </div>

        <div className="admin-metric-card">
          <p className="admin-metric-label">Active Transcripts</p>
          <div className="admin-metric-value">{conversations.length}</div>
          <p className="admin-metric-note positive">Tamper-evident logs &amp; encryption</p>
        </div>

        <div className="admin-metric-card">
          <p className="admin-metric-label">Agent Desk Status</p>
          <div
            className="admin-metric-value"
            style={{
              fontSize: '20px',
              color: hubStatus === 'connected' ? '#166534' : '#b45309',
            }}
          >
            {hubStatus === 'connected' ? 'Ready to Assist' : 'Reconnecting...'}
          </div>
          <p className="admin-metric-note">Instant 2-way SignalR stream</p>
        </div>
      </div>

      {errorMsg && (
        <div className="admin-error-banner" style={{ marginBottom: '16px' }}>
          <span>⚠️ {errorMsg}</span>
          <button type="button" onClick={loadConversations} style={{ marginLeft: '12px', fontWeight: 600 }}>
            Retry
          </button>
        </div>
      )}

      {/* ── Main Chat Interface ── */}
      <div className={`admin-chat-container mobile-view-${mobileView}`}>
        {/* Left Column: Conversations Directory */}
        <div className={`admin-chat-sidebar ${mobileView === 'chat' && selectedConv ? 'mobile-hidden' : ''}`}>
          <div className="admin-chat-search-wrap">
            <div
              className="admin-search-wrapper"
              style={{
                width: '100%',
                background: '#ffffff',
                border: '1px solid var(--admin-border)',
                borderRadius: '10px',
                padding: '8px 12px',
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                boxSizing: 'border-box',
              }}
            >
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="#64736a" strokeWidth="2.2">
                <circle cx="11" cy="11" r="8" />
                <line x1="21" y1="21" x2="16.65" y2="16.65" />
              </svg>
              <input
                type="text"
                className="admin-search-input"
                placeholder="Search conversations, names..."
                value={search}
                onChange={e => setSearch(e.target.value)}
                style={{
                  border: 'none',
                  outline: 'none',
                  fontSize: '13px',
                  color: '#141f19',
                  background: 'transparent',
                  colorScheme: 'light',
                  width: '100%',
                }}
              />
              {search && (
                <button
                  type="button"
                  onClick={() => setSearch('')}
                  style={{
                    background: 'none',
                    border: 'none',
                    color: '#8a9990',
                    cursor: 'pointer',
                    fontSize: '14px',
                  }}
                >
                  ✕
                </button>
              )}
            </div>

            {/* Filter Tabs */}
            <div className="admin-chat-tabs">
              <button
                type="button"
                className={`admin-chat-tab-btn ${activeTab === 'all' ? 'active' : ''}`}
                onClick={() => setActiveTab('all')}
              >
                All ({conversations.length})
              </button>
              <button
                type="button"
                className={`admin-chat-tab-btn ${activeTab === 'support' ? 'active' : ''}`}
                onClick={() => setActiveTab('support')}
              >
                🛡️ Support ({supportCount})
              </button>
              <button
                type="button"
                className={`admin-chat-tab-btn ${activeTab === 'jobs' ? 'active' : ''}`}
                onClick={() => setActiveTab('jobs')}
              >
                💼 Jobs ({jobCount})
              </button>
            </div>
          </div>

          {/* Conversation List */}
          <div className="admin-chat-conv-list">
            {loadingConvs ? (
              <div style={{ padding: '32px 16px', textAlign: 'center', color: '#64736a', fontSize: '13px' }}>
                <div className="admin-spinner" style={{ margin: '0 auto 10px' }} />
                Loading conversations...
              </div>
            ) : filteredConversations.length === 0 ? (
              <div style={{ padding: '36px 16px', textAlign: 'center', color: '#8a9990', fontSize: '13px' }}>
                <div style={{ fontSize: '32px', marginBottom: '8px' }}>💬</div>
                No conversations found matching filters.
              </div>
            ) : (
              filteredConversations.map(conv => {
                const isSelected = selectedConv?.id === conv.id;
                return (
                  <div
                    key={conv.id}
                    className={`admin-chat-conv-card ${isSelected ? 'selected' : ''} ${conv.isSupportChat ? 'support-chat' : ''}`}
                    onClick={() => {
                      setSelectedConv(conv);
                      setMobileView('chat');
                    }}
                  >
                    <div style={{ display: 'flex', gap: '12px', alignItems: 'flex-start' }}>
                      {/* Avatar */}
                      {conv.isSupportChat ? (
                        <div
                          style={{
                            width: '40px',
                            height: '40px',
                            borderRadius: '50%',
                            background: 'linear-gradient(135deg, #1b5e3f 0%, #256b4a 100%)',
                            color: '#ffffff',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            fontSize: '18px',
                            flexShrink: 0,
                            boxShadow: '0 2px 6px rgba(37, 107, 74, 0.25)',
                          }}
                        >
                          🛡️
                        </div>
                      ) : (
                        <div
                          style={{
                            width: '40px',
                            height: '40px',
                            borderRadius: '50%',
                            background: '#e3ebe6',
                            color: '#1b5e3f',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            fontWeight: 700,
                            fontSize: '15px',
                            flexShrink: 0,
                          }}
                        >
                          {conv.customerName.charAt(0).toUpperCase()}
                        </div>
                      )}

                      {/* Content */}
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '3px' }}>
                          <span
                            style={{
                              fontSize: '13.5px',
                              fontWeight: 700,
                              color: '#141f19',
                              overflow: 'hidden',
                              textOverflow: 'ellipsis',
                              whiteSpace: 'nowrap',
                            }}
                          >
                            {conv.customerName}
                          </span>
                          <span style={{ fontSize: '11px', color: '#8a9990', flexShrink: 0, marginLeft: '6px' }}>
                            {formatChatTime(conv.lastMessageAt)}
                          </span>
                        </div>

                        <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '4px' }}>
                          {conv.isSupportChat ? (
                            <span className="admin-chat-badge-support">
                              <span>🛡️</span> Official Support
                            </span>
                          ) : (
                            <span style={{ fontSize: '11px', color: '#64736a' }}>
                              ↔ {conv.providerName}
                            </span>
                          )}

                          {!conv.isSupportChat && conv.customerRole && (
                            <span
                              style={{
                                fontSize: '10px',
                                padding: '1px 5px',
                                borderRadius: '4px',
                                background: conv.customerRole === 'Provider' ? '#ede9fe' : '#e0f2fe',
                                color: conv.customerRole === 'Provider' ? '#5b21b6' : '#0369a1',
                                fontWeight: 600,
                              }}
                            >
                              {conv.customerRole}
                            </span>
                          )}
                        </div>

                        <p
                          style={{
                            margin: 0,
                            fontSize: '12px',
                            color: isSelected ? '#1b5e3f' : '#64736a',
                            overflow: 'hidden',
                            textOverflow: 'ellipsis',
                            whiteSpace: 'nowrap',
                          }}
                        >
                          {conv.lastMessageSnippet || 'No messages yet'}
                        </p>
                      </div>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>

        {/* Right Column: Live Chat Pane & Transcript Viewer */}
        <div className={`admin-chat-main ${mobileView === 'list' ? 'mobile-hidden' : ''}`}>
          {selectedConv ? (
            <>
              {/* Header */}
              <div className="admin-chat-header">
                <div className="admin-chat-header-user">
                  <button
                    type="button"
                    className="admin-chat-back-btn"
                    onClick={() => setMobileView('list')}
                    title="Back to conversations list"
                    aria-label="Back to conversations list"
                  >
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                      <path d="M19 12H5M12 19l-7-7 7-7" />
                    </svg>
                  </button>
                  {selectedConv.isSupportChat ? (
                    <div className="admin-chat-header-avatar support">
                      🛡️
                    </div>
                  ) : (
                    <div className="admin-chat-header-avatar user">
                      {selectedConv.customerName.charAt(0).toUpperCase()}
                    </div>
                  )}

                  <div className="admin-chat-header-details">
                    <div className="admin-chat-header-title-row">
                      <h3 className="admin-chat-header-name">
                        {selectedConv.customerName}
                      </h3>
                      {selectedConv.isSupportChat ? (
                        <span className="admin-chat-badge-support">Support</span>
                      ) : (
                        <span className="admin-badge priority-low" style={{ fontSize: '10px' }}>
                          #{selectedConv.bookingReference || 'GENERAL'}
                        </span>
                      )}
                    </div>

                    <div className="admin-chat-header-meta">
                      {selectedConv.customerPhone && (
                        <span>📞 {selectedConv.customerPhone}</span>
                      )}
                      {selectedConv.customerPhone && selectedConv.customerEmail && (
                        <span className="admin-chat-meta-dot">•</span>
                      )}
                      {selectedConv.customerEmail && (
                        <span>✉️ {selectedConv.customerEmail}</span>
                      )}
                      {!selectedConv.isSupportChat && selectedConv.customerRole && (
                        <>
                          <span className="admin-chat-meta-dot">•</span>
                          <span>{selectedConv.customerRole}</span>
                        </>
                      )}
                    </div>
                  </div>
                </div>

                <div className="admin-chat-header-actions">
                  <button
                    type="button"
                    className="admin-chat-icon-btn"
                    onClick={() => loadMessages(selectedConv.id)}
                    title="Refresh Messages"
                    aria-label="Refresh"
                  >
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.3">
                      <path d="M21.5 2v6h-6M21.34 15.57a10 10 0 1 1-.57-8.38l5.67-5.67" />
                    </svg>
                  </button>
                </div>
              </div>

              {/* Message Feed */}
              <div className="admin-chat-stream">
                {selectedConv.isSupportChat && (
                  <div className="admin-chat-security-banner">
                    <span>🛡️</span>
                    <span>Live Support Desk Connected • Encrypted</span>
                  </div>
                )}
                {loadingMessages ? (
                  <div style={{ margin: 'auto', textAlign: 'center', color: '#64736a' }}>
                    <div className="admin-spinner" style={{ margin: '0 auto 10px' }} />
                    Decrypting message stream...
                  </div>
                ) : (() => {
                  const displayMessages = messages.filter(
                    m => !m.content.includes('Welcome to TaskBridge Live Support')
                  );
                  if (displayMessages.length === 0) {
                    return (
                      <div style={{ margin: 'auto', textAlign: 'center', color: '#8a9990' }}>
                        <div style={{ fontSize: '40px', marginBottom: '8px' }}>📬</div>
                        <p style={{ fontWeight: 600, color: '#141f19', marginBottom: '4px' }}>
                          No messages yet in this session.
                        </p>
                        <p style={{ fontSize: '12.5px' }}>
                          Send a message below to connect with this user in real-time.
                        </p>
                      </div>
                    );
                  }
                  return displayMessages.map(msg => {
                    const isSupportSender = msg.isSupportSender;
                    const isCustomer = msg.senderId === selectedConv.customerId;

                    let roleType: 'customer' | 'provider' | 'support-outgoing' = 'customer';
                    let roleLabel = '';
                    let isRight = false;
                    let senderInitial = msg.senderName ? msg.senderName.charAt(0).toUpperCase() : 'U';

                    if (isSupportSender) {
                      roleType = 'support-outgoing';
                      roleLabel = selectedConv.isSupportChat ? '' : '🛡️ Support Agent';
                      isRight = true;
                    } else if (!selectedConv.isSupportChat) {
                      // In Job Chat (Customer vs Provider)
                      if (isCustomer) {
                        roleType = 'customer';
                        roleLabel = `👤 Customer • ${msg.senderName}`;
                        isRight = false;
                        senderInitial = selectedConv.customerName ? selectedConv.customerName.charAt(0).toUpperCase() : 'C';
                      } else {
                        roleType = 'provider';
                        roleLabel = `💼 Provider • ${msg.senderName}`;
                        isRight = true;
                        senderInitial = selectedConv.providerName ? selectedConv.providerName.charAt(0).toUpperCase() : 'P';
                      }
                    } else {
                      // In Direct Support Chat: no label like customer or admin
                      roleType = 'customer';
                      roleLabel = '';
                      isRight = false;
                      senderInitial = selectedConv.customerName ? selectedConv.customerName.charAt(0).toUpperCase() : 'U';
                    }

                    return (
                      <div
                        key={msg.id}
                        className={`admin-chat-bubble-row ${isRight ? 'outgoing' : 'incoming'}`}
                      >
                        {!isRight && (
                          <div className={`admin-chat-avatar ${roleType}`} title={roleLabel || undefined}>
                            {senderInitial}
                          </div>
                        )}

                        <div className={`admin-chat-bubble ${roleType}`}>
                          <button
                            type="button"
                            className="admin-chat-del-btn"
                            title="Delete message for all parties"
                            onClick={() => handleDeleteMessage(msg.id)}
                          >
                            <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                              <polyline points="3 6 5 6 21 6" />
                              <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
                            </svg>
                          </button>

                          {/* Role Label: ONLY shown in Customer ↔ Provider Job Chats, NOT in Direct Support Chat */}
                          {!selectedConv.isSupportChat && roleLabel && (
                            <div className={`admin-chat-role-badge ${roleType}`}>
                              {roleLabel}
                            </div>
                          )}

                          {msg.messageType === 'Image' && msg.mediaUrl && (
                            <div style={{ margin: '4px 0 6px', borderRadius: '8px', overflow: 'hidden' }}>
                              <img
                                src={msg.mediaUrl}
                                alt="Attachment"
                                style={{ maxWidth: '240px', maxHeight: '180px', objectFit: 'cover', display: 'block', borderRadius: '6px' }}
                              />
                            </div>
                          )}

                          <div className="admin-chat-bubble-body">
                            <span className="admin-chat-bubble-text">{msg.content}</span>
                            <span className="admin-chat-bubble-time">
                              {new Date(msg.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                              {isSupportSender && <span style={{ letterSpacing: '-1px', marginLeft: '3px' }}>✓✓</span>}
                            </span>
                          </div>
                        </div>

                        {isRight && (
                          <div className={`admin-chat-avatar ${roleType}`} title={roleLabel || undefined}>
                            {isSupportSender ? '🛡️' : senderInitial}
                          </div>
                        )}
                      </div>
                    );
                  });
                })()}
                <div ref={streamEndRef} />
              </div>

              {/* Composer: ONLY shown in Direct Support Chat! Customer ↔ Provider chats are read-only */}
              {selectedConv.isSupportChat ? (
                <div className="admin-chat-composer">
                  {/* Quick Reply Chips */}
                  <div className="admin-chat-chips">
                    {QUICK_RESPONSES.map((chip, idx) => (
                      <button
                        key={idx}
                        type="button"
                        className="admin-chat-chip"
                        onClick={() => setReplyText(chip)}
                      >
                        {chip.length > 35 ? chip.substring(0, 35) + '...' : chip}
                      </button>
                    ))}
                  </div>

                  {/* Input and Send */}
                  <form
                    onSubmit={handleSendMessage}
                    className="admin-chat-form"
                  >
                    <textarea
                      rows={1}
                      value={replyText}
                      onChange={e => setReplyText(e.target.value)}
                      onKeyDown={e => {
                        if (e.key === 'Enter' && !e.shiftKey) {
                          e.preventDefault();
                          handleSendMessage();
                        }
                      }}
                      placeholder={`Type a message to ${selectedConv.customerName}...`}
                      className="admin-chat-textarea"
                    />

                    <button
                      type="submit"
                      disabled={!replyText.trim() || sending}
                      className="admin-chat-send-btn"
                    >
                      {sending ? (
                        '...'
                      ) : (
                        <>
                          <span>Send</span>
                          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
                            <line x1="22" y1="2" x2="11" y2="13" />
                            <polygon points="22 2 15 22 11 13 2 9 22 2" />
                          </svg>
                        </>
                      )}
                    </button>
                  </form>
                </div>
              ) : (
                <div
                  style={{
                    padding: '14px 20px',
                    background: '#ffffff',
                    borderTop: '1px solid var(--admin-border-light)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    gap: '8px',
                    color: '#64736a',
                    fontSize: '12.5px',
                  }}
                >
                  <span style={{ fontSize: '15px' }}>🔒</span>
                  <span>
                    <strong>Audited Job Chat:</strong> Monitored transcript between Customer ({selectedConv.customerName}) and Provider ({selectedConv.providerName}). Read-only mode active.
                  </span>
                </div>
              )}
            </>
          ) : (
            <div style={{ margin: 'auto', textAlign: 'center', color: '#8a9990' }}>
              <div style={{ fontSize: '48px', marginBottom: '12px' }}>💬</div>
              <h3 style={{ margin: '0 0 6px', color: '#141f19', fontSize: '17px' }}>
                Select a conversation
              </h3>
              <p style={{ margin: 0, fontSize: '13.5px' }}>
                Pick a support inquiry or job chat from the left directory to inspect transcripts and chat live.
              </p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
