import { lazy, StrictMode, Suspense } from 'react'
import { createRoot } from 'react-dom/client'

// Internal opt-in route; starter App and its styles remain unchanged.
const Showcase = lazy(() => import('./design-system/ShowcaseEntry'))
const App = lazy(async () => {
  await import('./index.css')
  return import('./App.tsx')
})
const isShowcase = import.meta.env.DEV && window.location.pathname.replace(/\/$/, '') === '/design-system'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <Suspense fallback={<p>Loading TaskBridge…</p>}>
      {isShowcase ? <Showcase /> : <App />}
    </Suspense>
  </StrictMode>,
)
