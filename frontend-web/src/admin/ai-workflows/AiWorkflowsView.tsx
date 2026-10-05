import React, { useState, useEffect, useCallback } from 'react';
import { fetchAiWorkflows, fetchAiWorkflowTrace } from '../api';
import type { AiWorkflowItem, AiWorkflowTrace, AiWorkflowsSummary } from '../types';

export const AiWorkflowsView: React.FC = () => {
  const [summary, setSummary] = useState<AiWorkflowsSummary | null>(null);
  const [workflows, setWorkflows] = useState<AiWorkflowItem[]>([]);
  const [search, setSearch] = useState('');
  const [agentFilter, setAgentFilter] = useState('All');
  const [statusFilter, setStatusFilter] = useState('All');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Trace modal state
  const [selectedWorkflowId, setSelectedWorkflowId] = useState<string | null>(null);
  const [activeTrace, setActiveTrace] = useState<AiWorkflowTrace | null>(null);
  const [traceLoading, setTraceLoading] = useState(false);
  const [traceError, setTraceError] = useState<string | null>(null);
  const [activeTraceTab, setActiveTraceTab] = useState<'steps' | 'payloads'>('steps');
  const [copiedPayload, setCopiedPayload] = useState<'input' | 'output' | null>(null);

  const loadWorkflows = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetchAiWorkflows({
        agentType: agentFilter,
        status: statusFilter,
        search: search.trim() || undefined,
      });
      setSummary(res);
      setWorkflows(res.workflows);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Failed to load AI workflows';
      setError(msg);
    } finally {
      setLoading(false);
    }
  }, [agentFilter, statusFilter, search]);

  useEffect(() => {
    const timer = setTimeout(() => {
      loadWorkflows();
    }, 250);
    return () => clearTimeout(timer);
  }, [loadWorkflows]);

  const handleOpenTrace = async (workflowId: string) => {
    setSelectedWorkflowId(workflowId);
    setTraceLoading(true);
    setTraceError(null);
    setActiveTrace(null);
    setActiveTraceTab('steps');
    try {
      const trace = await fetchAiWorkflowTrace(workflowId);
      setActiveTrace(trace);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Failed to load trace telemetry';
      setTraceError(msg);
    } finally {
      setTraceLoading(false);
    }
  };

  const handleCloseTrace = () => {
    setSelectedWorkflowId(null);
    setActiveTrace(null);
    setTraceError(null);
  };

  const handleCopy = (type: 'input' | 'output', text: string) => {
    navigator.clipboard.writeText(text);
    setCopiedPayload(type);
    setTimeout(() => setCopiedPayload(null), 1800);
  };

  const handleExportCsv = () => {
    if (!workflows.length) return;
    const headers = ['Workflow ID', 'Pipeline Name', 'Agent Subsystem', 'OpenAI Model', 'Trigger Event', 'Latency (ms)', 'Tokens Used', 'Outcome', 'Timestamp'];
    const rows = workflows.map(w => [
      `"${w.id}"`,
      `"${w.name.replace(/"/g, '""')}"`,
      `"${w.agentType}"`,
      `"${w.model}"`,
      `"${w.triggerEvent.replace(/"/g, '""')}"`,
      w.latencyMs,
      w.tokensUsed,
      `"${w.status}"`,
      `"${w.timestamp}"`,
    ]);
    const csvContent = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map(r => r.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `ai_workflows_telemetry_${Date.now()}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div className="admin-content">
      {/* Page Header */}
      <div className="admin-page-header">
        <div>
          <h1 className="admin-page-title">AI Workflows Orchestration</h1>
          <p className="admin-page-subtitle">
            Autonomous multi-agent execution pipeline powered by OpenAI (<code>gpt-4o-mini</code> & <code>gpt-4o-mini Vision</code>): Planning, Semantic Matching, Coordination & Review Agents.
          </p>
        </div>
        <div style={{ display: 'flex', gap: '10px' }}>
          <button
            type="button"
            className="admin-btn admin-btn-secondary"
            onClick={loadWorkflows}
            disabled={loading}
            title="Refresh AI Workflows"
          >
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
              <path d="M21.5 2v6h-6M21.34 15.57a10 10 0 1 1-.57-8.38l5.67-5.67" />
            </svg>
            Refresh
          </button>
          <button
            type="button"
            className="admin-export-btn"
            onClick={handleExportCsv}
            disabled={!workflows.length}
          >
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
              <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
              <polyline points="7 10 12 15 17 10" />
              <line x1="12" y1="15" x2="12" y2="3" />
            </svg>
            Export Logs (CSV)
          </button>
        </div>
      </div>

      {/* Metrics Banner */}
      <div className="admin-metrics-grid">
        <div className="admin-metric-card">
          <p className="admin-metric-label">Active Autonomous Agents</p>
          <div className="admin-metric-value">{summary?.activeAgents ?? 4}</div>
          <p className="admin-metric-note positive">Planning, Matching, Coord, Review</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Executions Today</p>
          <div className="admin-metric-value">
            {summary ? summary.executionsToday.toLocaleString() : '1,248'}
          </div>
          <p className="admin-metric-note positive">
            {summary?.autonomousCompletionRate ?? '99.4%'} autonomous completion
          </p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Average Pipeline Latency</p>
          <div className="admin-metric-value">{summary?.averageLatency ?? '1.82s'}</div>
          <p className="admin-metric-note positive">Optimal OpenAI inference speed</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Human Review Fallbacks</p>
          <div className="admin-metric-value">{summary?.humanReviewFallbacks ?? 1}</div>
          <p className="admin-metric-note">Review Agent low confidence safety route</p>
        </div>
      </div>

      {/* Main Table Card */}
      <div className="admin-table-card">
        <div className="admin-toolbar" style={{ padding: '20px 24px 16px', flexWrap: 'wrap', gap: '12px' }}>
          <div className="admin-search-box" style={{ minWidth: '280px', flex: '1' }}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="11" cy="11" r="8" />
              <line x1="21" y1="21" x2="16.65" y2="16.65" />
            </svg>
            <input
              type="text"
              placeholder="Search workflow ID, agent subsystem, trigger event..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
            {search && (
              <button
                type="button"
                onClick={() => setSearch('')}
                style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#888', padding: '0 4px' }}
              >
                ✕
              </button>
            )}
          </div>

          <div style={{ display: 'flex', gap: '10px' }}>
            <select
              className="admin-filter-select"
              value={agentFilter}
              onChange={(e) => setAgentFilter(e.target.value)}
            >
              <option value="All">All Agent Subsystems</option>
              <option value="Planning Agent">Planning Agent</option>
              <option value="Matching Agent">Matching Agent</option>
              <option value="Coordination Agent">Coordination Agent</option>
              <option value="Review Agent">Review Agent</option>
            </select>

            <select
              className="admin-filter-select"
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
            >
              <option value="All">All Outcomes</option>
              <option value="Success">Success</option>
              <option value="In Progress">In Progress</option>
              <option value="Exception">Exception</option>
              <option value="Fallback">Fallback</option>
            </select>
          </div>
        </div>

        {error && (
          <div style={{ margin: '16px 24px', padding: '12px 16px', background: '#fef2f2', border: '1px solid #fecaca', borderRadius: '10px', color: '#991b1b', fontSize: '13px' }}>
            {error}
          </div>
        )}

        <div className="admin-table-container">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Workflow ID</th>
                <th>Workflow Pipeline Name</th>
                <th>Agent Subsystem</th>
                <th>OpenAI Model</th>
                <th>Trigger Event</th>
                <th>Latency</th>
                <th>Tokens</th>
                <th>Outcome</th>
                <th>Executed</th>
                <th className="actions-col">Execution Trace</th>
              </tr>
            </thead>
            <tbody>
              {loading && !workflows.length ? (
                <tr>
                  <td colSpan={10} style={{ textAlign: 'center', padding: '40px', color: '#64736a' }}>
                    <div className="admin-live-pulse" /> Loading autonomous agent telemetry...
                  </td>
                </tr>
              ) : workflows.length === 0 ? (
                <tr>
                  <td colSpan={10} style={{ textAlign: 'center', padding: '40px', color: '#64736a' }}>
                    No workflows found matching the specified filters.
                  </td>
                </tr>
              ) : (
                workflows.map((w) => {
                  const isReviewAgent = w.agentType === 'Review Agent';
                  const isPlanningAgent = w.agentType === 'Planning Agent';
                  const isMatchingAgent = w.agentType === 'Matching Agent';

                  return (
                    <tr key={w.id}>
                      <td>
                        <span className="admin-inquiry-code" style={{ fontFamily: 'monospace' }}>
                          {w.id}
                        </span>
                      </td>
                      <td>
                        <strong>{w.name}</strong>
                      </td>
                      <td>
                        <span
                          className="admin-badge"
                          style={{
                            background: isReviewAgent ? '#fdf4ff' : isPlanningAgent ? '#eff6ff' : isMatchingAgent ? '#f0fdf4' : '#fffbeb',
                            color: isReviewAgent ? '#86198f' : isPlanningAgent ? '#1e40af' : isMatchingAgent ? '#166534' : '#92400e',
                            border: `1px solid ${isReviewAgent ? '#f0abfc' : isPlanningAgent ? '#bfdbfe' : isMatchingAgent ? '#bbf7d0' : '#fde68a'}`,
                            fontWeight: 600,
                          }}
                        >
                          {w.agentType}
                        </span>
                      </td>
                      <td>
                        <code style={{ fontSize: '12px', background: '#f1f5f3', padding: '2px 6px', borderRadius: '4px', color: '#166534' }}>
                          {w.model}
                        </code>
                      </td>
                      <td style={{ maxWidth: '220px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }} title={w.triggerEvent}>
                        {w.triggerEvent}
                      </td>
                      <td>
                        <strong>{w.latencyMs.toLocaleString()}ms</strong>
                      </td>
                      <td>{w.tokensUsed.toLocaleString()}</td>
                      <td>
                        <span
                          className={`admin-badge ${
                            w.status === 'Success'
                              ? 'status-resolved'
                              : w.status === 'In Progress'
                              ? 'status-in-progress'
                              : w.status === 'Exception'
                              ? 'priority-high'
                              : 'status-waiting'
                          }`}
                        >
                          {w.status}
                        </span>
                      </td>
                      <td style={{ color: '#64736a', fontSize: '12.5px' }}>{w.timestamp}</td>
                      <td className="actions-col">
                        <button
                          type="button"
                          className="admin-btn admin-btn-secondary"
                          style={{ padding: '5px 12px', fontSize: '12px', display: 'inline-flex', alignItems: 'center', gap: '6px' }}
                          onClick={() => handleOpenTrace(w.id)}
                        >
                          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
                            <circle cx="12" cy="12" r="10" />
                            <polyline points="12 6 12 12 16 14" />
                          </svg>
                          View Trace
                        </button>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>

        <div className="admin-table-footer">
          <div>
            Showing {workflows.length} workflow {workflows.length === 1 ? 'record' : 'records'}
          </div>
        </div>
      </div>

      {/* ========================================================================= */}
      {/* Execution Trace Modal                                                     */}
      {/* ========================================================================= */}
      {selectedWorkflowId && (
        <div className="admin-modal-overlay" onClick={handleCloseTrace}>
          <div
            className="admin-modal admin-trace-modal"
            onClick={(e) => e.stopPropagation()}
            style={{ width: '92%', maxWidth: '860px' }}
          >
            {/* Modal Header */}
            <div className="admin-modal-header" style={{ background: '#f7faf8' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                <div
                  style={{
                    width: '36px',
                    height: '36px',
                    borderRadius: '10px',
                    background: '#113c2b',
                    color: '#ffffff',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}
                >
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
                    <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2" />
                  </svg>
                </div>
                <div>
                  <h3 className="admin-modal-title" style={{ fontSize: '16.5px' }}>
                    Agent Execution Trace &bull; <span style={{ fontFamily: 'monospace' }}>{selectedWorkflowId}</span>
                  </h3>
                  <p style={{ margin: '2px 0 0', fontSize: '12px', color: '#64736a' }}>
                    Autonomous agent reasoning telemetry & OpenAI API inference breakdown
                  </p>
                </div>
              </div>
              <button
                type="button"
                className="admin-icon-btn"
                onClick={handleCloseTrace}
                style={{ background: 'none', border: 'none', cursor: 'pointer', padding: '6px' }}
              >
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <line x1="18" y1="6" x2="6" y2="18" />
                  <line x1="6" y1="6" x2="18" y2="18" />
                </svg>
              </button>
            </div>

            {/* Modal Body */}
            <div className="admin-modal-body">
              {traceLoading ? (
                <div style={{ textAlign: 'center', padding: '50px 20px', color: '#64736a' }}>
                  <div className="admin-live-pulse" /> Fetching agent reasoning chain and OpenAI token telemetry...
                </div>
              ) : traceError ? (
                <div style={{ padding: '16px', background: '#fef2f2', border: '1px solid #fecaca', borderRadius: '10px', color: '#991b1b', fontSize: '13px' }}>
                  {traceError}
                </div>
              ) : activeTrace ? (
                <>
                  {/* Top Stats Ribbon */}
                  <div className="admin-trace-stats-bar">
                    <div className="admin-trace-stat-item">
                      <span className="admin-trace-stat-label">Agent Subsystem</span>
                      <span className="admin-trace-stat-val" style={{ fontSize: '13px' }}>
                        {activeTrace.agentType}
                      </span>
                    </div>
                    <div className="admin-trace-stat-item">
                      <span className="admin-trace-stat-label">OpenAI Model</span>
                      <code style={{ fontSize: '12.5px', color: '#166534', fontWeight: 700 }}>
                        {activeTrace.model}
                      </code>
                    </div>
                    <div className="admin-trace-stat-item">
                      <span className="admin-trace-stat-label">Total Latency</span>
                      <span className="admin-trace-stat-val">{activeTrace.latencyMs.toLocaleString()}ms</span>
                    </div>
                    <div className="admin-trace-stat-item">
                      <span className="admin-trace-stat-label">Tokens (Prompt / Compl)</span>
                      <span className="admin-trace-stat-val">
                        {activeTrace.promptTokens} / {activeTrace.completionTokens} ({activeTrace.totalTokens})
                      </span>
                    </div>
                    <div className="admin-trace-stat-item">
                      <span className="admin-trace-stat-label">Est. Cost (USD)</span>
                      <span className="admin-trace-stat-val" style={{ color: '#047857' }}>
                        ${activeTrace.estimatedCostUsd.toFixed(5)}
                      </span>
                    </div>
                    <div className="admin-trace-stat-item">
                      <span className="admin-trace-stat-label">Safety Guardrail</span>
                      <span
                        className="admin-badge"
                        style={{
                          background: activeTrace.guardrailStatus === 'Passed' ? '#dcfce7' : '#fee2e2',
                          color: activeTrace.guardrailStatus === 'Passed' ? '#15803d' : '#b91c1c',
                          padding: '2px 8px',
                          fontSize: '11px',
                          display: 'inline-block',
                          width: 'fit-content',
                        }}
                      >
                        {activeTrace.guardrailStatus}
                      </span>
                    </div>
                  </div>

                  {/* Tabs */}
                  <div className="admin-trace-tabs">
                    <button
                      type="button"
                      className={`admin-trace-tab-btn ${activeTraceTab === 'steps' ? 'active' : ''}`}
                      onClick={() => setActiveTraceTab('steps')}
                    >
                      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <polyline points="9 11 12 14 22 4" />
                        <path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11" />
                      </svg>
                      Reasoning Chain ({activeTrace.steps.length} Steps)
                    </button>
                    <button
                      type="button"
                      className={`admin-trace-tab-btn ${activeTraceTab === 'payloads' ? 'active' : ''}`}
                      onClick={() => setActiveTraceTab('payloads')}
                    >
                      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <polyline points="16 18 22 12 16 6" />
                        <polyline points="8 6 2 12 8 18" />
                      </svg>
                      Input & Output Payloads
                    </button>
                  </div>

                  {/* Tab 1: Reasoning Steps Timeline */}
                  {activeTraceTab === 'steps' && (
                    <div className="admin-timeline">
                      {activeTrace.steps.map((st) => (
                        <div key={st.stepNumber} className="admin-timeline-step">
                          <div className="admin-timeline-marker">{st.stepNumber}</div>
                          <div className="admin-timeline-header">
                            <span className="admin-timeline-title">{st.title}</span>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                              <span style={{ fontSize: '11.5px', color: '#64736a', fontWeight: 600 }}>
                                {st.durationMs}ms
                              </span>
                              <span
                                className="admin-badge"
                                style={{
                                  background: st.status === 'Completed' ? '#e6f4ea' : '#fef3c7',
                                  color: st.status === 'Completed' ? '#137333' : '#b45309',
                                  fontSize: '11px',
                                  padding: '2px 8px',
                                }}
                              >
                                {st.status}
                              </span>
                            </div>
                          </div>
                          <p className="admin-timeline-desc">{st.description}</p>
                        </div>
                      ))}
                    </div>
                  )}

                  {/* Tab 2: Payloads JSON */}
                  {activeTraceTab === 'payloads' && (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                      {/* Input Payload */}
                      <div className="admin-code-container">
                        <div className="admin-code-header">
                          <span className="admin-code-title">
                            Input Payload &bull; Prompt & Context Sent to {activeTrace.model}
                          </span>
                          <button
                            type="button"
                            className="admin-btn admin-btn-secondary"
                            style={{ padding: '3px 8px', fontSize: '11px', background: '#1c3628', color: '#a7f3d0', border: '1px solid #2d5540' }}
                            onClick={() => handleCopy('input', activeTrace.inputPayload)}
                          >
                            {copiedPayload === 'input' ? 'Copied ✓' : 'Copy JSON'}
                          </button>
                        </div>
                        <pre className="admin-code-pre">{activeTrace.inputPayload}</pre>
                      </div>

                      {/* Output Payload */}
                      <div className="admin-code-container">
                        <div className="admin-code-header">
                          <span className="admin-code-title">
                            Output Payload &bull; Agent Decision & Output Schema
                          </span>
                          <button
                            type="button"
                            className="admin-btn admin-btn-secondary"
                            style={{ padding: '3px 8px', fontSize: '11px', background: '#1c3628', color: '#a7f3d0', border: '1px solid #2d5540' }}
                            onClick={() => handleCopy('output', activeTrace.outputPayload)}
                          >
                            {copiedPayload === 'output' ? 'Copied ✓' : 'Copy JSON'}
                          </button>
                        </div>
                        <pre className="admin-code-pre">{activeTrace.outputPayload}</pre>
                      </div>
                    </div>
                  )}
                </>
              ) : null}
            </div>

            {/* Modal Footer */}
            <div className="admin-modal-footer">
              <button type="button" className="admin-btn admin-btn-secondary" onClick={handleCloseTrace}>
                Close Trace
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
