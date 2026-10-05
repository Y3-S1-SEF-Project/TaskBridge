import React, { useState } from 'react';

export const SettingsView: React.FC = () => {
  const [commissionRate, setCommissionRate] = useState(12);
  const [minEscrowAmount, setMinEscrowAmount] = useState(1500);
  const [autoMatchRadiusKm, setAutoMatchRadiusKm] = useState(15);
  const [aiConfidenceThreshold, setAiConfidenceThreshold] = useState(85);
  const [maintenanceMode, setMaintenanceMode] = useState(false);
  const [saved, setSaved] = useState(false);

  const handleSave = (e: React.FormEvent) => {
    e.preventDefault();
    setSaved(true);
    setTimeout(() => setSaved(false), 2500);
  };

  return (
    <div className="admin-content">
      <div className="admin-page-header">
        <div>
          <h1 className="admin-page-title">System Settings</h1>
          <p className="admin-page-subtitle">
            Configure marketplace financial parameters, autonomous AI model thresholds, and operational limits.
          </p>
        </div>
        <button
          type="submit"
          form="settings-form"
          className="admin-btn admin-btn-primary"
        >
          {saved ? '✓ Changes Saved' : 'Save System Settings'}
        </button>
      </div>

      <form id="settings-form" onSubmit={handleSave} style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
        {/* Marketplace Commercials */}
        <div className="admin-table-card" style={{ padding: '24px' }}>
          <h3 style={{ margin: '0 0 6px 0', fontSize: '17px', color: '#141f19' }}>Marketplace Financial Rules</h3>
          <p style={{ margin: '0 0 20px 0', fontSize: '13px', color: '#64736a' }}>
            Commission rates and escrow clearing parameters applied to service requests and booking settlements.
          </p>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '20px' }}>
            <div className="admin-form-group">
              <label className="admin-form-label">Platform Take Rate Commission (%)</label>
              <input
                type="number"
                className="admin-form-input"
                value={commissionRate}
                onChange={(e) => setCommissionRate(Number(e.target.value))}
                min={1}
                max={30}
              />
              <span style={{ fontSize: '11.5px', color: '#8a9990' }}>Standard marketplace commission charged on provider payout.</span>
            </div>

            <div className="admin-form-group">
              <label className="admin-form-label">Minimum Escrow Floor (LKR)</label>
              <input
                type="number"
                className="admin-form-input"
                value={minEscrowAmount}
                onChange={(e) => setMinEscrowAmount(Number(e.target.value))}
                step={100}
              />
              <span style={{ fontSize: '11.5px', color: '#8a9990' }}>Lowest allowable upfront booking deposit.</span>
            </div>

            <div className="admin-form-group">
              <label className="admin-form-label">Default Matching Geo-Radius (km)</label>
              <input
                type="number"
                className="admin-form-input"
                value={autoMatchRadiusKm}
                onChange={(e) => setAutoMatchRadiusKm(Number(e.target.value))}
              />
              <span style={{ fontSize: '11.5px', color: '#8a9990' }}>Maximum distance for provider instant dispatch bids.</span>
            </div>
          </div>
        </div>

        {/* AI & Automation Thresholds */}
        <div className="admin-table-card" style={{ padding: '24px' }}>
          <h3 style={{ margin: '0 0 6px 0', fontSize: '17px', color: '#141f19' }}>AI Orchestration Parameters</h3>
          <p style={{ margin: '0 0 20px 0', fontSize: '13px', color: '#64736a' }}>
            Controls for multi-agent autonomous decision thresholds and supervisory human review routing.
          </p>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '20px' }}>
            <div className="admin-form-group">
              <label className="admin-form-label">Human Review Routing Threshold (%)</label>
              <input
                type="number"
                className="admin-form-input"
                value={aiConfidenceThreshold}
                onChange={(e) => setAiConfidenceThreshold(Number(e.target.value))}
                min={50}
                max={99}
              />
              <span style={{ fontSize: '11.5px', color: '#8a9990' }}>Matches or evidence reviews below this score route to human review.</span>
            </div>

            <div className="admin-form-group">
              <label className="admin-form-label">Primary LLM Provider Engine</label>
              <select className="admin-form-select" defaultValue="openai-gpt-4o-mini">
                <option value="openai-gpt-4o-mini">OpenAI (gpt-4o-mini & gpt-4o-mini Vision)</option>
                <option value="openai-fallback">OpenAI Rule-Based Fallback Cluster</option>
              </select>
              <span style={{ fontSize: '11.5px', color: '#8a9990' }}>Underlying foundation model for task parsing, semantic matching, and vision verification.</span>
            </div>
          </div>
        </div>

        {/* Platform Status */}
        <div className="admin-table-card" style={{ padding: '24px' }}>
          <h3 style={{ margin: '0 0 6px 0', fontSize: '17px', color: '#141f19' }}>System Operations &amp; Maintenance</h3>
          <p style={{ margin: '0 0 20px 0', fontSize: '13px', color: '#64736a' }}>
            Global marketplace availability and emergency service controls.
          </p>

          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '16px 20px', borderRadius: '12px', background: '#f5f8f6', border: '1px solid #e3ebe6' }}>
            <div>
              <div style={{ fontWeight: 600, fontSize: '14px', color: '#141f19' }}>Maintenance Mode</div>
              <div style={{ fontSize: '12.5px', color: '#64736a' }}>Temporarily pauses customer booking requests while permitting active job tracking.</div>
            </div>
            <button
              type="button"
              className={`admin-btn ${maintenanceMode ? 'admin-btn-primary' : 'admin-btn-secondary'}`}
              onClick={() => setMaintenanceMode(!maintenanceMode)}
            >
              {maintenanceMode ? 'Maintenance ACTIVE' : 'Operational (Normal)'}
            </button>
          </div>
        </div>
      </form>
    </div>
  );
};
