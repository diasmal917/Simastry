import { Asset } from "expo-asset";
import { BlurView } from "expo-blur";
import { Image } from "expo-image";
import { LinearGradient } from "expo-linear-gradient";
import { useEffect, useRef, useState } from "react";
import { Modal, Pressable, ScrollView, StyleSheet, Text, TextInput, useWindowDimensions, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { BottomNavigation } from "@/components/bottom-navigation";
import { buildChatFoundation, mockUserChart } from "@/data/chat-foundation";
import type { ChatTurn } from "@/data/chat-foundation";
import { buildLocalChatResponse, chatReleaseConfig, getQuotaStatus } from "@/data/chat-engine";
import type { AccessTier } from "@/data/chat-engine";
import { companions } from "@/data/companions";
import type { Companion } from "@/data/companions";
import { getSignMetadata } from "@/data/astrology";

type ChatThreadsByCompanion = Record<string, ChatTurn[]>;
type ChatMemoryByCompanion = Record<string, string[]>;
type ChatUsageState = {
  day: string;
  tier: AccessTier;
  count: number;
};

const chatStorageKey = "simastry-chat-threads-v2";
const chatMemoryStorageKey = "simastry-chat-memory-v1";
const chatUsageStorageKey = "simastry-chat-usage-v1";

function getTodayKey() {
  return new Date().toISOString().slice(0, 10);
}

function isAccessTier(value: string | null | undefined): value is AccessTier {
  return value === "free" || value === "plus" || value === "pro";
}

function getInitialAccessTier() {
  if (typeof window === "undefined") return chatReleaseConfig.defaultTier;

  const tier = new URLSearchParams(window.location.search).get("tier")?.toLowerCase();
  return isAccessTier(tier) ? tier : chatReleaseConfig.defaultTier;
}

function isStoredChatTurn(value: unknown): value is ChatTurn {
  if (!value || typeof value !== "object") return false;
  const turn = value as Partial<ChatTurn>;
  return typeof turn.id === "string"
    && (turn.author === "companion" || turn.author === "user")
    && typeof turn.body === "string"
    && typeof turn.timestamp === "string";
}

function loadStoredChatThreads(): ChatThreadsByCompanion {
  if (typeof window === "undefined" || !window.localStorage) return {};

  try {
    const raw = window.localStorage.getItem(chatStorageKey);
    if (!raw) return {};
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return {};

    return Object.fromEntries(
      Object.entries(parsed)
        .filter(([, value]) => Array.isArray(value))
        .map(([key, value]) => [key, (value as unknown[]).filter(isStoredChatTurn).slice(-24)])
        .filter(([, value]) => (value as ChatTurn[]).length > 0)
    );
  } catch {
    return {};
  }
}

function saveStoredChatThreads(threads: ChatThreadsByCompanion) {
  if (typeof window === "undefined" || !window.localStorage) return;

  try {
    window.localStorage.setItem(chatStorageKey, JSON.stringify(threads));
  } catch {
    // Local persistence is a prototype convenience. Chat still works if storage is unavailable.
  }
}

function loadStoredChatMemory(): ChatMemoryByCompanion {
  if (typeof window === "undefined" || !window.localStorage) return {};

  try {
    const raw = window.localStorage.getItem(chatMemoryStorageKey);
    if (!raw) return {};
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return {};

    return Object.fromEntries(
      Object.entries(parsed)
        .filter(([, value]) => Array.isArray(value))
        .map(([key, value]) => [key, (value as unknown[]).filter((item): item is string => typeof item === "string").slice(0, 5)])
        .filter(([, value]) => (value as string[]).length > 0)
    );
  } catch {
    return {};
  }
}

function saveStoredChatMemory(memory: ChatMemoryByCompanion) {
  if (typeof window === "undefined" || !window.localStorage) return;

  try {
    window.localStorage.setItem(chatMemoryStorageKey, JSON.stringify(memory));
  } catch {
    // Memory is a prototype convenience. The engine still uses chart logic if storage is unavailable.
  }
}

function loadStoredChatUsage(): ChatUsageState {
  const today = getTodayKey();
  const tierFromRoute = getInitialAccessTier();
  if (typeof window === "undefined" || !window.localStorage) return { day: today, tier: tierFromRoute, count: 0 };

  try {
    const raw = window.localStorage.getItem(chatUsageStorageKey);
    if (!raw) return { day: today, tier: tierFromRoute, count: 0 };
    const parsed = JSON.parse(raw) as Partial<ChatUsageState>;
    const storedTier = isAccessTier(parsed.tier) ? parsed.tier : tierFromRoute;
    const tier = tierFromRoute !== chatReleaseConfig.defaultTier ? tierFromRoute : storedTier;
    const count = parsed.day === today && typeof parsed.count === "number" ? Math.max(parsed.count, 0) : 0;
    return { day: today, tier, count };
  } catch {
    return { day: today, tier: tierFromRoute, count: 0 };
  }
}

function saveStoredChatUsage(usage: ChatUsageState) {
  if (typeof window === "undefined" || !window.localStorage) return;

  try {
    window.localStorage.setItem(chatUsageStorageKey, JSON.stringify(usage));
  } catch {
    // Usage limits need a backend for production enforcement. Local storage keeps the prototype honest.
  }
}

function getInitialCompanionIndex() {
  if (typeof window === "undefined") return 0;

  const slide = new URLSearchParams(window.location.search).get("slide")?.toLowerCase();
  const variant = new URLSearchParams(window.location.search).get("variant")?.toLowerCase();
  const match = companions.findIndex((companion) => companion.id === slide);
  if (match >= 0) return match;

  const signMatch = companions.findIndex((companion) => {
    const isSlideMatch = companion.sign.toLowerCase() === slide;
    const isVariantMatch = !variant || companion.gender === variant;
    return isSlideMatch && isVariantMatch;
  });
  return signMatch >= 0 ? signMatch : 0;
}

function getInitialViewMode(): "deck" | "astrogram" | "chat" {
  if (typeof window === "undefined") return "deck";

  const view = new URLSearchParams(window.location.search).get("view")?.toLowerCase();
  if (view === "astrogram" || view === "chat") return view;
  return "deck";
}

function getInitialTab(viewMode: "deck" | "astrogram" | "chat") {
  if (typeof window !== "undefined") {
    const tab = new URLSearchParams(window.location.search).get("tab")?.toLowerCase();
    if (tab === "home" || tab === "predict" || tab === "companions" || tab === "messages" || tab === "about") return tab;
  }

  if (viewMode === "chat") return "messages";
  return viewMode === "astrogram" ? "home" : "companions";
}

function MessageGlyph({ color = "#fff8ef" }: { color?: string }) {
  return (
    <View style={[styles.messageGlyph, { borderColor: color }]}>
      <View style={[styles.messageGlyphDot, { backgroundColor: color }]} />
      <View style={[styles.messageGlyphDot, { backgroundColor: color }]} />
      <View style={[styles.messageGlyphDot, { backgroundColor: color }]} />
      <View style={[styles.messageGlyphTail, { borderColor: color }]} />
    </View>
  );
}

function ChatBubbleIcon({ color = "#fff" }: { color?: string }) {
  return (
    <View style={styles.chatBubbleIcon}>
      <View style={[styles.chatBubbleIconBody, { backgroundColor: color }]} />
      <View style={[styles.chatBubbleIconTail, { backgroundColor: color }]} />
    </View>
  );
}

function MessagesAppIcon() {
  return (
    <View style={styles.messagesAppIcon}>
      <LinearGradient
        colors={["rgba(255,251,237,0.9)", "rgba(207,183,125,0.68)", "rgba(113,91,54,0.58)"]}
        locations={[0, 0.52, 1]}
        style={StyleSheet.absoluteFill}
      />
      <View style={styles.messagesAppIconSheen} />
      <ChatBubbleIcon color="#fffdf6" />
    </View>
  );
}

function CompanionPortrait({ companion }: { companion: Companion }) {
  const source = Asset.fromModule(companion.image);
  return (
    <Image
      source={{ uri: source.uri }}
      contentFit="cover"
      contentPosition={companion.cardPosition}
      style={styles.cardPortraitImage}
    />
  );
}

const personaCities: Record<string, string> = {
  "aries-cassian": "Miami",
  "aries-amara": "Austin",
  "taurus-ada": "Copenhagen",
  "taurus-theo": "Portland",
  "gemini-arden": "New York",
  "gemini-rina": "London",
  "cancer-mila": "Seattle",
  "cancer-noel": "Vancouver",
  "leo-leona": "Los Angeles",
  "leo-dante": "Mexico City",
  "virgo-mara": "Chicago",
  "virgo-jonah": "Boston",
  "libra-isolde": "Paris",
  "libra-mateo": "Madrid",
  "scorpio-elias": "Berlin",
  "scorpio-vera": "Prague",
  "sagittarius-nadia": "Los Angeles",
  "sagittarius-rafi": "Lisbon",
  "capricorn-silas": "San Francisco",
  "capricorn-naomi": "Toronto",
  "aquarius-yarrow": "Amsterdam",
  "aquarius-imani": "Atlanta",
  "pisces-zev": "New Orleans",
  "pisces-liora": "Tel Aviv"
};

function getPersonaMeta(companion: Companion) {
  return `${companion.identity.ageRange} • ${companion.sign} • ${personaCities[companion.id] ?? "Los Angeles"}`;
}

function CompanionVariantSwitch({
  active,
  onSelect
}: {
  active: Companion;
  onSelect: (companion: Companion) => void;
}) {
  const variants = companions.filter((companion) => companion.pairId === active.pairId);

  if (variants.length < 2) return null;

  return (
    <BlurView intensity={48} tint="dark" style={styles.variantSwitch}>
      <LinearGradient
        colors={["rgba(255,255,255,0.18)", "rgba(255,255,255,0.055)", "rgba(0,0,0,0.2)"]}
        locations={[0, 0.42, 1]}
        style={StyleSheet.absoluteFill}
      />
      {variants.map((variant) => {
        const isActive = variant.id === active.id;
        return (
          <Pressable
            key={variant.id}
            onPress={() => onSelect(variant)}
            style={[styles.variantPill, isActive && styles.variantPillActive]}
          >
            <Text style={[styles.variantText, isActive && styles.variantTextActive]}>
              {variant.gender === "female" ? "Female" : "Male"}
            </Text>
          </Pressable>
        );
      })}
    </BlurView>
  );
}

function AstrogramProfile({
  companion,
  onBack,
  onMessage,
  onSelectVariant
}: {
  companion: Companion;
  onBack: () => void;
  onMessage: () => void;
  onSelectVariant: (companion: Companion) => void;
}) {
  const posts = companion.astrogramPosts;
  const photos = posts.map((post) => post.image).filter((photo): photo is number => Boolean(photo));
  const [selectedPost, setSelectedPost] = useState<number | null>(null);
  const [commentDraft, setCommentDraft] = useState("");
  const [commentsByPost, setCommentsByPost] = useState<Record<string, string[]>>({});
  const activePostKey = selectedPost === null ? "" : `${companion.id}-${selectedPost}`;
  const selectedPostRecord = selectedPost === null ? null : posts[selectedPost];
  const activeComments = activePostKey ? commentsByPost[activePostKey] ?? selectedPostRecord?.comments ?? [] : [];
  const selectedPhoto = selectedPostRecord?.image;

  const submitComment = () => {
    const body = commentDraft.trim();
    if (!body || selectedPost === null) return;

    setCommentsByPost((current) => ({
      ...current,
      [activePostKey]: [...(current[activePostKey] ?? []), body]
    }));
    setCommentDraft("");
  };

  return (
    <View style={styles.astrogram}>
      <View style={styles.astrogramTop}>
        <Pressable onPress={onBack} style={styles.astroBack}>
          <Text style={styles.astroBackText}>‹</Text>
        </Pressable>
        <View style={styles.astroTitleLockup}>
          <Text style={styles.astroTitle}>{companion.displayName}</Text>
          <Text style={styles.astroSubtitle}>{companion.sign} companion</Text>
        </View>
        <Pressable onPress={onMessage} style={styles.astroMessage}>
          <ChatBubbleIcon color="#fff" />
        </Pressable>
      </View>

      <View style={styles.astroProfilePanel}>
        <CompanionVariantSwitch active={companion} onSelect={onSelectVariant} />
        <View style={styles.astroHero}>
          {companion.portraitStatus === "approved" ? (
            <Image source={companion.image} contentFit="cover" contentPosition={companion.cardPosition} style={styles.astroAvatar} />
          ) : (
            <View style={[styles.astroAvatar, styles.astroAvatarPlaceholder]}>
              <Text style={styles.astroAvatarGlyph}>{companion.glyph.replace("︎", "️")}</Text>
            </View>
          )}
          <View style={styles.astroStatsRow}>
            <View style={styles.astroStats}>
              <Text style={styles.astroNumber}>{posts.length}</Text>
              <Text style={styles.astroLabel}>posts</Text>
            </View>
            <View style={styles.astroDivider} />
            <View style={styles.astroStats}>
              <Text style={styles.astroNumber}>{companion.sign}</Text>
              <Text style={styles.astroLabel}>sun sign</Text>
            </View>
          </View>
        </View>

        <Text style={styles.astroBio}>{companion.bio}</Text>
        {companion.portraitStatus !== "approved" ? (
          <Text style={styles.assetNote}>Portrait in review. Identity, voice, notifications, and Astrogram captions are ready for generation.</Text>
        ) : null}

        <View style={styles.astroTagRow}>
          {companion.tags.map((tag) => (
            <Text key={`astro-${tag}`} style={styles.astroTag}>{tag}</Text>
          ))}
        </View>
      </View>

      <View style={styles.photoGrid}>
        {posts.map((post, index) => (
          <Pressable key={`${companion.id}-${index}`} onPress={() => setSelectedPost(index)} style={styles.photoTile}>
            {post.image ? (
              <Image
                source={post.image}
                contentFit="cover"
                contentPosition={{ left: "50%", top: "18%" }}
                style={StyleSheet.absoluteFill}
              />
            ) : (
              <View style={styles.photoPlaceholder}>
                <Text style={styles.photoPlaceholderLabel}>{post.context}</Text>
              </View>
            )}
            <LinearGradient
              colors={["rgba(255,255,255,0.05)", "rgba(0,0,0,0.2)"]}
              style={StyleSheet.absoluteFill}
            />
          </Pressable>
        ))}
      </View>

      <Modal visible={selectedPost !== null} transparent animationType="fade" onRequestClose={() => setSelectedPost(null)}>
        <View style={styles.postModal}>
          <Pressable style={StyleSheet.absoluteFill} onPress={() => setSelectedPost(null)} />
          <View style={styles.postSheet}>
            <View style={styles.postHeader}>
              <View>
                <Text style={styles.postName}>{companion.displayName}</Text>
                <Text style={styles.postMeta}>Astrogram post</Text>
              </View>
              <Pressable onPress={() => setSelectedPost(null)} style={styles.postClose}>
                <Text style={styles.postCloseText}>×</Text>
              </Pressable>
            </View>

            {selectedPhoto ? (
              <Image source={selectedPhoto} contentFit="contain" contentPosition="center" style={styles.postImage} />
            ) : selectedPostRecord ? (
              <View style={[styles.postImage, styles.postImagePlaceholder]}>
                <Text style={styles.photoPlaceholderLabel}>{selectedPostRecord.context}</Text>
              </View>
            ) : null}

            <View style={styles.postActions}>
              <Text style={styles.postAction}>♡</Text>
              <Text style={styles.postAction}>⌁</Text>
              <Text style={styles.postAction}>↗</Text>
            </View>

            <ScrollView style={styles.commentList} showsVerticalScrollIndicator={false}>
              <Text style={styles.postCaption}>
                <Text style={styles.commentAuthor}>{companion.displayName}</Text> {selectedPostRecord?.caption ?? companion.opener}
              </Text>
              {activeComments.length === 0 ? (
                <Text style={styles.emptyComments}>No comments yet.</Text>
              ) : (
                activeComments.map((comment, index) => (
                  <Text key={`${activePostKey}-${index}`} style={styles.commentText}>
                    <Text style={styles.commentAuthor}>You</Text> {comment}
                  </Text>
                ))
              )}
            </ScrollView>

            <View style={styles.commentComposer}>
              <TextInput
                value={commentDraft}
                onChangeText={setCommentDraft}
                onSubmitEditing={submitComment}
                placeholder="Add a comment..."
                placeholderTextColor="rgba(255,248,239,0.45)"
                style={styles.commentInput}
                returnKeyType="send"
              />
              <Pressable onPress={submitComment} style={styles.commentSend}>
                <Text style={styles.commentSendText}>Post</Text>
              </Pressable>
            </View>
          </View>
        </View>
      </Modal>
    </View>
  );
}

function FeaturePanel({ title, eyebrow, body }: { title: string; eyebrow: string; body: string }) {
  return (
    <View style={styles.featurePanel}>
      <LinearGradient
        colors={["rgba(255,255,255,0.14)", "rgba(255,255,255,0.04)", "rgba(235,190,104,0.1)"]}
        style={StyleSheet.absoluteFill}
      />
      <Text style={styles.featureEyebrow}>{eyebrow}</Text>
      <Text style={styles.featureTitle}>{title}</Text>
      <Text style={styles.featureBody}>{body}</Text>
    </View>
  );
}

type PredictionMode = "Warm" | "Direct" | "Wait";

function buildPrediction(companion: Companion, message: string, mode: PredictionMode) {
  const companionMeta = getSignMetadata(companion.sign);
  const moonMeta = getSignMetadata(mockUserChart.moon);
  const risingMeta = getSignMetadata(mockUserChart.rising);
  const modeAdvice: Record<PredictionMode, string> = {
    Warm: "Keep the door open, but make them cross the distance.",
    Direct: "Name the pattern without turning it into a trial.",
    Wait: "Do not feed the silence. Let their next move carry information."
  };
  const replyByMode: Record<PredictionMode, string> = {
    Warm: "I liked hearing from you. What changed the pace?",
    Direct: "I am open to this, but I need the energy to stay consistent.",
    Wait: "No reply yet. If they come back, answer the behavior, not the anxiety."
  };

  return {
    likelyRead: `${companion.displayName}'s ${companion.sign} lens flags the risk: ${companionMeta.relationshipShadow}.`,
    predictedResponse: mode === "Wait"
      ? "Waiting makes their next move carry the evidence."
      : "A good response gets warmer and more specific. A weak response stays vague.",
    astrology: `Your ${mockUserChart.moon} Moon ${moonMeta.emotionalPattern}. Your ${mockUserChart.rising} Rising wants the tone to stay ${risingMeta.communicationStyle}.`,
    action: modeAdvice[mode],
    reply: replyByMode[mode]
  };
}

function PredictPanel({ companion, onMessage }: { companion: Companion; onMessage: () => void }) {
  const [message, setMessage] = useState(mockUserChart.sampleMessage);
  const [mode, setMode] = useState<PredictionMode>("Warm");
  const prediction = buildPrediction(companion, message, mode);
  const modes: PredictionMode[] = ["Warm", "Direct", "Wait"];

  return (
    <View style={styles.toolPanel}>
      <LinearGradient
        colors={["rgba(255,255,255,0.12)", "rgba(255,255,255,0.04)", "rgba(240,201,121,0.08)"]}
        style={StyleSheet.absoluteFill}
      />
      <View style={styles.toolHeader}>
        <Text style={styles.featureEyebrow}>PREDICT</Text>
        <Text style={styles.toolTitle}>Predict their reply before you answer.</Text>
        <Text style={styles.toolBody}>Paste the text or describe the silence. Simastry reads tone, timing, and the safest next move through your chart and {companion.displayName}'s {companion.sign} lens.</Text>
      </View>

      <View style={styles.predictCompanionRow}>
        <Image source={companion.image} contentFit="cover" contentPosition={companion.cardPosition} style={styles.predictAvatar} />
        <View style={styles.predictCompanionCopy}>
          <Text style={styles.predictName}>{companion.displayName}</Text>
          <Text style={styles.predictMeta}>{companion.sign} • {getSignMetadata(companion.sign).rulingPlanet} lens</Text>
        </View>
      </View>

      <View style={styles.predictInputShell}>
        <Text style={styles.inputLabel}>Message or situation</Text>
        <TextInput
          value={message}
          onChangeText={setMessage}
          multiline
          textAlignVertical="top"
          placeholder="Paste the message or describe what happened..."
          placeholderTextColor="rgba(255,248,239,0.42)"
          style={styles.predictInput}
        />
      </View>

      <View style={styles.modeRow}>
        {modes.map((item) => (
          <Pressable key={item} onPress={() => setMode(item)} style={[styles.modeChip, mode === item && styles.modeChipActive]}>
            <Text style={[styles.modeChipText, mode === item && styles.modeChipTextActive]}>{item}</Text>
          </Pressable>
        ))}
      </View>

      <View style={styles.predictionCard}>
        <Text style={styles.predictionLabel}>Likely read</Text>
        <Text style={styles.predictionText}>{prediction.likelyRead}</Text>
        <Text style={styles.predictionLabel}>Best move</Text>
        <Text style={styles.predictionText}>{prediction.action} {prediction.predictedResponse}</Text>
        <View style={styles.replyCard}>
          <Text style={styles.replyLabel}>Reply to send</Text>
          <Text style={styles.replyText}>{prediction.reply}</Text>
        </View>
        <Text style={styles.predictionWhy}>{prediction.astrology}</Text>
      </View>

      <Pressable onPress={onMessage} style={styles.primaryAction}>
        <Text style={styles.primaryActionText}>Message {companion.displayName}</Text>
        <MessageGlyph color="#111" />
      </Pressable>
    </View>
  );
}

function AboutMePanel({ companion, onMessage }: { companion: Companion; onMessage: () => void }) {
  const foundation = buildChatFoundation(companion);
  const sunMeta = getSignMetadata(mockUserChart.sun);
  const moonMeta = getSignMetadata(mockUserChart.moon);
  const risingMeta = getSignMetadata(mockUserChart.rising);

  return (
    <View style={styles.toolPanel}>
      <LinearGradient
        colors={["rgba(255,255,255,0.12)", "rgba(255,255,255,0.04)", "rgba(240,201,121,0.08)"]}
        style={StyleSheet.absoluteFill}
      />
      <View style={styles.toolHeader}>
        <Text style={styles.featureEyebrow}>ABOUT ME</Text>
        <Text style={styles.toolTitle}>Your reading profile.</Text>
        <Text style={styles.toolBody}>This is the local prototype profile Simastry uses to make guidance feel specific. It is chart-based and privacy-safe, not a public dating profile.</Text>
      </View>

      <View style={styles.chartCardGrid}>
        <View style={styles.chartCard}>
          <Text style={styles.chartCardLabel}>Sun</Text>
          <Text style={styles.chartCardTitle}>{mockUserChart.sun}</Text>
          <Text style={styles.chartCardBody}>{sunMeta.coreDrive}</Text>
        </View>
        <View style={styles.chartCard}>
          <Text style={styles.chartCardLabel}>Moon</Text>
          <Text style={styles.chartCardTitle}>{mockUserChart.moon}</Text>
          <Text style={styles.chartCardBody}>{moonMeta.emotionalPattern}</Text>
        </View>
        <View style={styles.chartCard}>
          <Text style={styles.chartCardLabel}>Rising</Text>
          <Text style={styles.chartCardTitle}>{mockUserChart.rising}</Text>
          <Text style={styles.chartCardBody}>{risingMeta.communicationStyle}</Text>
        </View>
      </View>

      <View style={styles.profileSection}>
        <Text style={styles.profileSectionTitle}>Companion calibration</Text>
        <Text style={styles.profileSectionBody}>{companion.displayName} reads you through {companion.sign}: {getSignMetadata(companion.sign).communicationStyle}. This keeps each companion distinct while grounding advice in the same user chart.</Text>
      </View>

      <View style={styles.profileSection}>
        <Text style={styles.profileSectionTitle}>Memory signals</Text>
        {foundation.memorySignals.map((signal) => (
          <Text key={`about-${signal}`} style={styles.profileMemory}>• {signal}</Text>
        ))}
      </View>

      <View style={styles.profileSection}>
        <Text style={styles.profileSectionTitle}>Private notifications</Text>
        {foundation.notificationExamples.slice(0, 2).map((copy) => (
          <Text key={`notification-${copy}`} style={styles.profileMemory}>• {copy}</Text>
        ))}
      </View>

      <Pressable onPress={onMessage} style={styles.primaryAction}>
        <Text style={styles.primaryActionText}>Start a reading</Text>
        <MessageGlyph color="#111" />
      </Pressable>
    </View>
  );
}

function ChatPreview({
  companion,
  messages,
  memorySignals,
  chatUsage,
  onMessagesChange,
  onUsageChange,
  onMemoryChange,
  onBack
}: {
  companion: Companion;
  messages: ChatTurn[];
  memorySignals: string[];
  chatUsage: ChatUsageState;
  onMessagesChange: (updater: (current: ChatTurn[]) => ChatTurn[]) => void;
  onUsageChange: (updater: (current: ChatUsageState) => ChatUsageState) => void;
  onMemoryChange: (signals: string[]) => void;
  onBack: () => void;
}) {
  const foundation = buildChatFoundation(companion);
  const [draft, setDraft] = useState("");
  const [isTyping, setIsTyping] = useState(false);
  const typingTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const quota = getQuotaStatus(chatUsage.tier, chatUsage.count);
  const quotaLabel = quota.limit === null
    ? `${chatUsage.tier.toUpperCase()} unlimited`
    : `${chatUsage.tier.toUpperCase()} ${quota.used}/${quota.limit} today`;
  const memoryForDisplay = memorySignals.length > 0 ? memorySignals : foundation.memorySignals;

  useEffect(() => {
    setDraft("");
    setIsTyping(false);
    if (typingTimer.current) {
      clearTimeout(typingTimer.current);
      typingTimer.current = null;
    }
  }, [companion.id]);

  useEffect(() => () => {
    if (typingTimer.current) clearTimeout(typingTimer.current);
  }, []);

  const sendMessage = (body = draft) => {
    const cleanBody = body.trim();
    if (!cleanBody || isTyping) return;

    const timestamp = "now";
    const result = buildLocalChatResponse({
      companion,
      userMessage: cleanBody,
      existingMessages: messages,
      profile: mockUserChart,
      tier: chatUsage.tier,
      usageCount: chatUsage.count
    });

    if (result.shouldIncrementUsage) {
      onUsageChange((current) => ({ ...current, day: getTodayKey(), count: current.count + 1 }));
    }

    onMemoryChange(result.memorySignals);

    if (result.shouldAppendUserMessage) {
      const userTurn: ChatTurn = {
        id: `${companion.id}-user-${Date.now()}`,
        author: "user",
        body: cleanBody,
        timestamp,
        status: "seen"
      };
      onMessagesChange((current) => [...current, userTurn].slice(-24));
    }

    setDraft("");
    setIsTyping(true);

    typingTimer.current = setTimeout(() => {
      const companionTurns: ChatTurn[] = result.replyParts.map((replyPart, index) => ({
        id: `${companion.id}-${result.kind}-${Date.now()}-${index}`,
        author: "companion",
        body: replyPart,
        timestamp
      }));

      onMessagesChange((current) => [...current, ...companionTurns].slice(-24));
      setIsTyping(false);
      typingTimer.current = null;
    }, 680);
  };
  const lastMessage = messages[messages.length - 1];

  return (
    <View style={styles.chatPanel}>
      <View style={styles.dmHeader}>
        <Pressable onPress={onBack} style={styles.dmBack}>
          <Text style={styles.dmBackText}>‹</Text>
        </Pressable>
        <Image source={companion.image} contentFit="cover" contentPosition={companion.cardPosition} style={styles.dmAvatar} />
        <View style={styles.dmTitleLockup}>
          <Text style={styles.dmName}>{companion.displayName}</Text>
          <Text style={styles.dmStatus}>{companion.sign} lens • reading now</Text>
        </View>
        <View style={styles.dmCallButton}>
          <Text style={styles.dmCallGlyph}>✦</Text>
        </View>
      </View>

      <View style={styles.dmProfileCard}>
        <Text style={styles.dmProfileLabel}>Reading context</Text>
        <Text style={styles.dmProfileBio}>{foundation.connectionCue}</Text>
        <View style={styles.chartPillRow}>
          <Text style={styles.chartPill}>Sun {mockUserChart.sun}</Text>
          <Text style={styles.chartPill}>Moon {mockUserChart.moon}</Text>
          <Text style={styles.chartPill}>Rising {mockUserChart.rising}</Text>
        </View>
        <View style={styles.releaseGateRow}>
          <Text style={styles.releaseGatePill}>{quotaLabel}</Text>
          <Text style={styles.releaseGateCopy}>Moderated before AI • private previews</Text>
        </View>
      </View>

      <View style={styles.whyPanel}>
        <Text style={styles.whyEyebrow}>Why this reading</Text>
        {foundation.whyThisReading.map((item) => (
          <View key={item.label} style={styles.whyRow}>
            <Text style={styles.whyLabel}>{item.label}</Text>
            <Text style={styles.whyBody}>{item.body}</Text>
          </View>
        ))}
      </View>

      <View style={styles.memoryPanel}>
        <Text style={styles.memoryEyebrow}>Memory for this reading</Text>
        {memoryForDisplay.map((signal) => (
          <Text key={signal} style={styles.memorySignal}>• {signal}</Text>
        ))}
      </View>

      <View style={styles.dmThread}>
        {messages.map((message) => {
          const isUser = message.author === "user";
          return (
            <View key={message.id} style={[styles.dmMessageRow, isUser && styles.dmMessageRowOutgoing]}>
              {!isUser ? (
                <Image source={companion.image} contentFit="cover" contentPosition={companion.cardPosition} style={styles.dmMessageAvatar} />
              ) : null}
              <View style={[styles.dmBubble, isUser ? styles.dmBubbleOutgoing : styles.dmBubbleIncoming]}>
                <Text style={[styles.dmBubbleText, isUser && styles.dmBubbleTextOutgoing]}>{message.body}</Text>
              </View>
            </View>
          );
        })}
        {isTyping ? (
          <View style={styles.dmMessageRow}>
            <Image source={companion.image} contentFit="cover" contentPosition={companion.cardPosition} style={styles.dmMessageAvatar} />
            <View style={[styles.dmBubble, styles.dmBubbleIncoming, styles.typingBubble]}>
              <Text style={styles.typingDot}>•</Text>
              <Text style={styles.typingDot}>•</Text>
              <Text style={styles.typingDot}>•</Text>
            </View>
          </View>
        ) : null}
        {lastMessage?.author === "user" ? (
          <Text style={styles.dmSeen}>Seen by {companion.displayName}</Text>
        ) : (
          <Text style={styles.dmSeen}>Personalized by your Sun, Moon, and Rising</Text>
        )}
      </View>

      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.quickPromptRow}>
        {foundation.quickPrompts.map((prompt) => (
          <Pressable key={prompt} onPress={() => sendMessage(prompt)} style={styles.quickPrompt}>
            <Text style={styles.quickPromptText}>{prompt}</Text>
          </Pressable>
        ))}
      </ScrollView>

      <View style={styles.chatComposer}>
        <TextInput
          value={draft}
          onChangeText={setDraft}
          onSubmitEditing={() => sendMessage()}
          placeholder={`Message ${companion.displayName}`}
          placeholderTextColor="rgba(16,12,8,0.48)"
          style={styles.chatInput}
          returnKeyType="send"
        />
        <Pressable onPress={() => sendMessage()} style={styles.dmSendButton}>
          <MessageGlyph color="#111" />
        </Pressable>
      </View>
    </View>
  );
}

export default function HomeScreen() {
  const [activeIndex, setActiveIndex] = useState(getInitialCompanionIndex);
  const [viewMode, setViewMode] = useState<"deck" | "astrogram" | "chat">(getInitialViewMode);
  const [activeTab, setActiveTab] = useState(() => getInitialTab(getInitialViewMode()));
  const [chatThreadsByCompanion, setChatThreadsByCompanion] = useState<ChatThreadsByCompanion>(loadStoredChatThreads);
  const [chatMemoryByCompanion, setChatMemoryByCompanion] = useState<ChatMemoryByCompanion>(loadStoredChatMemory);
  const [chatUsage, setChatUsage] = useState<ChatUsageState>(loadStoredChatUsage);
  const contentScrollRef = useRef<ScrollView>(null);
  const insets = useSafeAreaInsets();
  const { width, height } = useWindowDimensions();
  const active = companions[activeIndex];
  const next = companions[(activeIndex + 1) % companions.length];
  const previous = companions[(activeIndex + companions.length - 1) % companions.length];
  const isDesktopPreview = width > 520;
  const viewportHeight = Math.max(height, 760);
  const frameHeight = isDesktopPreview ? Math.min(viewportHeight - 32, 932) : viewportHeight;
  const layoutWidth = isDesktopPreview ? 430 : width;
  const visualHeight = frameHeight;
  const isCompact = layoutWidth < 520;
  const activeChatMessages = chatThreadsByCompanion[active.id] ?? buildChatFoundation(active).starterThread;
  const activeMemorySignals = chatMemoryByCompanion[active.id] ?? buildChatFoundation(active).memorySignals;
  const contentTop = viewMode === "chat"
    ? (isDesktopPreview ? 92 : insets.top + 90)
    : (isDesktopPreview ? 108 : insets.top + 104);

  useEffect(() => {
    saveStoredChatThreads(chatThreadsByCompanion);
  }, [chatThreadsByCompanion]);

  useEffect(() => {
    saveStoredChatMemory(chatMemoryByCompanion);
  }, [chatMemoryByCompanion]);

  useEffect(() => {
    saveStoredChatUsage(chatUsage);
  }, [chatUsage]);

  useEffect(() => {
    if (viewMode !== "chat") return;
    const scrollTimer = setTimeout(() => {
      contentScrollRef.current?.scrollToEnd({ animated: true });
    }, 90);

    return () => clearTimeout(scrollTimer);
  }, [active.id, activeChatMessages.length, viewMode]);

  const goNext = () => setActiveIndex((value) => (value + 1) % companions.length);
  const goBack = () => setActiveIndex((value) => (value + companions.length - 1) % companions.length);
  const selectCompanion = (companion: Companion) => {
    const nextIndex = companions.findIndex((item) => item.id === companion.id);
    if (nextIndex >= 0) setActiveIndex(nextIndex);
  };
  const openAstrogram = () => {
    setActiveTab("home");
    setViewMode("astrogram");
  };
  const openChat = () => {
    setActiveTab("messages");
    setViewMode("chat");
  };
  const updateActiveChatMessages = (updater: (current: ChatTurn[]) => ChatTurn[]) => {
    setChatThreadsByCompanion((current) => {
      const seed = current[active.id] ?? buildChatFoundation(active).starterThread;
      return {
        ...current,
        [active.id]: updater(seed)
      };
    });
  };
  const updateActiveMemorySignals = (signals: string[]) => {
    setChatMemoryByCompanion((current) => ({
      ...current,
      [active.id]: signals
    }));
  };
  const handleTabChange = (tab: string) => {
    setActiveTab(tab);
    if (tab === "home") setViewMode("astrogram");
    if (tab === "companions") setViewMode("deck");
    if (tab === "messages") setViewMode("chat");
    if (tab === "predict" || tab === "about") setViewMode("deck");
  };

  return (
    <View style={[styles.previewHost, !isDesktopPreview && styles.previewHostMobile]}>
      <View style={[styles.screen, isDesktopPreview && styles.phoneFrame, isDesktopPreview && { height: frameHeight }, !isDesktopPreview && styles.mobileFrame]}>
      <LinearGradient colors={["#080605", active.shadow, "#050404"]} locations={[0, 0.48, 1]} style={StyleSheet.absoluteFill} />
      {active.portraitStatus === "approved" ? (
        <Image
          source={active.image}
          contentFit="cover"
          contentPosition={active.backgroundPosition}
          transition={420}
          style={{
            position: "absolute",
            left: 0,
            right: 0,
            top: 0,
            height: visualHeight * 0.64,
            opacity: 0.18
          }}
        />
      ) : null}
      <LinearGradient
        colors={["rgba(6,4,3,0.38)", "rgba(8,6,5,0.72)", "rgba(5,4,4,0.98)"]}
        locations={[0, 0.48, 1]}
        style={StyleSheet.absoluteFill}
      />

      {viewMode !== "chat" ? (
        <View style={[styles.brandHeader, { top: isDesktopPreview ? 42 : insets.top + 22 }]}>
          <Text selectable style={styles.brandText}>Simastry</Text>
        </View>
      ) : null}

      <ScrollView
        ref={contentScrollRef}
        contentInsetAdjustmentBehavior="automatic"
        showsVerticalScrollIndicator={false}
        contentContainerStyle={[
          styles.content,
          {
            minHeight: visualHeight,
            paddingTop: contentTop,
            paddingBottom: insets.bottom + (viewMode === "chat" ? 56 : isCompact ? 174 : 146)
          }
        ]}
      >
        {activeTab === "predict" ? (
          <PredictPanel companion={active} onMessage={openChat} />
        ) : activeTab === "about" ? (
          <AboutMePanel companion={active} onMessage={openChat} />
        ) : viewMode === "astrogram" ? (
          <AstrogramProfile companion={active} onBack={() => setViewMode("deck")} onMessage={openChat} onSelectVariant={selectCompanion} />
        ) : viewMode === "chat" ? (
          <ChatPreview
            companion={active}
            messages={activeChatMessages}
            memorySignals={activeMemorySignals}
            chatUsage={chatUsage}
            onMessagesChange={updateActiveChatMessages}
            onUsageChange={setChatUsage}
            onMemoryChange={updateActiveMemorySignals}
            onBack={() => setViewMode("astrogram")}
          />
        ) : (
        <View style={[styles.cardStage, { height: Math.min(visualHeight * 0.7, 624) }]}>
          <Pressable onPress={goBack} style={[styles.peekCard, styles.peekLeft]}>
            {previous.portraitStatus === "approved" ? (
              <Image source={previous.image} contentFit="cover" contentPosition={previous.cardPosition} style={StyleSheet.absoluteFill} />
            ) : (
              <View style={styles.peekPlaceholder} />
            )}
          </Pressable>
          <Pressable onPress={goNext} style={[styles.peekCard, styles.peekRight]}>
            {next.portraitStatus === "approved" ? (
              <Image source={next.image} contentFit="cover" contentPosition={next.cardPosition} style={StyleSheet.absoluteFill} />
            ) : (
              <View style={styles.peekPlaceholder} />
            )}
          </Pressable>

          <Pressable onPress={openAstrogram} style={[styles.profileCard, { height: Math.min(visualHeight * 0.68, 596) }]}>
            {active.portraitStatus === "approved" ? (
              <CompanionPortrait companion={active} />
            ) : (
              <View style={styles.pendingCardBackdrop}>
                <Text style={styles.pendingGlyph}>{active.glyph.replace("︎", "️")}</Text>
              </View>
            )}
            <LinearGradient
              colors={active.portraitStatus === "approved" ? ["rgba(255,255,255,0.06)", "rgba(0,0,0,0)", "rgba(0,0,0,0.2)", "rgba(0,0,0,0.9)"] : ["rgba(255,255,255,0.06)", "rgba(0,0,0,0.38)", "rgba(0,0,0,0.94)"]}
              locations={active.portraitStatus === "approved" ? [0, 0.28, 0.58, 1] : [0, 0.32, 1]}
              style={StyleSheet.absoluteFill}
            />
            <LinearGradient
              colors={["rgba(255,255,255,0.48)", "rgba(255,255,255,0.1)", "rgba(255,255,255,0)"]}
              start={{ x: 0.04, y: 0 }}
              end={{ x: 0.8, y: 0.5 }}
              style={styles.cardGloss}
            />
            <View style={styles.cardGlassEdge} />
            <View style={styles.cardVariantSwitch}>
              <CompanionVariantSwitch active={active} onSelect={selectCompanion} />
            </View>
            {active.portraitStatus !== "approved" ? (
              <View style={styles.pendingPortraitPanel}>
                <Text style={styles.pendingEyebrow}>Portrait in review</Text>
                <Text style={styles.pendingTitle}>{active.identity.ageRange}</Text>
                <Text style={styles.pendingBody}>{active.identity.visualDirection}</Text>
              </View>
            ) : null}

            <View style={styles.cardBio}>
              <View style={styles.profileNameRow}>
                <Text selectable style={styles.profileName}>{active.displayName}</Text>
                <View style={styles.signSquare}>
                  <Text style={styles.signSquareText}>{active.glyph.replace("︎", "️")}</Text>
                </View>
              </View>
              <Text selectable style={styles.profileMeta}>{getPersonaMeta(active)}</Text>
              <Text selectable style={styles.profileBio}>{active.bio}</Text>
              <View style={styles.tagRow}>
                {active.tags.map((tag) => (
                  <Text selectable key={tag} style={styles.tag}>{tag}</Text>
                ))}
              </View>
            </View>

            <Pressable onPress={openChat} style={styles.cardChatButton}>
              <MessagesAppIcon />
            </Pressable>
          </Pressable>
        </View>
        )}
      </ScrollView>

      {viewMode !== "chat" ? <BottomNavigation activeTab={activeTab} onChange={handleTabChange} /> : null}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  previewHost: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#080605"
  },
  previewHostMobile: {
    alignItems: "stretch",
    justifyContent: "flex-start"
  },
  screen: {
    flex: 1,
    backgroundColor: "#050404",
    overflow: "hidden"
  },
  mobileFrame: {
    alignSelf: "stretch"
  },
  phoneFrame: {
    flexGrow: 0,
    flexShrink: 0,
    flexBasis: "auto",
    width: 430,
    maxWidth: "100%",
    borderRadius: 44,
    borderWidth: 1,
    borderColor: "rgba(239,210,136,0.18)",
    shadowColor: "#000",
    shadowOpacity: 0.42,
    shadowRadius: 34,
    shadowOffset: { width: 0, height: 18 }
  },
  brandHeader: {
    position: "absolute",
    alignSelf: "center",
    zIndex: 20,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 3
  },
  brandText: {
    color: "#f3d17f",
    fontFamily: "Georgia",
    fontStyle: "italic",
    fontSize: 30,
    lineHeight: 34,
    fontWeight: "500",
    textShadowColor: "rgba(240,201,121,0.18)",
    textShadowRadius: 8,
    textShadowOffset: { width: 0, height: 1 }
  },
  content: {
    paddingHorizontal: 22,
    gap: 12
  },
  cardStage: {
    alignItems: "center",
    justifyContent: "center"
  },
  peekCard: {
    position: "absolute",
    width: "76%",
    height: 360,
    borderRadius: 34,
    overflow: "hidden",
    opacity: 0.28,
    backgroundColor: "#17110e",
    borderWidth: 1,
    borderColor: "rgba(255,255,255,0.1)"
  },
  peekPlaceholder: {
    flex: 1,
    backgroundColor: "rgba(240,201,121,0.08)"
  },
  peekLeft: {
    left: -92,
    transform: [{ rotate: "-5deg" }, { scale: 0.92 }]
  },
  peekRight: {
    right: -92,
    transform: [{ rotate: "5deg" }, { scale: 0.92 }]
  },
  profileCard: {
    width: "96%",
    borderRadius: 35,
    overflow: "hidden",
    backgroundColor: "#17110e",
    borderWidth: 1,
    borderColor: "rgba(255,248,226,0.36)",
    shadowColor: "#000",
    shadowOpacity: 0.42,
    shadowRadius: 30,
    shadowOffset: { width: 0, height: 18 }
  },
  cardPortraitImage: {
    position: "absolute",
    left: 0,
    right: 0,
    top: 0,
    bottom: 0,
    width: "100%",
    height: "100%"
  },
  pendingCardBackdrop: {
    ...StyleSheet.absoluteFillObject,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#17110e"
  },
  pendingGlyph: {
    color: "rgba(240,201,121,0.18)",
    fontSize: 168,
    fontWeight: "900"
  },
  cardGloss: {
    position: "absolute",
    top: 0,
    left: 0,
    width: "84%",
    height: "42%",
    opacity: 0.36,
    borderTopLeftRadius: 38,
    borderTopRightRadius: 38
  },
  cardGlassEdge: {
    position: "absolute",
    top: 8,
    left: 10,
    right: 10,
    height: 1,
    backgroundColor: "rgba(255,255,255,0.36)"
  },
  cardVariantSwitch: {
    position: "absolute",
    top: 13,
    left: 56,
    right: 56
  },
  variantSwitch: {
    minHeight: 38,
    flexDirection: "row",
    alignItems: "center",
    gap: 0,
    padding: 4,
    borderRadius: 19,
    overflow: "hidden",
    backgroundColor: "rgba(16,13,12,0.34)",
    borderWidth: 1,
    borderColor: "rgba(255,248,226,0.18)"
  },
  variantPill: {
    flex: 1,
    minHeight: 30,
    borderRadius: 15,
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: 8,
    backgroundColor: "transparent"
  },
  variantPillActive: {
    backgroundColor: "rgba(236,212,129,0.82)",
    borderWidth: 1,
    borderColor: "rgba(255,248,226,0.34)",
    shadowColor: "#f0c979",
    shadowOpacity: 0.14,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: 3 }
  },
  variantText: {
    color: "rgba(255,248,239,0.72)",
    fontSize: 13,
    lineHeight: 16,
    fontWeight: "600",
    letterSpacing: 0
  },
  variantTextActive: {
    color: "#11100d"
  },
  pendingPortraitPanel: {
    position: "absolute",
    left: 18,
    right: 18,
    top: 76,
    gap: 7,
    borderRadius: 24,
    padding: 14,
    backgroundColor: "rgba(8,6,5,0.5)",
    borderWidth: 1,
    borderColor: "rgba(240,201,121,0.18)"
  },
  pendingEyebrow: {
    color: "#f0c979",
    fontSize: 10,
    fontWeight: "900",
    letterSpacing: 1.4,
    textTransform: "uppercase"
  },
  pendingTitle: {
    color: "#fff8ef",
    fontSize: 16,
    fontWeight: "900"
  },
  pendingBody: {
    color: "rgba(255,248,239,0.76)",
    fontSize: 12,
    lineHeight: 17,
    fontWeight: "700"
  },
  cardBio: {
    position: "absolute",
    left: 26,
    right: 76,
    bottom: 49,
    gap: 8
  },
  profileNameRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8
  },
  profileName: {
    color: "#fff8ef",
    fontFamily: "Georgia",
    fontSize: 43,
    lineHeight: 43,
    fontWeight: "900"
  },
  signSquare: {
    width: 28,
    height: 28,
    borderRadius: 7,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "rgba(113,63,160,0.88)",
    borderWidth: 1,
    borderColor: "rgba(255,248,239,0.14)"
  },
  signSquareText: {
    color: "#fff8ef",
    fontSize: 18,
    lineHeight: 22,
    fontWeight: "900"
  },
  profileMeta: {
    color: "rgba(255,248,239,0.92)",
    fontSize: 13,
    lineHeight: 17,
    fontWeight: "800"
  },
  profileBio: {
    color: "rgba(255,255,255,0.84)",
    fontSize: 13,
    lineHeight: 19,
    fontStyle: "italic",
    fontWeight: "600"
  },
  tagRow: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 7,
    paddingTop: 14
  },
  tag: {
    overflow: "hidden",
    color: "#fff8ef",
    borderWidth: 1,
    borderColor: "rgba(255,255,255,0.18)",
    borderRadius: 999,
    paddingHorizontal: 10,
    paddingVertical: 6,
    fontSize: 10,
    letterSpacing: 1,
    textTransform: "uppercase",
    fontWeight: "900",
    backgroundColor: "rgba(255,255,255,0.07)"
  },
  cardChatButton: {
    position: "absolute",
    right: 26,
    bottom: 54,
    width: 58,
    height: 58,
    borderRadius: 29,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "rgba(255,248,226,0.08)",
    borderWidth: 1,
    borderColor: "rgba(255,248,226,0.22)",
    shadowColor: "#e9c76d",
    shadowOpacity: 0.22,
    shadowRadius: 16,
    shadowOffset: { width: 0, height: 7 }
  },
  messagesAppIcon: {
    width: 52,
    height: 52,
    borderRadius: 26,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "rgba(221,198,139,0.66)",
    borderWidth: 1,
    borderColor: "rgba(255,249,225,0.48)",
    overflow: "hidden",
    shadowColor: "#000",
    shadowOpacity: 0.18,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: 6 }
  },
  messagesAppIconSheen: {
    position: "absolute",
    left: 8,
    right: 14,
    top: 7,
    height: 14,
    borderRadius: 999,
    backgroundColor: "rgba(255,255,255,0.28)",
    transform: [{ rotate: "-18deg" }]
  },
  messageGlyph: {
    width: 27,
    height: 20,
    borderRadius: 11,
    borderWidth: 2,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 3
  },
  messageGlyphDot: {
    width: 4,
    height: 4,
    borderRadius: 2
  },
  messageGlyphTail: {
    position: "absolute",
    right: 1,
    bottom: -5,
    width: 9,
    height: 9,
    borderRightWidth: 2,
    borderBottomWidth: 2,
    borderBottomRightRadius: 7,
    transform: [{ rotate: "30deg" }]
  },
  chatBubbleIcon: {
    width: 28,
    height: 24,
    alignItems: "center",
    justifyContent: "center"
  },
  chatBubbleIconBody: {
    width: 26,
    height: 19,
    borderRadius: 11,
    zIndex: 2
  },
  chatBubbleIconTail: {
    position: "absolute",
    right: 2,
    bottom: 2,
    width: 10,
    height: 10,
    borderRadius: 3,
    backgroundColor: "#fff",
    transform: [{ rotate: "34deg" }]
  },
  astrogram: {
    gap: 14,
    paddingTop: 8
  },
  featurePanel: {
    minHeight: 552,
    borderRadius: 38,
    overflow: "hidden",
    borderWidth: 1,
    borderColor: "rgba(255,255,255,0.16)",
    backgroundColor: "rgba(255,255,255,0.06)",
    padding: 24,
    justifyContent: "center",
    gap: 12
  },
  featureEyebrow: {
    color: "#e7c27c",
    fontSize: 12,
    letterSpacing: 3,
    fontWeight: "900"
  },
  featureTitle: {
    color: "#fff8ef",
    fontFamily: "Georgia",
    fontSize: 38,
    lineHeight: 41,
    fontWeight: "800"
  },
  featureBody: {
    color: "rgba(255,255,255,0.74)",
    fontSize: 15,
    lineHeight: 22,
    fontWeight: "700"
  },
  toolPanel: {
    gap: 10,
    borderRadius: 28,
    overflow: "hidden",
    borderWidth: 1,
    borderColor: "rgba(255,255,255,0.14)",
    backgroundColor: "rgba(255,255,255,0.055)",
    padding: 14
  },
  toolHeader: {
    gap: 7
  },
  toolTitle: {
    color: "#fff8ef",
    fontFamily: "Georgia",
    fontSize: 24,
    lineHeight: 27,
    fontWeight: "800"
  },
  toolBody: {
    color: "rgba(255,255,255,0.72)",
    fontSize: 11,
    lineHeight: 16,
    fontWeight: "700"
  },
  predictCompanionRow: {
    minHeight: 52,
    borderRadius: 20,
    padding: 9,
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    backgroundColor: "rgba(8,6,5,0.36)",
    borderWidth: 1,
    borderColor: "rgba(255,248,239,0.1)"
  },
  predictAvatar: {
    width: 36,
    height: 36,
    borderRadius: 18,
    borderWidth: 1,
    borderColor: "rgba(240,201,121,0.64)",
    backgroundColor: "#17110e"
  },
  predictCompanionCopy: {
    flex: 1,
    gap: 2
  },
  predictName: {
    color: "#fff8ef",
    fontSize: 15,
    lineHeight: 19,
    fontWeight: "900"
  },
  predictMeta: {
    color: "rgba(255,248,239,0.56)",
    fontSize: 10,
    lineHeight: 14,
    fontWeight: "800"
  },
  predictInputShell: {
    gap: 8
  },
  inputLabel: {
    color: "#f0c979",
    fontSize: 10,
    letterSpacing: 1.5,
    fontWeight: "900",
    textTransform: "uppercase"
  },
  predictInput: {
    minHeight: 64,
    borderRadius: 20,
    paddingHorizontal: 14,
    paddingVertical: 10,
    color: "#fff8ef",
    backgroundColor: "rgba(0,0,0,0.26)",
    borderWidth: 1,
    borderColor: "rgba(255,248,239,0.12)",
    fontSize: 11,
    lineHeight: 16,
    fontWeight: "700"
  },
  modeRow: {
    flexDirection: "row",
    gap: 8
  },
  modeChip: {
    flex: 1,
    minHeight: 32,
    borderRadius: 999,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "rgba(255,255,255,0.08)",
    borderWidth: 1,
    borderColor: "rgba(255,255,255,0.12)"
  },
  modeChipActive: {
    backgroundColor: "rgba(240,201,121,0.86)",
    borderColor: "rgba(255,248,226,0.42)"
  },
  modeChipText: {
    color: "rgba(255,248,239,0.78)",
    fontSize: 12,
    fontWeight: "900"
  },
  modeChipTextActive: {
    color: "#12100c"
  },
  predictionCard: {
    gap: 5,
    borderRadius: 22,
    padding: 10,
    backgroundColor: "rgba(255,248,239,0.07)",
    borderWidth: 1,
    borderColor: "rgba(255,248,239,0.12)"
  },
  predictionLabel: {
    color: "#f0c979",
    fontSize: 9,
    letterSpacing: 1.3,
    fontWeight: "900",
    textTransform: "uppercase"
  },
  predictionText: {
    color: "rgba(255,248,239,0.78)",
    fontSize: 11,
    lineHeight: 16,
    fontWeight: "700"
  },
  replyCard: {
    gap: 3,
    borderRadius: 20,
    padding: 10,
    backgroundColor: "rgba(240,201,121,0.13)",
    borderWidth: 1,
    borderColor: "rgba(240,201,121,0.22)"
  },
  replyLabel: {
    color: "rgba(255,248,239,0.72)",
    fontSize: 10,
    letterSpacing: 1.1,
    fontWeight: "900",
    textTransform: "uppercase"
  },
  replyText: {
    color: "#fff8ef",
    fontSize: 13,
    lineHeight: 18,
    fontWeight: "900"
  },
  predictionWhy: {
    color: "rgba(255,248,239,0.55)",
    fontSize: 11,
    lineHeight: 16,
    fontWeight: "700"
  },
  primaryAction: {
    minHeight: 50,
    borderRadius: 999,
    paddingHorizontal: 16,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 10,
    backgroundColor: "#f0c979",
    borderWidth: 1,
    borderColor: "rgba(255,248,226,0.48)"
  },
  primaryActionText: {
    color: "#14100b",
    fontSize: 14,
    fontWeight: "900"
  },
  chartCardGrid: {
    gap: 9
  },
  chartCard: {
    gap: 5,
    borderRadius: 22,
    padding: 13,
    backgroundColor: "rgba(8,6,5,0.32)",
    borderWidth: 1,
    borderColor: "rgba(255,248,239,0.1)"
  },
  chartCardLabel: {
    color: "#f0c979",
    fontSize: 10,
    letterSpacing: 1.4,
    fontWeight: "900",
    textTransform: "uppercase"
  },
  chartCardTitle: {
    color: "#fff8ef",
    fontSize: 18,
    lineHeight: 22,
    fontWeight: "900"
  },
  chartCardBody: {
    color: "rgba(255,248,239,0.68)",
    fontSize: 12,
    lineHeight: 17,
    fontWeight: "700"
  },
  profileSection: {
    gap: 6,
    borderRadius: 24,
    padding: 13,
    backgroundColor: "rgba(255,248,239,0.065)",
    borderWidth: 1,
    borderColor: "rgba(255,248,239,0.1)"
  },
  profileSectionTitle: {
    color: "#fff8ef",
    fontSize: 15,
    lineHeight: 19,
    fontWeight: "900"
  },
  profileSectionBody: {
    color: "rgba(255,248,239,0.68)",
    fontSize: 12,
    lineHeight: 17,
    fontWeight: "700"
  },
  profileMemory: {
    color: "rgba(255,248,239,0.68)",
    fontSize: 12,
    lineHeight: 17,
    fontWeight: "700"
  },
  astrogramTop: {
    minHeight: 48,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingHorizontal: 1
  },
  astroBack: {
    width: 44,
    height: 44,
    borderRadius: 22,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "rgba(255,255,255,0.1)",
    borderWidth: 1,
    borderColor: "rgba(255,255,255,0.16)"
  },
  astroBackText: {
    color: "#fff8ef",
    fontSize: 33,
    lineHeight: 36,
    fontWeight: "300"
  },
  astroTitleLockup: {
    alignItems: "center",
    gap: 2
  },
  astroTitle: {
    color: "#fff8ef",
    fontFamily: "Georgia",
    fontSize: 27,
    fontStyle: "italic",
    fontWeight: "400"
  },
  astroSubtitle: {
    color: "rgba(255,248,239,0.54)",
    fontSize: 10,
    fontWeight: "900",
    letterSpacing: 1.4,
    textTransform: "uppercase"
  },
  astroMessage: {
    width: 44,
    height: 44,
    borderRadius: 22,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#31d158",
    borderWidth: 1,
    borderColor: "rgba(255,255,255,0.38)",
    shadowColor: "#31d158",
    shadowOpacity: 0.28,
    shadowRadius: 16,
    shadowOffset: { width: 0, height: 8 }
  },
  astroMessagePlaceholder: {
    width: 42,
    height: 42
  },
  astroProfilePanel: {
    gap: 16,
    padding: 16,
    borderRadius: 30,
    backgroundColor: "rgba(255,248,239,0.075)",
    borderWidth: 1,
    borderColor: "rgba(255,248,239,0.12)"
  },
  astroHero: {
    flexDirection: "row",
    alignItems: "center",
    gap: 16
  },
  astroAvatar: {
    width: 92,
    height: 92,
    borderRadius: 46,
    borderWidth: 2,
    borderColor: "rgba(240,201,121,0.8)",
    backgroundColor: "#17110e"
  },
  astroAvatarPlaceholder: {
    alignItems: "center",
    justifyContent: "center"
  },
  astroAvatarGlyph: {
    color: "rgba(240,201,121,0.8)",
    fontSize: 34,
    fontWeight: "900"
  },
  astroStatsRow: {
    flex: 1,
    minHeight: 70,
    borderRadius: 22,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-around",
    backgroundColor: "rgba(8,6,5,0.36)",
    borderWidth: 1,
    borderColor: "rgba(255,248,239,0.09)"
  },
  astroStats: {
    alignItems: "center",
    gap: 2
  },
  astroDivider: {
    width: 1,
    height: 32,
    backgroundColor: "rgba(255,248,239,0.13)"
  },
  astroNumber: {
    color: "#fff8ef",
    fontSize: 18,
    fontWeight: "900"
  },
  astroLabel: {
    color: "rgba(255,248,239,0.48)",
    fontSize: 10,
    textTransform: "uppercase",
    letterSpacing: 1.2,
    fontWeight: "800"
  },
  astroBio: {
    color: "rgba(255,248,239,0.78)",
    fontSize: 13,
    lineHeight: 19,
    fontWeight: "700"
  },
  assetNote: {
    color: "rgba(240,201,121,0.84)",
    fontSize: 12,
    lineHeight: 17,
    fontWeight: "800"
  },
  astroTagRow: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 7
  },
  astroTag: {
    overflow: "hidden",
    color: "#f0c979",
    borderWidth: 1,
    borderColor: "rgba(240,201,121,0.24)",
    borderRadius: 999,
    paddingHorizontal: 10,
    paddingVertical: 6,
    fontSize: 10,
    letterSpacing: 0.8,
    textTransform: "uppercase",
    fontWeight: "900",
    backgroundColor: "rgba(240,201,121,0.08)"
  },
  photoGrid: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 7
  },
  photoTile: {
    width: "31.9%",
    aspectRatio: 1,
    borderRadius: 20,
    overflow: "hidden",
    backgroundColor: "#17110e",
    borderWidth: 1,
    borderColor: "rgba(255,255,255,0.1)"
  },
  photoPlaceholder: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    padding: 10,
    backgroundColor: "rgba(240,201,121,0.1)"
  },
  photoPlaceholderLabel: {
    color: "rgba(255,248,239,0.72)",
    fontSize: 10,
    lineHeight: 13,
    fontWeight: "900",
    textAlign: "center",
    textTransform: "uppercase"
  },
  postModal: {
    flex: 1,
    backgroundColor: "rgba(0,0,0,0.74)",
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: 18,
    paddingVertical: 28
  },
  postSheet: {
    width: "100%",
    maxWidth: 430,
    maxHeight: "94%",
    borderRadius: 30,
    overflow: "hidden",
    backgroundColor: "#100d0b",
    borderWidth: 1,
    borderColor: "rgba(255,248,239,0.16)"
  },
  postHeader: {
    minHeight: 58,
    paddingHorizontal: 16,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    backgroundColor: "rgba(255,248,239,0.06)",
    borderBottomWidth: 1,
    borderBottomColor: "rgba(255,248,239,0.1)"
  },
  postName: {
    color: "#fff8ef",
    fontSize: 16,
    fontWeight: "900"
  },
  postMeta: {
    color: "rgba(255,248,239,0.48)",
    fontSize: 10,
    fontWeight: "800",
    letterSpacing: 1.2,
    textTransform: "uppercase"
  },
  postClose: {
    width: 38,
    height: 38,
    borderRadius: 19,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "rgba(255,255,255,0.08)"
  },
  postCloseText: {
    color: "#fff8ef",
    fontSize: 26,
    lineHeight: 29,
    fontWeight: "300"
  },
  postImage: {
    width: "100%",
    aspectRatio: 4 / 5,
    backgroundColor: "#050403",
    borderBottomWidth: 1,
    borderBottomColor: "rgba(255,248,239,0.08)"
  },
  postImagePlaceholder: {
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "rgba(240,201,121,0.1)"
  },
  postActions: {
    minHeight: 46,
    flexDirection: "row",
    alignItems: "center",
    gap: 18,
    paddingHorizontal: 17,
    borderBottomWidth: 1,
    borderBottomColor: "rgba(255,248,239,0.08)"
  },
  postAction: {
    color: "#fff8ef",
    fontSize: 24,
    fontWeight: "700"
  },
  commentList: {
    maxHeight: 150,
    paddingHorizontal: 17,
    paddingVertical: 12
  },
  postCaption: {
    color: "rgba(255,248,239,0.82)",
    fontSize: 13,
    lineHeight: 19,
    marginBottom: 8
  },
  emptyComments: {
    color: "rgba(255,248,239,0.42)",
    fontSize: 13,
    lineHeight: 20
  },
  commentText: {
    color: "rgba(255,248,239,0.8)",
    fontSize: 13,
    lineHeight: 20,
    marginBottom: 6
  },
  commentAuthor: {
    color: "#fff8ef",
    fontWeight: "900"
  },
  commentComposer: {
    minHeight: 54,
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
    paddingHorizontal: 14,
    borderTopWidth: 1,
    borderTopColor: "rgba(255,248,239,0.1)"
  },
  commentInput: {
    flex: 1,
    minHeight: 40,
    color: "#fff8ef",
    fontSize: 14
  },
  commentSend: {
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 999,
    backgroundColor: "rgba(240,201,121,0.14)",
    borderWidth: 1,
    borderColor: "rgba(240,201,121,0.24)"
  },
  commentSendText: {
    color: "#f0c979",
    fontSize: 12,
    fontWeight: "900"
  },
  chatPanel: {
    gap: 8,
    paddingTop: 0
  },
  dmHeader: {
    minHeight: 52,
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
    paddingHorizontal: 2
  },
  dmBack: {
    width: 38,
    height: 38,
    borderRadius: 19,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "rgba(255,255,255,0.08)",
    borderWidth: 1,
    borderColor: "rgba(255,255,255,0.12)"
  },
  dmBackText: {
    color: "#fff8ef",
    fontSize: 30,
    lineHeight: 34,
    fontWeight: "300"
  },
  dmAvatar: {
    width: 39,
    height: 39,
    borderRadius: 19.5,
    borderWidth: 1,
    borderColor: "rgba(240,201,121,0.54)",
    backgroundColor: "#17110e"
  },
  dmTitleLockup: {
    flex: 1,
    gap: 1
  },
  dmName: {
    color: "#fff8ef",
    fontSize: 16,
    lineHeight: 20,
    fontWeight: "900"
  },
  dmStatus: {
    color: "rgba(255,248,239,0.52)",
    fontSize: 11,
    lineHeight: 15,
    fontWeight: "800"
  },
  dmCallButton: {
    width: 38,
    height: 38,
    borderRadius: 19,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "rgba(240,201,121,0.12)",
    borderWidth: 1,
    borderColor: "rgba(240,201,121,0.24)"
  },
  dmCallGlyph: {
    color: "#f0c979",
    fontSize: 18,
    lineHeight: 20,
    fontWeight: "700"
  },
  dmProfileCard: {
    alignItems: "flex-start",
    gap: 6,
    paddingHorizontal: 12,
    paddingVertical: 9,
    borderRadius: 18,
    backgroundColor: "rgba(255,248,239,0.07)",
    borderWidth: 1,
    borderColor: "rgba(255,248,239,0.1)"
  },
  dmProfilePhoto: {
    width: 72,
    height: 72,
    borderRadius: 36,
    borderWidth: 2,
    borderColor: "rgba(240,201,121,0.62)",
    backgroundColor: "#17110e"
  },
  dmProfileName: {
    color: "#fff8ef",
    fontSize: 20,
    lineHeight: 24,
    fontWeight: "900"
  },
  dmProfileLabel: {
    color: "#f0c979",
    fontSize: 10,
    letterSpacing: 1.5,
    fontWeight: "900",
    textTransform: "uppercase"
  },
  dmProfileBio: {
    color: "rgba(255,248,239,0.62)",
    fontSize: 10,
    lineHeight: 14,
    fontWeight: "800",
    textAlign: "left"
  },
  chartPillRow: {
    flexDirection: "row",
    flexWrap: "wrap",
    justifyContent: "flex-start",
    gap: 6
  },
  chartPill: {
    overflow: "hidden",
    color: "#f0c979",
    borderWidth: 1,
    borderColor: "rgba(240,201,121,0.24)",
    borderRadius: 999,
    paddingHorizontal: 8,
    paddingVertical: 4,
    fontSize: 9,
    letterSpacing: 0.7,
    textTransform: "uppercase",
    fontWeight: "900",
    backgroundColor: "rgba(240,201,121,0.08)"
  },
  releaseGateRow: {
    width: "100%",
    flexDirection: "row",
    flexWrap: "wrap",
    alignItems: "center",
    gap: 7,
    paddingTop: 2
  },
  releaseGatePill: {
    overflow: "hidden",
    color: "#11100d",
    backgroundColor: "rgba(240,201,121,0.86)",
    borderRadius: 999,
    paddingHorizontal: 9,
    paddingVertical: 4,
    fontSize: 9,
    letterSpacing: 0.8,
    textTransform: "uppercase",
    fontWeight: "900"
  },
  releaseGateCopy: {
    color: "rgba(255,248,239,0.48)",
    fontSize: 10,
    lineHeight: 14,
    fontWeight: "800"
  },
  chatBubbleIncoming: {
    maxWidth: "100%",
    borderRadius: 24,
    borderBottomLeftRadius: 8,
    backgroundColor: "rgba(255,255,255,0.1)",
    borderWidth: 1,
    borderColor: "rgba(255,255,255,0.12)",
    paddingHorizontal: 15,
    paddingVertical: 12
  },
  chatBubbleText: {
    color: "#fff8ef",
    fontSize: 13,
    lineHeight: 18,
    fontWeight: "700"
  },
  memoryPanel: {
    gap: 4,
    borderRadius: 22,
    padding: 12,
    backgroundColor: "rgba(240,201,121,0.08)",
    borderWidth: 1,
    borderColor: "rgba(240,201,121,0.14)"
  },
  memoryEyebrow: {
    color: "#f0c979",
    fontSize: 10,
    letterSpacing: 1.4,
    fontWeight: "900",
    textTransform: "uppercase"
  },
  memorySignal: {
    color: "rgba(255,248,239,0.68)",
    fontSize: 11,
    lineHeight: 15,
    fontWeight: "700"
  },
  dmThread: {
    width: "100%",
    gap: 6,
    paddingVertical: 2
  },
  dmMessageRow: {
    width: "100%",
    flexDirection: "row",
    alignItems: "flex-end",
    gap: 7,
    paddingRight: 4
  },
  dmMessageRowOutgoing: {
    justifyContent: "flex-end"
  },
  dmMessageAvatar: {
    width: 26,
    height: 26,
    borderRadius: 13,
    backgroundColor: "#17110e",
    borderWidth: 1,
    borderColor: "rgba(255,248,239,0.15)"
  },
  dmBubble: {
    maxWidth: "82%",
    flexShrink: 1,
    borderRadius: 22,
    paddingHorizontal: 13,
    paddingVertical: 9
  },
  dmBubbleIncoming: {
    borderBottomLeftRadius: 7,
    backgroundColor: "rgba(255,255,255,0.12)",
    borderWidth: 1,
    borderColor: "rgba(255,255,255,0.1)"
  },
  dmBubbleOutgoing: {
    borderBottomRightRadius: 7,
    backgroundColor: "#f0c979"
  },
  dmBubbleText: {
    color: "#fff8ef",
    fontSize: 13,
    lineHeight: 18,
    fontWeight: "700",
    flexShrink: 1
  },
  dmBubbleTextOutgoing: {
    color: "#15110c"
  },
  dmSeen: {
    alignSelf: "flex-end",
    color: "rgba(255,248,239,0.42)",
    fontSize: 10,
    fontWeight: "800",
    paddingRight: 4
  },
  typingBubble: {
    minWidth: 52,
    minHeight: 34,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 3,
    paddingHorizontal: 14,
    paddingVertical: 8
  },
  typingDot: {
    color: "rgba(255,248,239,0.78)",
    fontSize: 18,
    lineHeight: 18,
    fontWeight: "900"
  },
  quickPromptRow: {
    gap: 8,
    paddingRight: 8
  },
  quickPrompt: {
    borderRadius: 999,
    paddingHorizontal: 12,
    paddingVertical: 7,
    backgroundColor: "rgba(255,255,255,0.08)",
    borderWidth: 1,
    borderColor: "rgba(255,255,255,0.12)"
  },
  quickPromptText: {
    color: "#fff8ef",
    fontSize: 12,
    fontWeight: "900"
  },
  whyPanel: {
    gap: 6,
    borderRadius: 24,
    padding: 12,
    backgroundColor: "rgba(255,248,239,0.075)",
    borderWidth: 1,
    borderColor: "rgba(255,248,239,0.12)"
  },
  whyEyebrow: {
    color: "#e7c27c",
    fontSize: 10,
    letterSpacing: 1.5,
    fontWeight: "900",
    textTransform: "uppercase"
  },
  whyRow: {
    gap: 2
  },
  whyLabel: {
    color: "#fff8ef",
    fontSize: 12,
    fontWeight: "900"
  },
  whyBody: {
    color: "rgba(255,248,239,0.66)",
    fontSize: 11,
    lineHeight: 15,
    fontWeight: "700"
  },
  chatComposer: {
    marginTop: 0,
    marginBottom: 0,
    minHeight: 48,
    borderRadius: 999,
    backgroundColor: "rgba(255,255,255,0.9)",
    paddingLeft: 18,
    paddingRight: 7,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between"
  },
  chatInput: {
    flex: 1,
    color: "rgba(16,12,8,0.62)",
    fontSize: 14,
    fontWeight: "800",
    minHeight: 43
  },
  dmSendButton: {
    width: 38,
    height: 38,
    borderRadius: 19,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "rgba(240,201,121,0.86)"
  }
});
