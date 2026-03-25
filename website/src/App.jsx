import React, { useState, useEffect, useCallback, useRef } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { Sparkles, ChevronDown, Star } from 'lucide-react'
import { zodiacSigns } from './data/zodiac'
import zodiacIcons from './components/ZodiacIcons'

const INTERVAL = 6000

function hexToRgb(hex) {
  const r = parseInt(hex.slice(1, 3), 16)
  const g = parseInt(hex.slice(3, 5), 16)
  const b = parseInt(hex.slice(5, 7), 16)
  return `${r}, ${g}, ${b}`
}

function ProgressBar({ progress, color }) {
  return (
    <div className="absolute bottom-0 left-0 right-0 h-[3px] bg-white/10">
      <motion.div
        className="h-full"
        style={{ backgroundColor: color }}
        initial={{ width: '0%' }}
        animate={{ width: `${progress}%` }}
        transition={{ duration: 0.1, ease: 'linear' }}
      />
    </div>
  )
}

function CardContent({ sign, direction }) {
  const Icon = zodiacIcons[sign.name]
  const rgb = hexToRgb(sign.color)

  return (
    <motion.div
      className="absolute inset-0 flex flex-col justify-end"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.6 }}
    >
      {/* Background Image with zoom-out effect */}
      <motion.div
        className="absolute inset-0"
        initial={{ scale: 1.15 }}
        animate={{ scale: 1 }}
        exit={{ scale: 1.05, opacity: 0 }}
        transition={{ duration: 6, ease: [0.25, 0.1, 0.25, 1] }}
      >
        <img
          src={sign.image}
          alt={sign.name}
          className="w-full h-full object-cover"
          loading="eager"
        />
      </motion.div>

      {/* Color overlay */}
      <div
        className="absolute inset-0"
        style={{
          background: `linear-gradient(
            to bottom,
            rgba(${rgb}, 0.08) 0%,
            rgba(${rgb}, 0.15) 40%,
            rgba(0, 0, 0, 0.7) 75%,
            rgba(0, 0, 0, 0.92) 100%
          )`,
        }}
      />

      {/* Subtle top vignette */}
      <div className="absolute inset-0 pointer-events-none"
        style={{
          background: 'linear-gradient(to bottom, rgba(0,0,0,0.3) 0%, transparent 30%)',
        }}
      />

      {/* Text content */}
      <div className="relative z-10 p-6 sm:p-8 md:p-12 lg:p-16 pb-24 sm:pb-28 md:pb-32">
        {/* Element badge */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ type: 'spring', stiffness: 200, damping: 20, delay: 0.1 }}
          className="mb-3"
        >
          <span
            className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-sans font-medium tracking-widest uppercase"
            style={{
              backgroundColor: `rgba(${rgb}, 0.2)`,
              color: sign.color,
              border: `1px solid rgba(${rgb}, 0.3)`,
            }}
          >
            <Sparkles className="w-3 h-3" />
            {sign.element}
          </span>
        </motion.div>

        {/* Zodiac icon + name */}
        <motion.div
          className="flex items-center gap-4 mb-2"
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ type: 'spring', stiffness: 180, damping: 18, delay: 0.2 }}
        >
          {Icon && (
            <div
              className="w-12 h-12 sm:w-14 sm:h-14 rounded-full flex items-center justify-center"
              style={{
                backgroundColor: `rgba(${rgb}, 0.2)`,
                border: `1.5px solid rgba(${rgb}, 0.4)`,
              }}
            >
              <Icon className="w-7 h-7 sm:w-8 sm:h-8" style={{ color: sign.color }} />
            </div>
          )}
          <div>
            <h2
              className="text-4xl sm:text-5xl md:text-6xl lg:text-7xl font-serif font-semibold tracking-tight text-white"
              style={{ textShadow: '0 2px 20px rgba(0,0,0,0.5)' }}
            >
              {sign.name}
            </h2>
          </div>
        </motion.div>

        {/* Dates */}
        <motion.p
          className="text-sm sm:text-base font-sans font-light tracking-wide text-white/60 mb-4 ml-0.5"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ type: 'spring', stiffness: 180, damping: 18, delay: 0.35 }}
        >
          {sign.dates}
        </motion.p>

        {/* Description */}
        <motion.p
          className="text-base sm:text-lg md:text-xl font-sans font-light leading-relaxed text-white/80 max-w-xl"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ type: 'spring', stiffness: 180, damping: 18, delay: 0.45 }}
          style={{ textShadow: '0 1px 10px rgba(0,0,0,0.4)' }}
        >
          {sign.description}
        </motion.p>
      </div>
    </motion.div>
  )
}

function ThumbnailNav({ signs, activeIndex, onSelect }) {
  const containerRef = useRef(null)

  useEffect(() => {
    if (!containerRef.current) return
    const active = containerRef.current.children[activeIndex]
    if (active) {
      active.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' })
    }
  }, [activeIndex])

  return (
    <div
      ref={containerRef}
      className="flex items-center gap-2 sm:gap-3 overflow-x-auto px-4 sm:px-6 md:px-8 scrollbar-hide"
      style={{ scrollbarWidth: 'none', msOverflowStyle: 'none' }}
    >
      {signs.map((sign, i) => {
        const isActive = i === activeIndex
        const Icon = zodiacIcons[sign.name]
        const rgb = hexToRgb(sign.color)

        return (
          <motion.button
            key={sign.name}
            onClick={() => onSelect(i)}
            className="relative flex-shrink-0 rounded-xl overflow-hidden cursor-pointer focus:outline-none group"
            animate={{
              width: isActive ? 72 : 52,
              height: isActive ? 72 : 52,
              filter: isActive ? 'grayscale(0)' : 'grayscale(0.8)',
              opacity: isActive ? 1 : 0.5,
            }}
            whileHover={{ opacity: 0.9, filter: 'grayscale(0.2)', scale: 1.05 }}
            transition={{ type: 'spring', stiffness: 300, damping: 25 }}
          >
            <img
              src={sign.image}
              alt={sign.name}
              className="w-full h-full object-cover"
              loading="lazy"
            />
            {/* Color overlay on thumbnail */}
            <div
              className="absolute inset-0 transition-opacity"
              style={{
                background: `rgba(${rgb}, ${isActive ? 0.15 : 0.05})`,
              }}
            />
            {/* Active border glow */}
            {isActive && (
              <motion.div
                className="absolute inset-0 rounded-xl"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                style={{
                  boxShadow: `inset 0 0 0 2px ${sign.color}, 0 0 12px rgba(${rgb}, 0.4)`,
                }}
              />
            )}
            {/* Zodiac icon overlay */}
            <div className="absolute inset-0 flex items-center justify-center">
              {Icon && (
                <Icon
                  className="w-5 h-5 drop-shadow-lg"
                  style={{ color: isActive ? sign.color : 'rgba(255,255,255,0.7)' }}
                />
              )}
            </div>
          </motion.button>
        )
      })}
    </div>
  )
}

function Navbar() {
  return (
    <motion.nav
      className="absolute top-0 left-0 right-0 z-50 flex items-center justify-between px-6 sm:px-8 md:px-12 py-5"
      initial={{ opacity: 0, y: -20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.5, duration: 0.8 }}
    >
      <div className="flex items-center gap-2">
        <Star className="w-5 h-5 text-amber-400" fill="currentColor" />
        <span className="text-white font-serif text-xl font-semibold tracking-wide">
          Simastry
        </span>
      </div>
      <div className="hidden sm:flex items-center gap-6 text-sm font-sans font-light text-white/60">
        <a href="#features" className="hover:text-white/90 transition-colors">Features</a>
        <a href="#compatibility" className="hover:text-white/90 transition-colors">Compatibility</a>
        <a href="https://simastry.com" className="px-4 py-2 rounded-full bg-white/10 hover:bg-white/20 text-white/90 transition-all backdrop-blur-sm border border-white/10">
          Download
        </a>
      </div>
    </motion.nav>
  )
}

export default function App() {
  const [activeIndex, setActiveIndex] = useState(0)
  const [progress, setProgress] = useState(0)
  const [isPaused, setIsPaused] = useState(false)
  const [direction, setDirection] = useState(1)
  const intervalRef = useRef(null)
  const startTimeRef = useRef(Date.now())

  const goTo = useCallback((index) => {
    setDirection(index > activeIndex ? 1 : -1)
    setActiveIndex(index)
    setProgress(0)
    startTimeRef.current = Date.now()
  }, [activeIndex])

  const next = useCallback(() => {
    setDirection(1)
    setActiveIndex((prev) => (prev + 1) % zodiacSigns.length)
    setProgress(0)
    startTimeRef.current = Date.now()
  }, [])

  // Auto-rotation timer
  useEffect(() => {
    if (isPaused) return

    const tick = () => {
      const elapsed = Date.now() - startTimeRef.current
      const pct = Math.min((elapsed / INTERVAL) * 100, 100)
      setProgress(pct)

      if (elapsed >= INTERVAL) {
        next()
      }
    }

    intervalRef.current = setInterval(tick, 50)
    return () => clearInterval(intervalRef.current)
  }, [isPaused, next, activeIndex])

  const activeSign = zodiacSigns[activeIndex]

  return (
    <div
      className="relative w-full h-full bg-black overflow-hidden select-none"
      onMouseEnter={() => setIsPaused(true)}
      onMouseLeave={() => {
        setIsPaused(false)
        startTimeRef.current = Date.now() - (progress / 100) * INTERVAL
      }}
    >
      <Navbar />

      {/* Main card area */}
      <div className="absolute inset-0">
        <AnimatePresence mode="wait" initial={false}>
          <CardContent
            key={activeIndex}
            sign={activeSign}
            direction={direction}
          />
        </AnimatePresence>
      </div>

      {/* Bottom section: thumbnails + progress */}
      <div className="absolute bottom-0 left-0 right-0 z-30">
        {/* Gradient fade above thumbnails */}
        <div className="h-24 bg-gradient-to-t from-black/90 to-transparent pointer-events-none" />

        <div className="bg-black/80 backdrop-blur-md pb-4 pt-3 border-t border-white/5">
          <ThumbnailNav
            signs={zodiacSigns}
            activeIndex={activeIndex}
            onSelect={goTo}
          />
        </div>

        <ProgressBar progress={progress} color={activeSign.color} />
      </div>

      {/* Scroll hint */}
      <motion.div
        className="absolute bottom-28 sm:bottom-32 right-6 sm:right-8 md:right-12 z-20"
        initial={{ opacity: 0 }}
        animate={{ opacity: 0.4, y: [0, 6, 0] }}
        transition={{ delay: 2, duration: 2, repeat: Infinity }}
      >
        <ChevronDown className="w-5 h-5 text-white" />
      </motion.div>
    </div>
  )
}
