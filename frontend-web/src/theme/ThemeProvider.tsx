import { createContext, useContext, useEffect, useState } from 'react'
import type { ReactNode } from 'react'
import { themeVariables } from './theme'
import type { ThemeMode } from './theme'
import './theme.css'

const ThemeContext = createContext<{ mode: ThemeMode; setMode: (mode: ThemeMode) => void } | null>(null)
function initialMode(): ThemeMode {
  if (typeof window === 'undefined') return 'light'
  try {
    const saved = localStorage.getItem('taskbridge-theme')
    if (saved === 'light' || saved === 'dark') return saved
  } catch { /* Storage can be disabled; the toggle still works in memory. */ }
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
}
export function ThemeProvider({ children }: { children: ReactNode }) {
  const [mode, setMode] = useState<ThemeMode>(initialMode)
  useEffect(() => {
    try { localStorage.setItem('taskbridge-theme', mode) } catch { /* Optional persistence. */ }
  }, [mode])
  return <ThemeContext.Provider value={{ mode, setMode }}>
    <div className="tb-theme" data-theme={mode} style={themeVariables(mode)}>{children}</div>
  </ThemeContext.Provider>
}
export function useTaskBridgeTheme() {
  const context = useContext(ThemeContext)
  if (!context) throw new Error('TaskBridge components need ThemeProvider')
  return context
}
