import { useEffect, useId, useRef, useState } from 'react'
import type { ButtonHTMLAttributes, HTMLAttributes, InputHTMLAttributes, ReactNode } from 'react'
import { AppIcon } from './icons'
import type { AppIconName } from './icons'

export function Button({ variant = 'primary', loading = false, icon, children,
  disabled, className = '', type = 'button', ...props }: ButtonHTMLAttributes<HTMLButtonElement> & {
    variant?: 'primary' | 'secondary' | 'ghost'; loading?: boolean; icon?: AppIconName
  }) {
  return <button {...props} type={type} disabled={disabled || loading} aria-busy={loading}
    className={`tb-button tb-button--${variant} ${className}`}>
    {loading ? <span className="tb-spinner" aria-hidden="true" /> : icon && <AppIcon name={icon} size={20} />}
    {loading ? 'Please wait…' : children}
  </button>
}
export function Input({ label, helper, error, icon, id, className = '', ...props }:
  InputHTMLAttributes<HTMLInputElement> & { label: string; helper?: string; error?: string; icon?: AppIconName }) {
  const generated = useId()
  const inputId = id ?? generated
  const description = error || helper
  return <div className={`tb-field ${className}`}>
    <label htmlFor={inputId}>{label}</label>
    <div className="tb-input-wrap">
      {icon && <AppIcon name={icon} size={20} />}
      <input {...props} id={inputId} aria-invalid={!!error}
        aria-describedby={[props['aria-describedby'], description ? inputId + '-description' : null].filter(Boolean).join(' ') || undefined}
        className={icon ? 'tb-input tb-input--icon' : 'tb-input'} />
    </div>
    {description && <small id={inputId + '-description'} className={error ? 'tb-error-text' : 'tb-muted'}>{description}</small>}
  </div>
}
export function Card({ children, className = '', ...props }: HTMLAttributes<HTMLDivElement>) {
  return <div {...props} className={`tb-card ${className}`}>{children}</div>
}
export const statuses = ['Available', 'Verified', 'Pending', 'In progress', 'Completed', 'Action required', 'Open', 'Cancelled'] as const
export type Status = typeof statuses[number]
export function Badge({ status }: { status: Status }) {
  const tone = status === 'Action required' ? 'error' : status === 'Completed' ? 'success' :
    status === 'In progress' || status === 'Open' ? 'info' : status === 'Pending' || status === 'Cancelled' ? 'muted' : 'primary'
  return <span className={`tb-badge tb-tone-${tone}`}>
    <AppIcon name={status === 'Action required' ? 'warning-2' : status === 'Verified' ? 'verify' : 'tick-circle'} size={16} />{status}
  </span>
}
export function Avatar({ initials, name, src }: { initials: string; name: string; src?: string }) {
  const [failed, setFailed] = useState(false)
  useEffect(() => { setFailed(false) }, [src])
  return <span className="tb-avatar" role="img" aria-label={name}>
    {src && !failed ? <img src={src} alt="" onError={() => setFailed(true)} /> : initials}
  </span>
}
export function Rating({ value, reviews = 0 }: { value: number; reviews?: number }) {
  const score = Math.max(0, Math.min(5, value))
  return <span className="tb-rating" aria-label={`${score.toFixed(1)} out of 5, ${reviews} reviews`}>
    <span className="tb-row" aria-hidden="true">{Array.from({ length: 5 }, (_, i) =>
      <AppIcon key={i} name="star" size={20} className={i < Math.round(score) ? '' : 'tb-rating-empty'} />)}</span>
    <small aria-hidden="true">{score.toFixed(1)} ({reviews})</small>
  </span>
}
export function ProviderCard({ name, service, availability, initials = 'KP', recommended = false, onView }:
  { name: string; service: string; availability: string; initials?: string; recommended?: boolean; onView?: () => void }) {
  return <Card className="tb-stack">
    {recommended && <div className="tb-recommendation"><AppIcon name="magicpen" size={20} />Recommended by TaskBridge AI</div>}
    <div className="tb-identity"><Avatar initials={initials} name={name} /><div className="tb-stack tb-grow">
      <h3>{name}</h3><small className="tb-primary">Verified · {service}</small><Rating value={4.9} reviews={128} />
    </div></div>
    <p className="tb-muted">{availability}</p>
    <Button variant="secondary" onClick={onView}>View Profile</Button>
  </Card>
}
export function ServiceCard({ title, icon, onSelect }: { title: string; icon: AppIconName; onSelect?: () => void }) {
  return <Card><Button variant="ghost" icon={icon} onClick={onSelect}>{title}</Button></Card>
}
export function BookingCard({ title, provider, reference, schedule, price, status = 'Pending' }:
  { title: string; provider: string; reference: string; schedule: string; price: string; status?: Status }) {
  return <Card className="tb-stack"><h3>{title}</h3><small className="tb-muted">{provider} · {reference}</small>
    <p>{schedule}</p><div className="tb-row tb-wrap"><Badge status={status} /><strong>{price}</strong></div></Card>
}
export function ChatBubble({ children, timestamp, outgoing = false }: { children: ReactNode; timestamp: string; outgoing?: boolean }) {
  return <div className={`tb-chat ${outgoing ? 'tb-chat--outgoing' : ''}`}><p>{children}</p><small className="tb-muted">{timestamp}</small></div>
}
export function Tabs({ tabs, selected, onChange, id }: { tabs: string[]; selected: number; onChange: (index: number) => void; id: string }) {
  return <div role="tablist" aria-label="Showcase tabs" className="tb-tabs">{tabs.map((label, i) =>
    <button key={label} type="button" role="tab" id={`${id}-tab-${i}`} aria-controls={`${id}-panel-${i}`}
      aria-selected={selected === i} tabIndex={selected === i ? 0 : -1}
      onClick={() => onChange(i)} onKeyDown={(event) => {
        let next = i
        if (event.key === 'ArrowRight') next = (i + 1) % tabs.length
        else if (event.key === 'ArrowLeft') next = (i - 1 + tabs.length) % tabs.length
        else if (event.key === 'Home') next = 0
        else if (event.key === 'End') next = tabs.length - 1
        else return
        event.preventDefault(); onChange(next)
        document.getElementById(`${id}-tab-${next}`)?.focus()
      }}>{label}</button>)}</div>
}
export function Navigation({ selected, onChange, provider = false }: { selected: number; onChange: (index: number) => void; provider?: boolean }) {
  const labels = provider ? ['Dashboard', 'Jobs', 'Chat', 'Profile'] : ['Home', 'Bookings', 'Chat', 'Profile']
  const icons: AppIconName[] = provider ? ['chart', 'briefcase', 'message', 'profile'] : ['home', 'calendar', 'message', 'profile']
  return <nav className="tb-navigation" aria-label={provider ? 'Provider' : 'Customer'}>{labels.map((label, i) =>
    <button key={label} type="button" aria-current={selected === i ? 'page' : undefined} onClick={() => onChange(i)}>
      <AppIcon name={icons[i]} /><small>{label}</small></button>)}</nav>
}
export function StatePanel({ title, children, icon, loading, action }: { title: string; children: ReactNode; icon: AppIconName; loading?: boolean; action?: () => void }) {
  return <Card className="tb-stack" role={loading ? 'status' : undefined}>
    {loading ? <span className="tb-spinner" aria-hidden="true" /> : <AppIcon name={icon} size={40} />}
    <h3>{title}</h3><p className="tb-muted">{children}</p>
    {action && <Button variant="secondary" onClick={action}>Try again</Button>}
  </Card>
}
export function Dialog({ open, onClose, title, children }: { open: boolean; onClose: () => void; title: string; children: ReactNode }) {
  const ref = useRef<HTMLDialogElement>(null)
  const titleId = useId()
  useEffect(() => {
    const dialog = ref.current
    if (open && !dialog?.open) dialog?.showModal()
    if (!open && dialog?.open) dialog.close()
  }, [open])
  return <dialog ref={ref} className="tb-dialog" aria-labelledby={titleId}
    onCancel={onClose} onClose={onClose}><div className="tb-stack"><h2 id={titleId}>{title}</h2>
    {children}<Button onClick={onClose}>Close</Button></div></dialog>
}
