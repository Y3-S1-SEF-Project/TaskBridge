import { ThemeProvider } from '../theme/ThemeProvider'
import DesignSystemShowcase from './DesignSystemShowcase'

export default function ShowcaseEntry() {
  return <ThemeProvider><DesignSystemShowcase /></ThemeProvider>
}
