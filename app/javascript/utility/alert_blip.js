// Notification sound from public/sounds/new_message_alert.wav, with Web Audio fallback.
// Browsers require a user gesture before audio can play; we unlock on first interaction.

const ALERT_SOUND_URL = "/sounds/new_message_alert.wav"
const FALLBACK_TONE_VOLUME = 0.27

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
    this.audio = null
    this.unlocked = false
    this.lastPlayedAt = 0
    this.bindUnlock()
  }

  bindUnlock() {
    const unlock = () => {
      if (this.unlocked) return

      const AudioContext = window.AudioContext || window.webkitAudioContext
      if (AudioContext) {
        this.audioContext = new AudioContext()
        this.audioContext.resume().catch(() => {})
      }

      this.audio = new Audio(ALERT_SOUND_URL)
      this.audio.preload = "auto"
      this.audio.load()

      this.unlocked = true
    }

    const options = { capture: true, passive: true }
    document.addEventListener("click", unlock, options)
    document.addEventListener("keydown", unlock, options)
    document.addEventListener("touchstart", unlock, options)
  }

  play() {
    if (!this.unlocked) return

    const now = Date.now()
    if (now - this.lastPlayedAt < 650) return
    this.lastPlayedAt = now

    if (this.audio) {
      this.audio.volume = 1
      this.audio.currentTime = 0
      this.audio.play().catch(() => this.playFallback())
      return
    }

    this.playFallback()
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