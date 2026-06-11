import React, { useMemo } from "react";
import { interpolate, useCurrentFrame } from "remotion";

interface Star {
  x: number;
  y: number;
  size: number;
  phase: number;
  speed: number;
  maxOpacity: number;
}

export const Starfield: React.FC = () => {
  const frame = useCurrentFrame();

  const stars = useMemo<Star[]>(() => {
    const result: Star[] = [];
    for (let i = 0; i < 120; i++) {
      result.push({
        x: Math.random() * 100,
        y: Math.random() * 100,
        size: 1 + Math.random() * 2.5,
        phase: Math.random() * Math.PI * 2,
        speed: 0.02 + Math.random() * 0.04,
        maxOpacity: 0.3 + Math.random() * 0.7,
      });
    }
    return result;
  }, []);

  return (
    <div style={{ position: "absolute", inset: 0, zIndex: 0 }}>
      {stars.map((star, i) => {
        const opacity =
          star.maxOpacity *
          (0.5 + 0.5 * Math.sin(frame * star.speed + star.phase));
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: `${star.x}%`,
              top: `${star.y}%`,
              width: star.size,
              height: star.size,
              borderRadius: "50%",
              background: "#fff",
              opacity,
            }}
          />
        );
      })}
    </div>
  );
};

export const ShootingStar: React.FC<{ startFrame: number }> = ({
  startFrame,
}) => {
  const frame = useCurrentFrame();
  const progress = interpolate(frame - startFrame, [0, 40], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  if (frame < startFrame || frame > startFrame + 45) return null;

  const x = interpolate(progress, [0, 1], [-150, 1200]);
  const opacity = progress < 0.7 ? 1 : interpolate(progress, [0.7, 1], [1, 0]);

  return (
    <div
      style={{
        position: "absolute",
        width: 120,
        height: 2,
        background:
          "linear-gradient(90deg, rgba(185,155,75,0.9), transparent)",
        top: "15%",
        left: x,
        transform: "rotate(-25deg)",
        opacity,
        zIndex: 1,
      }}
    />
  );
};

export const AmbientOrbs: React.FC = () => {
  const frame = useCurrentFrame();
  const drift = Math.sin(frame * 0.01) * 40;
  const drift2 = Math.cos(frame * 0.008) * 30;

  return (
    <>
      <div
        style={{
          position: "absolute",
          width: 500,
          height: 500,
          borderRadius: "50%",
          background:
            "radial-gradient(circle, rgba(185,155,75,0.25), transparent 70%)",
          filter: "blur(100px)",
          top: "10%",
          left: "-10%",
          transform: `translate(${drift}px, ${drift2}px)`,
          zIndex: 0,
        }}
      />
      <div
        style={{
          position: "absolute",
          width: 400,
          height: 400,
          borderRadius: "50%",
          background:
            "radial-gradient(circle, rgba(74,144,217,0.15), transparent 70%)",
          filter: "blur(100px)",
          bottom: "10%",
          right: "-10%",
          transform: `translate(${-drift2}px, ${-drift}px)`,
          zIndex: 0,
        }}
      />
    </>
  );
};
