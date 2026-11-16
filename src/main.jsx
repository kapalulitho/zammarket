import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.jsx'
import {applyTheme} from './lib/theme'
import {backendMode} from './supabase'

applyTheme()

// PWA: register the service worker over HTTPS (the live site) and on
// localhost for testing. A failure must never block the app itself.
if ('serviceWorker' in navigator && (location.protocol === 'https:' || ['localhost', '127.0.0.1'].includes(location.hostname))) {
  window.addEventListener('load', () => navigator.serviceWorker.register('/sw.js').catch(() => {}));
}

createRoot(document.getElementById('root')).render(
  <StrictMode>
    {backendMode==='staging'&&<div className="staging-banner" role="status">ISOLATED STAGING · TEST ACCOUNTS ONLY · NOT PRODUCTION</div>}
    <App />
  </StrictMode>,
)
