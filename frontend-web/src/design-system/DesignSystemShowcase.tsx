import { useState } from 'react'
import type { ReactNode } from 'react'
import { useTaskBridgeTheme } from '../theme/ThemeProvider'
import { palettes } from '../theme/theme'
import { colors, radius, spacing, typography } from '../theme/tokens'
import { AppIcon, iconNames } from '../theme/icons'
import { Avatar, Badge, BookingCard, Button, Card, ChatBubble, Dialog, Input,
  Navigation, ProviderCard, Rating, ServiceCard, StatePanel, statuses, Tabs } from '../theme/components'
import './showcase.css'

function Section({ id, title, children }: { id: string; title: string; children: ReactNode }) {
  return <section id={id} className="tb-showcase-section" aria-labelledby={id + '-title'}>
    <h2 id={id + '-title'}>{title}</h2>{children}</section>
}
export default function DesignSystemShowcase() {
  const { mode, setMode } = useTaskBridgeTheme()
  const [selectedTab, setSelectedTab] = useState(0)
  const [destination, setDestination] = useState(0)
  const [provider, setProvider] = useState(false)
  const [dialog, setDialog] = useState(false)
  const [query, setQuery] = useState('')
  const [notice, setNotice] = useState('')
  const tabs = ['Upcoming', 'Active', 'Completed']
  const action = () => setNotice('Component interaction preview. No service action was performed.')
  const palette = palettes[mode]
  return <div className="tb-showcase">
    <header className="tb-showcase-header">
      <div className="tb-row"><AppIcon name="briefcase" /><strong>TASKBRIDGE</strong><span className="tb-muted">/ Design system</span></div>
      <Button variant="secondary" aria-pressed={mode === 'dark'} onClick={() => setMode(mode === 'dark' ? 'light' : 'dark')}>
        {mode === 'dark' ? 'Switch to light' : 'Switch to dark'}
      </Button>
    </header>
    <main className="tb-showcase-main">
      <div className="tb-showcase-intro"><small className="tb-primary">FOUNDATIONS / COMPONENTS / STATES</small>
        <h1>A shared language for good help.</h1><p className="tb-muted">TaskBridge’s Figma design system, implemented for Flutter and React.</p>
        <nav aria-label="Showcase sections" className="tb-row tb-wrap">
          {['Colors', 'Typography', 'Controls', 'Cards', 'Navigation', 'Feedback', 'Icons', 'Geometry'].map((label) =>
            <a key={label} href={'#' + label.toLowerCase()}>{label}</a>)}
        </nav>
      </div>
      <p role="status" aria-live="polite" className="tb-notice">{notice || 'Internal component showcase · sample content only'}</p>
      <Section id="colors" title="Colors">
        <div className="tb-color-grid">{Object.entries(colors).map(([name, value]) =>
          <Card key={name}><div className="tb-swatch" style={{ background: value }} /><strong>{name}</strong><p className="tb-muted">{value}</p></Card>)}</div>
        <h3>Semantic palette · {mode}</h3><div className="tb-color-grid">{Object.entries(palette).map(([name, value]) =>
          <Card key={name}><div className="tb-swatch" style={{ background: value }} /><strong>{name}</strong><p className="tb-muted">{value.toUpperCase()}</p></Card>)}</div>
      </Section>
      <Section id="typography" title="Typography · Inter">
        <Card className="tb-stack">{Object.entries(typography).map(([name, style]) =>
          <p key={name} style={{ fontSize: style.fontSize, lineHeight: style.lineHeight + 'px', fontWeight: style.fontWeight }}>
            {name} · {style.fontSize}/{style.lineHeight} · {style.fontWeight}</p>)}</Card>
      </Section>
      <Section id="controls" title="Buttons & inputs">
        <div className="tb-row tb-wrap"><Button onClick={action}>Continue</Button>
          <Button variant="secondary" onClick={action}>View Profile</Button>
          <Button variant="ghost" onClick={action}>Do Later</Button>
          <Button disabled>Disabled</Button><Button loading>Loading</Button>
          <Button icon="add" onClick={action}>Add photo</Button></div>
        <div className="tb-demo-grid">
          <Input label="Full name" placeholder="Enter your full name" helper="Your public profile name" />
          <Input label="Mobile number" placeholder="+94 77 123 4567" error="Enter a valid mobile number" />
          <Input label="Password" type="password" placeholder="Enter a password" />
          <Input label="Disabled field" placeholder="Not editable" disabled />
          <Input label="Search services or providers" type="search" icon="search-normal"
            placeholder="Try plumbing" value={query} onChange={(e) => setQuery(e.target.value)} />
        </div><small className="tb-muted">{query ? 'Preview query: ' + query : 'Focus an input to inspect its state.'}</small>
      </Section>
      <Section id="cards" title="Cards & marketplace components">
        <ServiceCard title="Plumbing" icon="drop" onSelect={action} />
        <div className="tb-demo-grid">
          <ProviderCard name="Kamal Perera" service="Plumbing specialist" availability="Available tomorrow · Colombo 05" onView={action} />
          <ProviderCard name="Kamal Perera" service="Plumbing specialist" availability="Available tomorrow · Colombo 05" recommended onView={action} />
          <BookingCard title="Kitchen tap repair" provider="Kamal Perera" reference="#TB-1042" schedule="17 Sep · 4 PM · Colombo 05" price="Rs. 4,500" status="In progress" />
          <Card className="tb-stack"><h3>Trust, at a glance</h3><div className="tb-row"><Avatar initials="KP" name="Kamal Perera" /><Rating value={4.9} reviews={128} /></div>
            <div className="tb-row tb-wrap">{statuses.map((status) => <Badge key={status} status={status} />)}</div></Card>
        </div>
      </Section>
      <Section id="navigation" title="Tabs & navigation">
        <div className="tb-demo-grid"><Card>
          <Tabs tabs={tabs} selected={selectedTab} onChange={setSelectedTab} id="sample" />
          {tabs.map((label, i) => <div key={label} id={`sample-panel-${i}`} role="tabpanel"
            aria-labelledby={`sample-tab-${i}`} hidden={selectedTab !== i} tabIndex={0} className="tb-tab-panel">{label} tab sample</div>)}
        </Card><div className="tb-stack">
          <Button variant="ghost" aria-pressed={provider} onClick={() => setProvider(!provider)}>{provider ? 'Customer navigation' : 'Provider navigation'}</Button>
          <Navigation selected={destination} onChange={setDestination} provider={provider} />
          <small className="tb-muted">Selected destination: {destination + 1}</small>
        </div></div>
      </Section>
      <Section id="feedback" title="Chat & feedback states">
        <div className="tb-demo-grid"><div className="tb-stack">
          <ChatBubble timestamp="10:42 AM">Hello! I can visit tomorrow at 4 PM.</ChatBubble>
          <ChatBubble timestamp="10:43 AM · Read" outgoing>That works for me. Thank you.</ChatBubble>
        </div><StatePanel title="Loading" icon="clock" loading>Getting your information ready.</StatePanel>
          <StatePanel title="Nothing here yet" icon="search-normal">Try another search or adjust your filters.</StatePanel>
          <StatePanel title="Unable to load" icon="warning-2" action={action}>Check your connection and try again.</StatePanel>
        </div><Button variant="secondary" onClick={() => setDialog(true)}>Inspect dialog</Button>
        <Dialog open={dialog} onClose={() => setDialog(false)} title="TaskBridge dialog">
          <p>16 px radius, a clear border and no heavy shadow.</p></Dialog>
      </Section>
      <Section id="icons" title="Iconsax · original Linear SVGs">
        <div className="tb-icon-grid">{iconNames.map((name) => <Card key={name} className="tb-icon-sample">
          <AppIcon name={name} /><small>{name}</small></Card>)}</div>
      </Section>
      <Section id="geometry" title="Spacing & radius">
        <div className="tb-demo-grid"><Card className="tb-stack">{Object.values(spacing).map((value) =>
          <div key={value} className="tb-row"><small className="tb-measure-label">{value} px</small><span className="tb-spacing-bar" style={{ width: value }} /></div>)}</Card>
          <Card className="tb-row tb-wrap">{Object.values(radius).map((value) =>
            <div key={value} className="tb-radius-sample" style={{ borderRadius: value }}>{value}</div>)}</Card></div>
      </Section>
      <footer className="tb-muted"><small>Source: TASKBRIDGE Figma · Light values are preserved. Dark semantics and responsive breakpoints are documented implementation derivations.</small></footer>
    </main>
  </div>
}
