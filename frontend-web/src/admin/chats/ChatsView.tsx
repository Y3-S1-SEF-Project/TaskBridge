import React, { useState } from 'react';

interface ChatSession {
  id: string;
  bookingRef: string;
  customerName: string;
  providerName: string;
  lastMessage: string;
  lastTime: string;
  flaggedKeywords: boolean;
  status: 'Active' | 'Closed' | 'Audit Flagged';
}

const mockChats: ChatSession[] = [
  { id: 'CHAT-701', bookingRef: 'BK-501', customerName: 'Sithara Fernando', providerName: 'Nuwan Cleaners', lastMessage: 'I have arrived at the apartment gate, security is letting me in.', lastTime: '3 mins ago', flaggedKeywords: false, status: 'Active' },
  { id: 'CHAT-700', bookingRef: 'BK-500', customerName: 'Rohan Jayasinghe', providerName: 'Sanjaya Electricals', lastMessage: 'Please bring an additional 16A circuit breaker switch.', lastTime: '22 mins ago', flaggedKeywords: false, status: 'Active' },
  { id: 'CHAT-699', bookingRef: 'BK-495', customerName: 'Sahan Wickrama', providerName: 'Kamal Perera', lastMessage: 'Can you pay me cash directly outside the app so we avoid the fee?', lastTime: '2 hours ago', flaggedKeywords: true, status: 'Audit Flagged' },
  { id: 'CHAT-698', bookingRef: 'BK-488', customerName: 'Anuki Fernando', providerName: 'Sunil Crafts', lastMessage: 'Thank you for the quick repair, table looks brand new!', lastTime: 'Yesterday', flaggedKeywords: false, status: 'Closed' },
];

export const ChatsView: React.FC = () => {
  const [selectedChat, setSelectedChat] = useState<ChatSession>(mockChats[0]);

  return (
    <div className="admin-content">
      <div className="admin-page-header">
        <div>
          <h1 className="admin-page-title">Audited Communications Console</h1>
          <p className="admin-page-subtitle">
            Admin oversight, compliance auditing, off-platform payment keyword triggers, and dispute mediation transcripts.
          </p>
        </div>
        <button
          type="button"
          className="admin-export-btn"
          onClick={() => alert('Exporting communications audit log...')}
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
            <polyline points="7 10 12 15 17 10" />
            <line x1="12" y1="15" x2="12" y2="3" />
          </svg>
          Export Chat Transcripts
        </button>
      </div>

      <div className="admin-metrics-grid">
        <div className="admin-metric-card">
          <p className="admin-metric-label">Active Job Chats</p>
          <div className="admin-metric-value">48</div>
          <p className="admin-metric-note positive">End-to-end encrypted storage</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Policy Violation Alerts</p>
          <div className="admin-metric-value" style={{ color: '#c81e1e' }}>1</div>
          <p className="admin-metric-note">Off-platform payment keyword</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Avg Provider Response</p>
          <div className="admin-metric-value">3.4m</div>
          <p className="admin-metric-note positive">High communication speed</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Audited for Disputes</p>
          <div className="admin-metric-value">100%</div>
          <p className="admin-metric-note positive">Tamper-evident logs</p>
        </div>
      </div>

      {/* Split layout: Conversations list on left, transcript on right */}
      <div className="admin-charts-grid" style={{ gridTemplateColumns: '1fr 1.6fr' }}>
        {/* Left: Chat List */}
        <div className="admin-table-card">
          <h3 className="admin-table-title" style={{ margin: '20px 20px 14px' }}>Audited Sessions</h3>
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            {mockChats.map(c => (
              <div
                key={c.id}
                onClick={() => setSelectedChat(c)}
                style={{
                  padding: '16px 20px',
                  borderBottom: '1px solid #edf2ef',
                  cursor: 'pointer',
                  backgroundColor: selectedChat.id === c.id ? '#eef7f2' : 'transparent',
                  transition: 'background 0.15s ease'
                }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '6px' }}>
                  <span style={{ fontWeight: 600, fontSize: '13.5px', color: '#141f19' }}>
                    {c.customerName} ↔ {c.providerName}
                  </span>
                  <span style={{ fontSize: '11px', color: '#8a9990' }}>{c.lastTime}</span>
                </div>
                <div style={{ fontSize: '12.5px', color: '#64736a', textOverflow: 'ellipsis', overflow: 'hidden', whiteSpace: 'nowrap' }}>
                  {c.lastMessage}
                </div>
                <div style={{ display: 'flex', gap: '8px', marginTop: '8px' }}>
                  <span style={{ fontSize: '11px', fontFamily: 'monospace', color: '#256b4a' }}>{c.bookingRef}</span>
                  {c.flaggedKeywords && (
                    <span className="admin-badge priority-high" style={{ fontSize: '10.5px' }}>
                      ⚠️ Off-Platform Alert
                    </span>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Right: Transcript Window */}
        <div className="admin-table-card" style={{ display: 'flex', flexDirection: 'column' }}>
          <div style={{ padding: '18px 24px', borderBottom: '1px solid #edf2ef', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <h3 style={{ margin: 0, fontSize: '16px', color: '#141f19' }}>
                Transcript: {selectedChat.customerName} &amp; {selectedChat.providerName}
              </h3>
              <p style={{ margin: '2px 0 0', fontSize: '12px', color: '#64736a' }}>
                Booking Ref: <strong>{selectedChat.bookingRef}</strong> | Session: <code>{selectedChat.id}</code>
              </p>
            </div>
            <span className={`admin-badge ${selectedChat.flaggedKeywords ? 'priority-high' : 'status-resolved'}`}>
              {selectedChat.status}
            </span>
          </div>

          <div style={{ padding: '24px', flex: 1, display: 'flex', flexDirection: 'column', gap: '16px', background: '#fafcfb' }}>
            <div style={{ alignSelf: 'flex-start', maxWidth: '75%', background: '#ffffff', border: '1px solid #e3ebe6', padding: '10px 14px', borderRadius: '12px 12px 12px 2px' }}>
              <div style={{ fontSize: '11px', fontWeight: 600, color: '#256b4a', marginBottom: '2px' }}>{selectedChat.customerName} (Customer)</div>
              <div style={{ fontSize: '13.5px', color: '#141f19' }}>Hello! Please let me know when you will be arriving.</div>
            </div>

            <div style={{ alignSelf: 'flex-end', maxWidth: '75%', background: '#d8ede0', border: '1px solid #b8dec8', padding: '10px 14px', borderRadius: '12px 12px 2px 12px' }}>
              <div style={{ fontSize: '11px', fontWeight: 600, color: '#113c2b', marginBottom: '2px' }}>{selectedChat.providerName} (Provider)</div>
              <div style={{ fontSize: '13.5px', color: '#141f19' }}>{selectedChat.lastMessage}</div>
            </div>

            {selectedChat.flaggedKeywords && (
              <div style={{ background: '#fee2e2', border: '1px solid #fecaca', borderRadius: '10px', padding: '12px 16px', fontSize: '13px', color: '#b91c1c' }}>
                <strong>Automated Policy Monitor:</strong> Message flagged for off-platform payment solicitation ("cash directly"). Warning logged to provider account.
              </div>
            )}
          </div>

          <div style={{ padding: '14px 24px', borderTop: '1px solid #edf2ef', display: 'flex', justifyContent: 'flex-end', gap: '10px' }}>
            <button
              type="button"
              className="admin-btn admin-btn-secondary"
              onClick={() => alert(`Warning strike sent to ${selectedChat.providerName}`)}
            >
              Issue Warning Strike
            </button>
            <button
              type="button"
              className="admin-btn admin-btn-primary"
              onClick={() => alert(`Exporting signed transcript ${selectedChat.id}`)}
            >
              Export Signed PDF
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
