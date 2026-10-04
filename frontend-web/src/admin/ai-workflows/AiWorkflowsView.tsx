import React, { useState } from 'react';

interface WorkflowRecord {
  id: string;
  name: string;
  agentType: 'Planning Agent' | 'Matching Agent' | 'Coordination Agent' | 'Review Agent';
  triggerEvent: string;
  durationMs: number;
  tokensUsed: number;
  status: 'Success' | 'In Progress' | 'Exception' | 'Fallback';
  timestamp: string;
}

const mockWorkflows: WorkflowRecord[] = [
  { id: 'WF-9401', name: 'Emergency Plumbing Intent Match', agentType: 'Matching Agent', triggerEvent: 'New Request SR-8092', durationMs: 1420, tokensUsed: 1240, status: 'Success', timestamp: '5 mins ago' },
  { id: 'WF-9400', name: 'Scope of Work & Cost Estimator', agentType: 'Planning Agent', triggerEvent: 'Customer prompt parse', durationMs: 2180, tokensUsed: 1890, status: 'Success', timestamp: '12 mins ago' },
  { id: 'WF-9399', name: 'Provider Arrival Verification & ETA', agentType: 'Coordination Agent', triggerEvent: 'GPS telemetry ping', durationMs: 840, tokensUsed: 620, status: 'Success', timestamp: '20 mins ago' },
  { id: 'WF-9398', name: 'Before & After Photographic Evidence Review', agentType: 'Review Agent', triggerEvent: 'Job Completion BK-499', durationMs: 3410, tokensUsed: 2850, status: 'Exception', timestamp: '45 mins ago' },
];

export const AiWorkflowsView: React.FC = () => {
  const [search, setSearch] = useState('');
  const [agentFilter, setAgentFilter] = useState('All');

  const filtered = mockWorkflows.filter(w => {
    const matchSearch = w.id.toLowerCase().includes(search.toLowerCase()) ||
      w.name.toLowerCase().includes(search.toLowerCase()) ||
      w.triggerEvent.toLowerCase().includes(search.toLowerCase());
    const matchAgent = agentFilter === 'All' || w.agentType === agentFilter;
    return matchSearch && matchAgent;
  });

  return (
    <div className="admin-content">
      <div className="admin-page-header">
        <div>
          <h1 className="admin-page-title">AI Workflows Orchestration</h1>
          <p className="admin-page-subtitle">
            Autonomous multi-agent execution pipeline: Planning, Semantic Matching, Coordination & Review Agents.
          </p>
        </div>
        <button
          type="button"
          className="admin-export-btn"
          onClick={() => alert('Exporting AI Workflow telemetry...')}
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
            <polyline points="7 10 12 15 17 10" />
            <line x1="12" y1="15" x2="12" y2="3" />
          </svg>
          Export Logs
        </button>
      </div>

      <div className="admin-metrics-grid">
        <div className="admin-metric-card">
          <p className="admin-metric-label">Active Autonomous Agents</p>
          <div className="admin-metric-value">4</div>
          <p className="admin-metric-note positive">Planning, Matching, Coord, Review</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Executions Today</p>
          <div className="admin-metric-value">1,248</div>
          <p className="admin-metric-note positive">99.4% autonomous completion</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Average Pipeline Latency</p>
          <div className="admin-metric-value">1.82s</div>
          <p className="admin-metric-note positive">Optimal response time</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Human Review Fallbacks</p>
          <div className="admin-metric-value">1</div>
          <p className="admin-metric-note">Sent to human review queue</p>
        </div>
      </div>

      <div className="admin-table-card">
        <div className="admin-toolbar" style={{ padding: '20px 24px 16px' }}>
          <div className="admin-search-box">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="11" cy="11" r="8" />
              <line x1="21" y1="21" x2="16.65" y2="16.65" />
            </svg>
            <input
              type="text"
              placeholder="Search workflow ID, agent name, trigger..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>

          <select
            className="admin-filter-select"
            value={agentFilter}
            onChange={(e) => setAgentFilter(e.target.value)}
          >
            <option value="All">All Agent Types</option>
            <option value="Planning Agent">Planning Agent</option>
            <option value="Matching Agent">Matching Agent</option>
            <option value="Coordination Agent">Coordination Agent</option>
            <option value="Review Agent">Review Agent</option>
          </select>
        </div>

        <div className="admin-table-container">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Workflow ID</th>
                <th>Workflow Pipeline Name</th>
                <th>Agent Subsystem</th>
                <th>Trigger Event</th>
                <th>Latency</th>
                <th>Tokens</th>
                <th>Outcome</th>
                <th>Executed</th>
                <th className="actions-col">Trace</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map(w => (
                <tr key={w.id}>
                  <td><span className="admin-inquiry-code">{w.id}</span></td>
                  <td><strong>{w.name}</strong></td>
                  <td>
                    <span className="admin-badge priority-normal">{w.agentType}</span>
                  </td>
                  <td>{w.triggerEvent}</td>
                  <td><strong>{w.durationMs}ms</strong></td>
                  <td>{w.tokensUsed.toLocaleString()}</td>
                  <td>
                    <span className={`admin-badge ${
                      w.status === 'Success' ? 'status-resolved' :
                      w.status === 'In Progress' ? 'status-in-progress' :
                      w.status === 'Exception' ? 'priority-high' : 'status-waiting'
                    }`}>
                      {w.status}
                    </span>
                  </td>
                  <td>{w.timestamp}</td>
                  <td className="actions-col">
                    <button
                      type="button"
                      className="admin-btn admin-btn-secondary"
                      style={{ padding: '4px 10px', fontSize: '12px' }}
                      onClick={() => alert(`Inspecting trace logs for ${w.id}`)}
                    >
                      View Trace
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="admin-table-footer">
          <div>Showing {filtered.length} of {mockWorkflows.length} workflow traces</div>
        </div>
      </div>
    </div>
  );
};
