import './style.css'
import {
  Chart, LineController, LineElement, PointElement,
  LinearScale, CategoryScale, Legend, Tooltip, Filler
} from 'chart.js'

Chart.register(LineController, LineElement, PointElement, LinearScale, CategoryScale, Legend, Tooltip, Filler)

// --- Wails bindings (injected by the runtime inside the webview) -------------
const App = () => window.go?.app?.App
const RT = () => window.runtime

const $ = (id) => document.getElementById(id)
const fmt = (n) => Math.round(n).toLocaleString()
const fmt1 = (n) => Number(n).toFixed(1)
const fmt2 = (n) => Number(n).toFixed(2)

// --- Chart setup -------------------------------------------------------------
let chart
function initChart() {
  const ctx = $('chart').getContext('2d')
  chart = new Chart(ctx, {
    type: 'line',
    data: {
      labels: [],
      datasets: [
        {
          label: 'events/sec', yAxisID: 'y', data: [],
          borderColor: '#5b8cff', backgroundColor: 'rgba(91,140,255,.15)',
          borderWidth: 2, fill: true, tension: 0.25, pointRadius: 0
        },
        {
          label: 'MB/sec', yAxisID: 'y1', data: [],
          borderColor: '#3ddc97', backgroundColor: 'rgba(61,220,151,.10)',
          borderWidth: 2, fill: false, tension: 0.25, pointRadius: 0
        }
      ]
    },
    options: {
      animation: false,
      responsive: true,
      maintainAspectRatio: false,
      interaction: { mode: 'index', intersect: false },
      scales: {
        x: { title: { display: true, text: 'elapsed (s)' }, grid: { color: '#1e2433' } },
        y: {
          type: 'linear', position: 'left', beginAtZero: true,
          title: { display: true, text: 'events/sec' }, grid: { color: '#1e2433' }
        },
        y1: {
          type: 'linear', position: 'right', beginAtZero: true,
          title: { display: true, text: 'MB/sec' }, grid: { drawOnChartArea: false }
        }
      },
      plugins: { legend: { labels: { color: '#c9d4e5' } } }
    }
  })
}

function resetChart() {
  chart.data.labels = []
  chart.data.datasets.forEach((d) => (d.data = []))
  chart.update()
}

// --- State / UI helpers ------------------------------------------------------
function setRunning(running) {
  $('startBtn').disabled = running
  $('stopBtn').disabled = !running
  const rs = $('runState')
  rs.innerHTML = running
    ? '<span class="dot live"></span> Running'
    : '<span class="dot idle"></span> Idle'
  // lock the form while running
  document.querySelectorAll('.config input, .config select, #browse')
    .forEach((el) => (el.disabled = running))
  $('startBtn').disabled = running
  $('stopBtn').disabled = !running
}

function showError(msg) {
  $('errBox').textContent = msg || ''
}

function updateTransportFields() {
  const t = $('transport').value
  document.querySelectorAll('.fld-framing').forEach((e) => (e.style.display = t === 'tcp' ? '' : 'none'))
  document.querySelectorAll('.fld-batch, .fld-tls').forEach((e) => (e.style.display = t === 'otlp' ? '' : 'none'))
}

function resetStats() {
  $('statEps').textContent = '0'
  $('statAvgEps').textContent = '0'
  $('statMbps').innerHTML = '0 <small>MB/s</small>'
  $('statMsgs').textContent = '0'
  $('statElapsed').innerHTML = '0.0 <small>s</small>'
  $('statErrors').textContent = '0'
  $('summary').classList.add('hidden')
}

function onStats(s) {
  $('statEps').textContent = fmt(s.instEps)
  $('statAvgEps').textContent = fmt(s.avgEps)
  $('statMbps').innerHTML = `${fmt2(s.instMBps)} <small>MB/s</small>`
  $('statMsgs').textContent = fmt(s.messages)
  $('statElapsed').innerHTML = `${fmt1(s.elapsedSec)} <small>s</small>`
  $('statErrors').textContent = fmt(s.errors)

  chart.data.labels.push(fmt1(s.elapsedSec))
  chart.data.datasets[0].data.push(Math.round(s.instEps))
  chart.data.datasets[1].data.push(Number(s.instMBps.toFixed(2)))
  // keep at most ~600 points
  if (chart.data.labels.length > 600) {
    chart.data.labels.shift()
    chart.data.datasets.forEach((d) => d.data.shift())
  }
  chart.update()
}

function onDone(r) {
  setRunning(false)
  const rows = [
    ['Throughput', `${fmt(r.avgEps)} events/sec`],
    ['Throughput', `${fmt2(r.avgMBps)} MB/sec`],
    ['Messages sent', fmt(r.messages)],
    ['Bytes sent', `${fmt2(r.bytes / (1024 * 1024))} MB`],
    ['Avg message size', `${Math.round(r.avgMsgBytes)} bytes`],
    ['Duration', `${fmt2(r.durationSec)} s`],
    ['Lines loaded', fmt(r.linesLoaded)],
    ['Errors', fmt(r.errors)]
  ]
  $('summaryTable').innerHTML = rows
    .map(([k, v]) => `<tr><th>${k}</th><td>${v}</td></tr>`)
    .join('')
  $('summary').classList.remove('hidden')
}

// --- Form <-> config ---------------------------------------------------------
function applyDefaults(d) {
  if (!d) return
  $('target').value = d.target ?? ''
  $('transport').value = d.transport ?? 'tcp'
  $('logs').value = d.logs ?? 'testdata/logs'
  $('workers').value = d.workers ?? 8
  $('durationSec').value = d.durationSec ?? 30
  $('rate').value = d.rate ?? 0
  $('count').value = d.count ?? 0
  $('format').value = d.format ?? 'rfc5424'
  $('framing').value = d.framing ?? 'octet'
  $('batch').value = d.batch ?? 100
  $('otlpTLS').checked = !!d.otlpTLS
  updateTransportFields()
}

function readConfig() {
  return {
    target: $('target').value.trim(),
    transport: $('transport').value,
    logs: $('logs').value.trim(),
    workers: parseInt($('workers').value, 10) || 1,
    durationSec: parseInt($('durationSec').value, 10) || 0,
    count: parseInt($('count').value, 10) || 0,
    rate: parseInt($('rate').value, 10) || 0,
    format: $('format').value,
    framing: $('framing').value,
    facility: 1,
    severity: 6,
    batch: parseInt($('batch').value, 10) || 100,
    otlpTLS: $('otlpTLS').checked,
    appName: 'axobench',
    service: 'axobench'
  }
}

async function start() {
  showError('')
  const cfg = readConfig()
  if (!cfg.target) {
    showError('Target address is required (e.g. 127.0.0.1:514).')
    return
  }
  resetStats()
  resetChart()
  setRunning(true)
  try {
    await App().Start(cfg)
  } catch (e) {
    setRunning(false)
    showError(String(e))
  }
}

async function stop() {
  try { await App().Stop() } catch (_) {}
}

async function browse() {
  try {
    const p = await App().BrowseLogs()
    if (p) $('logs').value = p
  } catch (_) {}
}

// --- Wire up -----------------------------------------------------------------
function wireEvents() {
  const rt = RT()
  if (!rt) return
  rt.EventsOn('stats', onStats)
  rt.EventsOn('done', onDone)
  rt.EventsOn('error', (msg) => {
    setRunning(false)
    showError(String(msg))
  })
}

window.addEventListener('DOMContentLoaded', async () => {
  initChart()
  resetStats()
  $('startBtn').addEventListener('click', start)
  $('stopBtn').addEventListener('click', stop)
  $('browse').addEventListener('click', browse)
  $('transport').addEventListener('change', updateTransportFields)
  wireEvents()

  // Populate defaults from the backend (falls back gracefully if not in Wails).
  try {
    if (App()?.Defaults) applyDefaults(await App().Defaults())
    else updateTransportFields()
  } catch {
    updateTransportFields()
  }
})
