import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.jsx'
import {applyTheme} from './lib/theme'
import {backendMode} from './supabase'

applyTheme()

createRoot(document.getElementById('root')).render(
  <StrictMode>
    {backendMode==='staging'&&<div className="staging-banner" role="status">ISOLATED STAGING · TEST ACCOUNTS ONLY · NOT PRODUCTION</div>}
    <App />
  </StrictMode>,
)
