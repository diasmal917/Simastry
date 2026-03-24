import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { colors } from "../styles";

interface Testimonial {
  quote: string;
  author: string;
  appearFrame: number;
  disappearFrame: number;
}

const testimonials: Testimonial[] = [
  {
    quote:
      '"I finally understand why my boss communicates the way she does. Game changer."',
    author: "— Sarah M.",
    appearFrame: 10,
    disappearFrame: 70,
  },
  {
    quote:
      '"My partner and I use it every day. It\'s like having a relationship translator."',
    author: "— James K.",
    appearFrame: 75,
    disappearFrame: 999,
  },
];

export const SceneTestimonials: React.FC = () => {
  const frame = useCurrentFrame();

  return (
    <AbsoluteFill
      style={{
        alignItems: "center",
        justifyContent: "center",
        padding: "0 80px",
      }}
    >
      {testimonials.map((t, i) => {
        const opacity = interpolate(
          frame,
          [
            t.appearFrame,
            t.appearFrame + 15,
            t.disappearFrame,
            t.disappearFrame + 12,
          ],
          [0, 1, 1, 0],
          { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
        );
        const y = interpolate(
          frame,
          [t.appearFrame, t.appearFrame + 15],
          [25, 0],
          { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
        );

        return (
          <div
            key={i}
            style={{
              position: "absolute",
              textAlign: "center",
              maxWidth: 800,
              opacity,
              transform: `translateY(${y}px)`,
            }}
          >
            <div
              style={{
                fontSize: 36,
                letterSpacing: 5,
                marginBottom: 25,
                color: colors.gold,
              }}
            >
              ★★★★★
            </div>
            <div
              style={{
                fontSize: 38,
                fontWeight: 500,
                lineHeight: 1.5,
                fontStyle: "italic",
                color: colors.text,
                marginBottom: 20,
              }}
            >
              {t.quote}
            </div>
            <div style={{ fontSize: 26, color: colors.gold }}>
              {t.author}
            </div>
          </div>
        );
      })}
    </AbsoluteFill>
  );
};
