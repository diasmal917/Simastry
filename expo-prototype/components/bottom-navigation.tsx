import { BlurView } from "expo-blur";
import * as Haptics from "expo-haptics";
import { LinearGradient } from "expo-linear-gradient";
import { useEffect, useMemo, useRef } from "react";
import { Animated, Easing, Pressable, StyleSheet, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";

type TabKey = "home" | "predict" | "companions" | "messages" | "about";

type Tab = {
  key: TabKey;
  label: string;
};

type Props = {
  activeTab: string;
  onChange: (tab: string) => void;
};

export const bottomNavTokens = {
  barRadius: 34,
  barHorizontalMargin: 24,
  barMinHeight: 80,
  gold: "#f0cf78",
  goldDeep: "#8c5d1d",
  cream: "#fff4d2",
  blue: "#69bdff",
  glassBorder: "rgba(255,220,133,0.58)",
  glowIntensity: 0.1,
  iconSize: 24,
  centerSize: 62,
  animationSpeedMs: 6800
};

const tabs: Tab[] = [
  { key: "home", label: "Profile" },
  { key: "predict", label: "Predict" },
  { key: "companions", label: "" },
  { key: "messages", label: "Messages" },
  { key: "about", label: "About Me" }
];

function CameraIcon({ active }: { active: boolean }) {
  return (
    <View style={[styles.iconOrb, active && styles.iconOrbActive]}>
      <LinearGradient
        colors={["rgba(255,238,177,0.2)", "rgba(0,0,0,0.1)", "rgba(255,210,104,0.16)"]}
        style={StyleSheet.absoluteFill}
      />
      <View style={styles.iconOrbShine} />
      <View style={[styles.cameraIcon, active && styles.iconActiveBorder]}>
        <LinearGradient
          colors={["rgba(255,245,207,0.18)", "rgba(0,0,0,0)", "rgba(218,164,63,0.18)"]}
          style={StyleSheet.absoluteFill}
        />
        <View style={[styles.cameraLens, active && styles.iconActiveBorder]} />
        <View style={[styles.cameraFlash, active && styles.activeFill]} />
      </View>
    </View>
  );
}

function CrystalBallIcon({ active }: { active: boolean }) {
  return (
    <View style={[styles.iconOrb, active && styles.iconOrbActive]}>
      <View style={styles.iconOrbShine} />
      <View style={styles.crystalWrap}>
        <View style={[styles.crystalBall, active && styles.crystalBallActive]}>
          <LinearGradient
            colors={["rgba(255,246,255,0.98)", "rgba(153,106,255,0.95)", "rgba(83,54,206,0.98)", "rgba(26,18,74,0.98)"]}
            locations={[0, 0.28, 0.62, 1]}
            style={StyleSheet.absoluteFill}
          />
          <View style={styles.crystalGlowSpot} />
          <View style={styles.crystalHorizon} />
          <View style={styles.crystalHighlight} />
          <View style={styles.crystalSparkleOne} />
          <View style={styles.crystalSparkleTwo} />
          <View style={styles.crystalSparkleThree} />
        </View>
        <View style={styles.crystalStem} />
        <View style={[styles.crystalBase, active && styles.crystalBaseActive]} />
      </View>
    </View>
  );
}

function MessageIcon({ active }: { active: boolean }) {
  return (
    <View style={[styles.iconOrb, active && styles.iconOrbActive]}>
      <View style={styles.iconOrbShine} />
      <View style={styles.messageWrap}>
        <View style={styles.messageTail}>
          <LinearGradient
            colors={active ? ["rgba(127,210,255,0.98)", "rgba(25,106,223,0.9)"] : ["rgba(112,196,255,0.72)", "rgba(30,96,196,0.68)"]}
            style={StyleSheet.absoluteFill}
          />
        </View>
        <View style={[styles.messageBubble, active && styles.messageBubbleActive]}>
        <LinearGradient
          colors={active ? ["rgba(183,232,255,1)", "rgba(54,168,255,0.96)", "rgba(18,88,205,0.94)"] : ["rgba(160,224,255,0.78)", "rgba(59,153,238,0.72)", "rgba(20,79,174,0.76)"]}
          locations={[0, 0.42, 1]}
          style={StyleSheet.absoluteFill}
        />
        <View style={styles.messageShine} />
        <View style={styles.messageDotRow}>
          <View style={styles.messageDot} />
          <View style={styles.messageDot} />
          <View style={styles.messageDot} />
        </View>
        </View>
      </View>
    </View>
  );
}

function ProfileIcon({ active }: { active: boolean }) {
  return (
    <View style={[styles.iconOrb, active && styles.iconOrbActive]}>
      <View style={styles.iconOrbShine} />
      <View style={styles.profileIcon}>
        <LinearGradient
          colors={["rgba(255,238,177,0.2)", "rgba(0,0,0,0.06)", "rgba(255,210,104,0.12)"]}
          style={StyleSheet.absoluteFill}
        />
        <View style={[styles.profileHead, active && styles.iconActiveBorder]} />
        <View style={[styles.profileShoulders, active && styles.iconActiveBorder]} />
      </View>
    </View>
  );
}

function CenterStarIcon() {
  return (
    <View style={styles.centerDisc}>
      <LinearGradient
        colors={["rgba(255,255,255,0.035)", "rgba(0,0,0,0.95)", "rgba(10,9,8,0.96)", "rgba(52,36,13,0.76)"]}
        locations={[0, 0.48, 0.76, 1]}
        style={StyleSheet.absoluteFill}
      />
      <Text style={styles.centerStar}>✦</Text>
      <View style={styles.centerStarGlint} />
    </View>
  );
}

function CenterStar({ glowValue }: { glowValue: Animated.Value }) {
  const glowStyle = {
    opacity: glowValue.interpolate({ inputRange: [0, 1], outputRange: [0.22, 0.44] }),
    transform: [
      {
        scale: glowValue.interpolate({ inputRange: [0, 1], outputRange: [0.96, 1.05] })
      }
    ]
  };

  return (
    <View style={styles.centerWrap}>
      <Animated.View style={[styles.centerGlow, glowStyle]} />
      <View style={styles.centerButton}>
        <LinearGradient
          colors={["rgba(255,220,106,0.74)", "rgba(148,86,18,0.72)", "rgba(22,17,11,0.94)", "rgba(237,177,65,0.54)"]}
          locations={[0, 0.2, 0.58, 1]}
          style={StyleSheet.absoluteFill}
        />
        <CenterStarIcon />
      </View>
    </View>
  );
}

function IconForTab({ tab, active, glowValue }: { tab: Tab; active: boolean; glowValue: Animated.Value }) {
  if (tab.key === "home") return <CameraIcon active={active} />;
  if (tab.key === "predict") return <CrystalBallIcon active={active} />;
  if (tab.key === "companions") return <CenterStar glowValue={glowValue} />;
  if (tab.key === "messages") return <MessageIcon active={active} />;
  return <ProfileIcon active={active} />;
}

export function BottomNavigation({ activeTab, onChange }: Props) {
  const insets = useSafeAreaInsets();
  const shimmer = useRef(new Animated.Value(0)).current;
  const glow = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    const shimmerLoop = Animated.loop(
      Animated.timing(shimmer, {
        toValue: 1,
        duration: bottomNavTokens.animationSpeedMs,
        easing: Easing.inOut(Easing.quad),
        useNativeDriver: true
      })
    );
    const glowLoop = Animated.loop(
      Animated.sequence([
        Animated.timing(glow, {
          toValue: 1,
          duration: 1800,
          easing: Easing.inOut(Easing.sin),
          useNativeDriver: true
        }),
        Animated.timing(glow, {
          toValue: 0,
          duration: 1800,
          easing: Easing.inOut(Easing.sin),
          useNativeDriver: true
        })
      ])
    );

    shimmerLoop.start();
    glowLoop.start();
    return () => {
      shimmerLoop.stop();
      glowLoop.stop();
    };
  }, [glow, shimmer]);

  const shimmerStyle = useMemo(
    () => ({
      transform: [
        {
          translateX: shimmer.interpolate({
            inputRange: [0, 1],
            outputRange: [-230, 230]
          })
        },
        { rotate: "-16deg" }
      ]
    }),
    [shimmer]
  );

  return (
    <View
      style={[
        styles.navHost,
        {
          left: bottomNavTokens.barHorizontalMargin,
          right: bottomNavTokens.barHorizontalMargin,
          bottom: Math.max(insets.bottom, 6)
        }
      ]}
    >
      <BlurView
        intensity={78}
        tint="dark"
        style={[
          styles.shell,
          {
            borderRadius: bottomNavTokens.barRadius
          }
        ]}
      >
        <LinearGradient
          colors={["rgba(255,244,198,0.22)", "rgba(255,255,255,0.045)", "rgba(0,0,0,0.34)", "rgba(138,91,25,0.18)"]}
          locations={[0, 0.24, 0.66, 1]}
          style={StyleSheet.absoluteFill}
        />
        <Animated.View pointerEvents="none" style={[styles.shimmer, shimmerStyle]}>
          <LinearGradient
            colors={["rgba(255,255,255,0)", "rgba(255,239,177,0.24)", "rgba(255,255,255,0)"]}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 0 }}
            style={StyleSheet.absoluteFill}
          />
        </Animated.View>
        <View style={styles.inner}>
          {tabs.map((tab) => {
            const active = activeTab === tab.key;
            const isCenter = tab.key === "companions";

            if (isCenter) {
              return <View key={tab.key} style={[styles.item, styles.centerSpacer]} />;
            }

            return (
              <Pressable
                key={tab.key}
                accessibilityRole="button"
                accessibilityLabel={tab.label}
                focusable={false}
                onPress={() => {
                  Haptics.selectionAsync();
                  onChange(tab.key);
                }}
                style={styles.item}
              >
                <View style={[styles.iconSlot, active && styles.activeIconSlot]}>
                  <IconForTab tab={tab} active={active} glowValue={glow} />
                </View>
                <Text numberOfLines={1} style={[styles.label, active && styles.activeLabel]}>
                  {tab.label}
                </Text>
              </Pressable>
            );
          })}
        </View>
      </BlurView>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel="Companions"
        focusable={false}
        onPress={() => {
          Haptics.selectionAsync();
          onChange("companions");
        }}
        style={styles.centerFloating}
      >
        <CenterStar glowValue={glow} />
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  navHost: {
    position: "absolute",
    height: bottomNavTokens.barMinHeight + 24,
    overflow: "visible"
  },
  shell: {
    position: "absolute",
    left: 0,
    right: 0,
    bottom: 0,
    overflow: "hidden",
    minHeight: bottomNavTokens.barMinHeight,
    borderWidth: 1,
    borderColor: "rgba(255,220,133,0.58)",
    backgroundColor: "rgba(3,3,3,0.93)",
    shadowColor: "#000",
    shadowOpacity: 0.5,
    shadowRadius: 22,
    shadowOffset: { width: 0, height: 12 }
  },
  shimmer: {
    position: "absolute",
    top: -34,
    bottom: -34,
    width: 150,
    opacity: 0.84
  },
  inner: {
    minHeight: bottomNavTokens.barMinHeight,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingHorizontal: 18,
    paddingTop: 8,
    paddingBottom: 10,
    backgroundColor: "rgba(9,8,7,0.48)",
    borderRadius: bottomNavTokens.barRadius
  },
  item: {
    flex: 1,
    minWidth: 48,
    alignItems: "center",
    justifyContent: "center",
    gap: 4
  },
  centerSpacer: {
    minWidth: 62
  },
  centerFloating: {
    position: "absolute",
    top: 2,
    left: "50%",
    marginLeft: -39,
    width: 78,
    height: 78,
    alignItems: "center",
    justifyContent: "center"
  },
  iconSlot: {
    width: 39,
    height: 39,
    borderRadius: 20,
    alignItems: "center",
    justifyContent: "center"
  },
  activeIconSlot: {
    backgroundColor: "transparent"
  },
  label: {
    color: "rgba(255,225,154,0.82)",
    fontSize: 10,
    lineHeight: 12,
    fontWeight: "500",
    letterSpacing: 0.1
  },
  activeLabel: {
    color: bottomNavTokens.gold
  },
  iconOrb: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: "center",
    justifyContent: "center",
    overflow: "hidden",
    borderWidth: 1,
    borderColor: "rgba(255,229,160,0.66)",
    backgroundColor: "rgba(9,8,8,0.84)",
    shadowColor: "#e7bf65",
    shadowOpacity: 0.34,
    shadowRadius: 7,
    shadowOffset: { width: 0, height: 0 }
  },
  iconOrbActive: {
    borderColor: "rgba(255,239,189,0.86)",
    shadowOpacity: 0.34
  },
  iconOrbShine: {
    position: "absolute",
    left: 6,
    right: 10,
    top: 5,
    height: 11,
    borderRadius: 999,
    backgroundColor: "rgba(255,255,255,0.12)",
    transform: [{ rotate: "-22deg" }]
  },
  cameraIcon: {
    width: 19,
    height: 19,
    borderRadius: 7,
    borderWidth: 1.8,
    borderColor: "rgba(243,207,114,0.9)",
    alignItems: "center",
    justifyContent: "center",
    overflow: "hidden"
  },
  cameraLens: {
    width: 9,
    height: 9,
    borderRadius: 5,
    borderWidth: 1.8,
    borderColor: "rgba(243,207,114,0.86)",
    backgroundColor: "rgba(0,0,0,0.18)"
  },
  cameraFlash: {
    position: "absolute",
    right: 4,
    top: 4,
    width: 3.5,
    height: 3.5,
    borderRadius: 2,
    backgroundColor: "rgba(250,221,142,0.92)"
  },
  activeFill: {
    backgroundColor: bottomNavTokens.gold
  },
  iconActiveBorder: {
    borderColor: bottomNavTokens.gold
  },
  crystalWrap: {
    width: 31,
    height: 31,
    alignItems: "center",
    justifyContent: "center"
  },
  crystalBall: {
    width: 27,
    height: 27,
    borderRadius: 14,
    overflow: "hidden",
    borderWidth: 1,
    borderColor: "rgba(249,226,166,0.72)",
    backgroundColor: "rgba(232,199,109,0.1)"
  },
  crystalBallActive: {
    borderColor: "rgba(255,240,190,0.82)",
    shadowColor: bottomNavTokens.gold,
    shadowOpacity: 0.22,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 2 }
  },
  crystalHighlight: {
    position: "absolute",
    left: 5,
    top: 4,
    width: 10,
    height: 7,
    borderRadius: 999,
    backgroundColor: "rgba(255,255,255,0.5)",
    transform: [{ rotate: "-24deg" }]
  },
  crystalHorizon: {
    position: "absolute",
    left: 5,
    right: 5,
    bottom: 7,
    height: 1,
    borderRadius: 999,
    backgroundColor: "rgba(255,255,255,0.22)"
  },
  crystalGlowSpot: {
    position: "absolute",
    right: 5,
    top: 8,
    width: 10,
    height: 10,
    borderRadius: 5,
    backgroundColor: "rgba(104,195,255,0.3)"
  },
  crystalSparkleOne: {
    position: "absolute",
    right: 8,
    top: 7,
    width: 3,
    height: 3,
    borderRadius: 2,
    backgroundColor: "rgba(255,255,255,0.88)"
  },
  crystalSparkleTwo: {
    position: "absolute",
    right: 9,
    bottom: 9,
    width: 2,
    height: 2,
    borderRadius: 1,
    backgroundColor: "rgba(255,255,255,0.72)"
  },
  crystalSparkleThree: {
    position: "absolute",
    left: 8,
    bottom: 8,
    width: 2,
    height: 2,
    borderRadius: 1,
    backgroundColor: "rgba(255,217,124,0.82)"
  },
  crystalStem: {
    position: "absolute",
    bottom: 3,
    width: 10,
    height: 5,
    borderRadius: 4,
    backgroundColor: "rgba(164,97,25,0.94)",
    borderWidth: 1,
    borderColor: "rgba(255,223,147,0.34)"
  },
  crystalBase: {
    position: "absolute",
    bottom: -1,
    width: 24,
    height: 7,
    borderRadius: 6,
    backgroundColor: "rgba(207,146,45,0.78)",
    borderWidth: 1,
    borderColor: "rgba(255,226,157,0.46)"
  },
  crystalBaseActive: {
    backgroundColor: "rgba(232,199,109,0.62)"
  },
  messageWrap: {
    width: 28,
    height: 26,
    alignItems: "center",
    justifyContent: "center",
    overflow: "visible"
  },
  messageBubble: {
    width: 27,
    height: 21,
    borderRadius: 12,
    overflow: "hidden",
    borderWidth: 1,
    borderColor: "rgba(168,220,255,0.34)"
  },
  messageBubbleActive: {
    borderColor: "rgba(205,238,255,0.9)",
    shadowColor: bottomNavTokens.blue,
    shadowOpacity: 0.3,
    shadowRadius: 9,
    shadowOffset: { width: 0, height: 2 }
  },
  messageShine: {
    position: "absolute",
    left: 5,
    right: 7,
    top: 4,
    height: 7,
    borderRadius: 999,
    backgroundColor: "rgba(255,255,255,0.32)"
  },
  messageDotRow: {
    position: "absolute",
    left: 6,
    right: 6,
    top: 9,
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center"
  },
  messageDot: {
    width: 3,
    height: 3,
    borderRadius: 2,
    backgroundColor: "rgba(255,255,255,0.94)"
  },
  messageTail: {
    position: "absolute",
    left: 3,
    bottom: 1,
    width: 9,
    height: 9,
    borderRadius: 2,
    overflow: "hidden",
    transform: [{ rotate: "-34deg" }]
  },
  profileIcon: {
    width: 25,
    height: 25,
    borderRadius: 16,
    borderWidth: 0,
    alignItems: "center",
    justifyContent: "center",
    overflow: "hidden"
  },
  profileHead: {
    width: 8,
    height: 8,
    borderRadius: 5,
    borderWidth: 2,
    borderColor: "rgba(243,207,114,0.86)",
    marginTop: 2
  },
  profileShoulders: {
    width: 16,
    height: 8,
    borderTopLeftRadius: 10,
    borderTopRightRadius: 10,
    borderWidth: 2,
    borderBottomWidth: 0,
    borderColor: "rgba(243,207,114,0.86)",
    marginTop: 2
  },
  centerWrap: {
    width: bottomNavTokens.centerSize + 16,
    height: bottomNavTokens.centerSize + 16,
    alignItems: "center",
    justifyContent: "center"
  },
  centerGlow: {
    position: "absolute",
    width: bottomNavTokens.centerSize + 18,
    height: bottomNavTokens.centerSize + 18,
    borderRadius: (bottomNavTokens.centerSize + 18) / 2,
    backgroundColor: "rgba(240,207,120,0.07)",
    shadowColor: bottomNavTokens.gold,
    shadowOpacity: bottomNavTokens.glowIntensity,
    shadowRadius: 14,
    shadowOffset: { width: 0, height: 0 }
  },
  centerButton: {
    width: bottomNavTokens.centerSize,
    height: bottomNavTokens.centerSize,
    borderRadius: bottomNavTokens.centerSize / 2,
    overflow: "hidden",
    alignItems: "center",
    justifyContent: "center",
    borderWidth: 1,
    borderColor: "rgba(255,231,161,0.72)",
    shadowColor: bottomNavTokens.gold,
    shadowOpacity: 0.14,
    shadowRadius: 9,
    shadowOffset: { width: 0, height: 2 }
  },
  centerDisc: {
    width: bottomNavTokens.centerSize - 12,
    height: bottomNavTokens.centerSize - 12,
    borderRadius: (bottomNavTokens.centerSize - 12) / 2,
    alignItems: "center",
    justifyContent: "center",
    overflow: "hidden",
    borderWidth: 0,
    borderColor: "transparent"
  },
  centerStar: {
    color: "#fff2b6",
    fontSize: 29,
    lineHeight: 33,
    fontWeight: "800",
    textShadowColor: "rgba(255,217,113,0.42)",
    textShadowRadius: 5,
    textShadowOffset: { width: 0, height: 1 }
  },
  centerStarGlint: {
    position: "absolute",
    top: 8,
    left: 9,
    width: 18,
    height: 7,
    borderRadius: 999,
    backgroundColor: "rgba(255,255,255,0.055)",
    transform: [{ rotate: "-22deg" }]
  },
});
