/**
 * Extracted from https://www.figma.com/design/vyFvCE5DxjCFs1TAS3qVf8
 * Foundations page 0:1, 2026-09-17. No Figma effect styles were present.
 * Dark semantics in theme.ts use existing primitive colors and sRGB blends:
 * surface +4% white; border/disabled +20%; status +45% (warning +25%).
 * Responsive thresholds/content maximum are implementation assumptions.
 * Inter is loaded remotely in theme.css; fonts are not bundled for offline use.
 * Internal showcase: /design-system in development. Starter route is preserved.
 */
export const colors = {
  "primary": "#256B4A",
  "primaryDark": "#174832",
  "primaryLight": "#E8F5EE",
  "mint": "#B8E5CA",
  "background": "#F7F9F8",
  "surface": "#FFFFFF",
  "textPrimary": "#17211B",
  "textSecondary": "#66736B",
  "border": "#E2E8E4",
  "success": "#2E8B57",
  "warning": "#E6A23C",
  "error": "#D94B4B",
  "info": "#3B82B8"
} as const

export const spacing = {"4": 4, "8": 8, "12": 12, "16": 16, "20": 20, "24": 24, "32": 32, "40": 40, "48": 48, "64": 64} as const
export const radius = {"8": 8, "12": 12, "16": 16, "20": 20, "24": 24, "999": 999} as const
export const typography = {
  "display": {
    "fontSize": 32,
    "lineHeight": 40,
    "fontWeight": 700
  },
  "h1": {
    "fontSize": 28,
    "lineHeight": 36,
    "fontWeight": 700
  },
  "h2": {
    "fontSize": 22,
    "lineHeight": 30,
    "fontWeight": 600
  },
  "h3": {
    "fontSize": 18,
    "lineHeight": 26,
    "fontWeight": 600
  },
  "body": {
    "fontSize": 16,
    "lineHeight": 24,
    "fontWeight": 400
  },
  "bodySmall": {
    "fontSize": 15,
    "lineHeight": 22,
    "fontWeight": 400
  },
  "caption": {
    "fontSize": 12,
    "lineHeight": 18,
    "fontWeight": 400
  },
  "label": {
    "fontSize": 13,
    "lineHeight": 20,
    "fontWeight": 600
  },
  "button": {
    "fontSize": 15,
    "lineHeight": 22,
    "fontWeight": 600
  }
} as const
export const shadows = { none: 'none', card: 'none', dialog: 'none' } as const
// Responsive thresholds are implementation assumptions, not Figma variables.
export const breakpoints = { compact: 768, desktop: 1200 } as const
export const metrics = { buttonHeight: 52, inputHeight: 55, avatar: 56, icon: 24, border: 1, focus: 2, content: 1128 } as const
