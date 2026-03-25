import React from 'react'

const iconProps = {
  xmlns: 'http://www.w3.org/2000/svg',
  viewBox: '0 0 64 64',
  fill: 'none',
  stroke: 'currentColor',
  strokeWidth: 2.5,
  strokeLinecap: 'round',
  strokeLinejoin: 'round',
}

export const Aries = (props) => (
  <svg {...iconProps} {...props}>
    <path d="M20 48 C20 28, 20 20, 32 12 C44 20, 44 28, 44 48" />
    <path d="M32 12 L32 52" />
  </svg>
)

export const Taurus = (props) => (
  <svg {...iconProps} {...props}>
    <circle cx="32" cy="40" r="14" />
    <path d="M18 18 C18 12, 24 8, 32 14 C40 8, 46 12, 46 18" />
  </svg>
)

export const Gemini = (props) => (
  <svg {...iconProps} {...props}>
    <path d="M16 14 L48 14" />
    <path d="M16 50 L48 50" />
    <path d="M24 14 L24 50" />
    <path d="M40 14 L40 50" />
  </svg>
)

export const Cancer = (props) => (
  <svg {...iconProps} {...props}>
    <path d="M16 28 C16 18, 32 18, 32 28 C32 38, 16 38, 16 28" />
    <path d="M48 36 C48 46, 32 46, 32 36 C32 26, 48 26, 48 36" />
  </svg>
)

export const Leo = (props) => (
  <svg {...iconProps} {...props}>
    <circle cx="24" cy="24" r="10" />
    <path d="M34 24 C34 36, 44 42, 44 48" />
    <circle cx="44" cy="48" r="4" />
  </svg>
)

export const Virgo = (props) => (
  <svg {...iconProps} {...props}>
    <path d="M16 16 L16 48" />
    <path d="M16 28 C16 20, 28 20, 28 28 L28 48" />
    <path d="M28 28 C28 20, 40 20, 40 28 L40 48" />
    <path d="M40 36 C46 36, 48 42, 46 48" />
  </svg>
)

export const Libra = (props) => (
  <svg {...iconProps} {...props}>
    <path d="M16 40 L48 40" />
    <path d="M16 48 L48 48" />
    <path d="M22 40 C22 26, 32 20, 32 20 C32 20, 42 26, 42 40" />
  </svg>
)

export const Scorpio = (props) => (
  <svg {...iconProps} {...props}>
    <path d="M16 16 L16 48" />
    <path d="M16 28 C16 20, 28 20, 28 28 L28 48" />
    <path d="M28 28 C28 20, 40 20, 40 28 L40 48" />
    <path d="M40 48 L48 40" />
    <path d="M44 44 L48 40 L48 48" />
  </svg>
)

export const Sagittarius = (props) => (
  <svg {...iconProps} {...props}>
    <path d="M18 46 L46 18" />
    <path d="M34 18 L46 18 L46 30" />
    <path d="M24 34 L34 24" />
  </svg>
)

export const Capricorn = (props) => (
  <svg {...iconProps} {...props}>
    <path d="M18 16 C18 16, 18 36, 28 36 C38 36, 38 16, 38 16" />
    <path d="M38 36 C38 44, 44 48, 48 44 C52 40, 46 34, 42 36" />
  </svg>
)

export const Aquarius = (props) => (
  <svg {...iconProps} {...props}>
    <path d="M14 26 L22 20 L30 26 L38 20 L46 26 L50 22" />
    <path d="M14 38 L22 32 L30 38 L38 32 L46 38 L50 34" />
  </svg>
)

export const Pisces = (props) => (
  <svg {...iconProps} {...props}>
    <path d="M20 16 C20 16, 32 24, 32 32 C32 40, 20 48, 20 48" />
    <path d="M44 16 C44 16, 32 24, 32 32 C32 40, 44 48, 44 48" />
    <path d="M16 32 L48 32" />
  </svg>
)

const zodiacIcons = {
  Aries, Taurus, Gemini, Cancer, Leo, Virgo,
  Libra, Scorpio, Sagittarius, Capricorn, Aquarius, Pisces,
}

export default zodiacIcons
