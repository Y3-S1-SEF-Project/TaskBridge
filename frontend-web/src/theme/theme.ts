import { colors, metrics, radius, spacing, typography } from './tokens'
import type { CSSProperties } from 'react'
export type ThemeMode = 'light' | 'dark'

/** Same sRGB interpolation as Flutter AppPalette. Dark mode is derived. */
export function mix(a: string, b: string, amount: number): string {
  const channel = (hex: string, start: number) => parseInt(hex.slice(start, start + 2), 16)
  return '#' + [1, 3, 5].map((i) =>
    Math.round(channel(a, i) + (channel(b, i) - channel(a, i)) * amount).toString(16).padStart(2, '0')).join('')
}
export const palettes = {
  light: {
    background: colors.background, surface: colors.surface, text: colors.textPrimary,
    muted: colors.textSecondary, border: colors.border, primary: colors.primary,
    pressed: colors.primaryDark, onPrimary: colors.surface, soft: colors.primaryLight,
    onSoft: colors.primary, success: colors.success, warning: colors.warning,
    error: colors.error, info: colors.info, disabled: colors.border,
  },
  dark: {
    background: colors.textPrimary, surface: mix(colors.textPrimary, colors.surface, .04),
    text: colors.background, muted: colors.mint, border: mix(colors.textPrimary, colors.surface, .20),
    primary: colors.mint, pressed: colors.primaryLight, onPrimary: colors.primaryDark,
    soft: colors.primaryDark, onSoft: colors.primaryLight,
    success: mix(colors.success, colors.surface, .45),
    warning: mix(colors.warning, colors.surface, .25),
    error: mix(colors.error, colors.surface, .45),
    info: mix(colors.info, colors.surface, .45),
    disabled: mix(colors.textPrimary, colors.surface, .20),
  },
} as const

const kebab = (s: string) => s.replace(/[A-Z]/g, (x) => '-' + x.toLowerCase())
export function themeVariables(mode: ThemeMode): CSSProperties {
  const properties: Record<string, string | number> = {}
  for (const [key, value] of Object.entries(palettes[mode])) properties['--tb-' + kebab(key)] = value
  for (const [key, value] of Object.entries(colors)) properties['--tb-brand-' + kebab(key)] = value
  for (const [key, value] of Object.entries(spacing)) properties['--tb-space-' + key] = value + 'px'
  for (const [key, value] of Object.entries(radius)) properties['--tb-radius-' + key] = value + 'px'
  for (const [key, value] of Object.entries(metrics)) properties['--tb-' + kebab(key)] = value + 'px'
  for (const [key, value] of Object.entries(typography)) {
    properties['--tb-type-' + kebab(key) + '-size'] = value.fontSize + 'px'
    properties['--tb-type-' + kebab(key) + '-line'] = value.lineHeight + 'px'
    properties['--tb-type-' + kebab(key) + '-weight'] = value.fontWeight
  }
  // Caption-safe inks retain the original semantic status colors above.
  for (const key of ['success', 'warning', 'error', 'info'] as const) {
    properties['--tb-' + key + '-ink'] = mix(palettes[mode][key], palettes[mode].text, .35)
  }
  return properties as CSSProperties
}
