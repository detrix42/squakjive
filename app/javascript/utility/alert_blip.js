// Play public/sounds/new_message_alert.wav via Web Audio API (most reliable cross-browser).
// Browsers require a user gesture before audio can play; we unlock on first interaction.

const ALERT_SOUND_URL = "/sounds/new_message_alert.wav"
const ALERT_VOLUME = 1.5
const FALLBACK_TONE_VOLUME = 0.405

let sharedBlip = null

export function getAlertBlip() {
  if (!sharedBlip) {
    sharedBlip = new AlertBlip()
  }
  return sharedBlip
}

class AlertBlip {
  constructor() {
    this.audioContext = null
    this.audioBuffer = null
    this.bufferReady = null
    this.unlocked = false
    this.lastPlayedAt = 0
    this.bindUnlock()
  }

  bindUnlock() {
    const unlock = () => {
      if (this.unlocked) return

      const AudioContext = window.AudioContext || window.webkitAudioContext
      if (!AudioContext) return

      this.audioContext = new AudioContext()
      this.bufferReady = this.prepareSound()
      this.unlocked = true
    }

    const options = { capture: true, passive: true }
    document.addEventListener("click", unlock, options)
    document.addEventListener("keydown", unlock, options)
    document.addEventListener("touchstart", unlock, options)
  }

  async prepareSound() {
    if (!this.audioContext) return false

    await this.audioContext.resume().catch(() => {})

    try {
      const response = await fetch(ALERT_SOUND_URL, { cache: "force-cache" })
      if (!response.ok) return false

      const data = await response.arrayBuffer()
      this.audioBuffer = await this.audioContext.decodeAudioData(data)
      return true
    } catch (_) {
      return false
    }
  }

  async play() {
    if (!this.unlocked || !this.audioContext) return

    const now = Date.now()
    if (now - this.lastPlayedAt < 650) return
    this.lastPlayedAt = now

    if (this.bufferReady) {
      await this.bufferReady
    }

    if (this.audioBuffer) {
      const played = await this.playBuffer()
      if (played) return
    }

    this.playFallback()
  }

  async playBuffer() {
    const ctx = this.audioContext
    if (!ctx || !this.audioBuffer) return false

    if (ctx.state === "suspended") {
      await ctx.resume().catch(() => {})
    }

    try {
      const source = ctx.createBufferSource()
      const gain = ctx.createGain()

      source.buffer = this.audioBuffer
      gain.gain.value = ALERT_VOLUME

      source.connect(gain)
      gain.connect(ctx.destination)
      source.start()

      return true
    } catch (_) {
      return false
    }
  }

  playFallback() {
    if (!this.audioContext) return

    const ctx = this.audioContext
    if (ctx.state === "suspended") {
      ctx.resume().catch(() => {})
    }

    const toneDuration = 0.3
    const start = ctx.currentTime

    this.playTone(ctx, 880, start, toneDuration)
    this.playTone(ctx, 1080, start + toneDuration, toneDuration)
  }

  playTone(ctx, frequency, startTime, duration, volume = FALLBACK_TONE_VOLUME) {
    const oscillator = ctx.createOscillator()
    const gain = ctx.createGain()
    const attack = 0.02
    const release = 0.04

    oscillator.type = "sine"
    oscillator.frequency.value = frequency

    gain.gain.setValueAtTime(0.0001, startTime)
    gain.gain.exponentialRampToValueAtTime(volume, startTime + attack)
    gain.gain.setValueAtTime(volume, startTime + duration - release)
    gain.gain.exponentialRampToValueAtTime(0.0001, startTime + duration)

    oscillator.connect(gain)
    gain.connect(ctx.destination)

    oscillator.start(startTime)
    oscillator.stop(startTime + duration + 0.01)
  }
}