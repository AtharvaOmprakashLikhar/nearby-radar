/**
 * NEARBY - OFFLINE BLUETOOTH RADAR MESSENGER
 * Interactive Radar Engine, Profile Creation Studio, and QR Code Generator
 */

document.addEventListener("DOMContentLoaded", () => {
  initRadarCanvas();
  initProfileStudio();
  initDownloadModal();
});

/* ==========================================================================
   1. LIVE HERO RADAR CANVAS ENGINE (60 FPS)
   ========================================================================== */
function initRadarCanvas() {
  const canvas = document.getElementById("radarCanvas");
  if (!canvas) return;
  const ctx = canvas.getContext("2d");

  let width = canvas.width;
  let height = canvas.height;
  let sweepAngle = 0;
  const sweepSpeed = 0.025; // Radians per frame

  // Web Audio Context for radar pings
  let audioCtx = null;
  let audioEnabled = false;

  const audioToggleBtn = document.getElementById("toggleAudioBtn");
  const audioIcon = document.getElementById("audioIcon");
  const audioStatusText = document.getElementById("audioStatusText");

  if (audioToggleBtn) {
    audioToggleBtn.addEventListener("click", () => {
      audioEnabled = !audioEnabled;
      if (audioEnabled) {
        if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
        audioIcon.textContent = "🔊";
        audioStatusText.textContent = "ON";
        audioToggleBtn.classList.add("active");
        playSonarPing(880);
      } else {
        audioIcon.textContent = "🔇";
        audioStatusText.textContent = "OFF";
        audioToggleBtn.classList.remove("active");
      }
    });
  }

  function playSonarPing(freq = 660) {
    if (!audioEnabled || !audioCtx) return;
    try {
      const osc = audioCtx.createOscillator();
      const gain = audioCtx.createGain();
      osc.type = "sine";
      osc.frequency.setValueAtTime(freq, audioCtx.currentTime);
      gain.gain.setValueAtTime(0.08, audioCtx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.0001, audioCtx.currentTime + 0.35);

      osc.connect(gain);
      gain.connect(audioCtx.destination);
      osc.start();
      osc.stop(audioCtx.currentTime + 0.36);
    } catch (e) {}
  }

  // Simulated live peers
  const peers = [
    { id: "p1", name: "Raven", angle: 0.8, distanceRatio: 0.38, status: "available", avatar: "🦅", pinged: false },
    { id: "p2", name: "Nova", angle: 2.3, distanceRatio: 0.65, status: "available", avatar: "✨", pinged: false },
    { id: "p3", name: "CyberPulse", angle: 4.1, distanceRatio: 0.22, status: "busy", avatar: "⚡", pinged: false },
    { id: "p4", name: "Nomad", angle: 5.4, distanceRatio: 0.82, status: "available", avatar: "🎒", pinged: false }
  ];

  // Spawn peer button
  const addPeerBtn = document.getElementById("addPeerBtn");
  if (addPeerBtn) {
    addPeerBtn.addEventListener("click", () => {
      const names = ["Vortex", "Specter", "Echo", "Aegis", "Orion", "Cipher"];
      const avatars = ["👾", "🛡️", "🦊", "🛰️", "🚀", "🪐"];
      const newPeer = {
        id: "p_" + Date.now(),
        name: names[Math.floor(Math.random() * names.length)],
        angle: Math.random() * Math.PI * 2,
        distanceRatio: 0.15 + Math.random() * 0.75,
        status: Math.random() > 0.3 ? "available" : "busy",
        avatar: avatars[Math.floor(Math.random() * avatars.length)],
        pinged: false
      };
      peers.push(newPeer);
      playSonarPing(920);
    });
  }

  // Click on canvas to spawn or select peer
  canvas.addEventListener("click", (e) => {
    const rect = canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    const center = { x: width / 2, y: height / 2 };
    const dx = x - center.x;
    const dy = y - center.y;
    const clickDist = Math.sqrt(dx * dx + dy * dy);
    const maxRadius = width / 2 - 20;

    if (clickDist <= maxRadius) {
      // Check if clicked an existing peer
      let clickedPeer = null;
      for (const p of peers) {
        const px = center.x + Math.cos(p.angle) * (p.distanceRatio * maxRadius);
        const py = center.y + Math.sin(p.angle) * (p.distanceRatio * maxRadius);
        const dist = Math.hypot(x - px, y - py);
        if (dist < 24) {
          clickedPeer = p;
          break;
        }
      }

      if (clickedPeer) {
        playSonarPing(1100);
        alert(`🎯 Peer Selected on Radar:\n\nName: ${clickedPeer.name}\nStatus: ${clickedPeer.status.toUpperCase()}\nDistance: ~${Math.round(clickedPeer.distanceRatio * 15)}m`);
      } else {
        // Spawn peer at click location
        const angle = Math.atan2(dy, dx);
        const normalizedAngle = angle < 0 ? angle + Math.PI * 2 : angle;
        peers.push({
          id: "p_" + Date.now(),
          name: "Peer " + Math.floor(Math.random() * 900 + 100),
          angle: normalizedAngle,
          distanceRatio: clickDist / maxRadius,
          status: "available",
          avatar: "📡",
          pinged: false
        });
        playSonarPing(800);
      }
    }
  });

  function draw() {
    ctx.clearRect(0, 0, width, height);

    const center = { x: width / 2, y: height / 2 };
    const maxRadius = width / 2 - 20;

    // 1. Concentric Range Rings
    ctx.lineWidth = 1.2;
    ctx.strokeStyle = "rgba(0, 245, 212, 0.18)";

    // Rings: <2m, ~5m, ~10m, outer border
    const ringFractions = [0.22, 0.48, 0.74, 1.0];
    ringFractions.forEach(f => {
      ctx.beginPath();
      ctx.arc(center.x, center.y, maxRadius * f, 0, Math.PI * 2);
      ctx.stroke();
    });

    // 2. Radial Crosshairs
    ctx.beginPath();
    ctx.moveTo(center.x - maxRadius, center.y);
    ctx.lineTo(center.x + maxRadius, center.y);
    ctx.moveTo(center.x, center.y - maxRadius);
    ctx.lineTo(center.x, center.y + maxRadius);
    ctx.strokeStyle = "rgba(0, 245, 212, 0.12)";
    ctx.stroke();

    // 3. Ring distance labels
    ctx.fillStyle = "rgba(0, 245, 212, 0.65)";
    ctx.font = "10px 'Space Grotesk', monospace";
    ctx.fillText("<2m", center.x + 6, center.y - maxRadius * 0.22 + 10);
    ctx.fillText("~5m", center.x + 6, center.y - maxRadius * 0.48 + 10);
    ctx.fillText("~10m", center.x + 6, center.y - maxRadius * 0.74 + 10);

    // 4. Rotating Sweep Line with Phosphor Glow Trail
    ctx.save();
    ctx.translate(center.x, center.y);

    // Draw sweep trail (pie wedge gradient)
    const trailSegments = 30;
    const trailArc = Math.PI * 0.45;
    for (let i = 0; i < trailSegments; i++) {
      const a1 = sweepAngle - (i / trailSegments) * trailArc;
      const a2 = sweepAngle - ((i + 1) / trailSegments) * trailArc;
      const alpha = (1 - (i / trailSegments)) * 0.18;

      ctx.beginPath();
      ctx.moveTo(0, 0);
      ctx.arc(0, 0, maxRadius, a2, a1);
      ctx.closePath();
      ctx.fillStyle = `rgba(0, 245, 212, ${alpha})`;
      ctx.fill();
    }

    // Leading Sweep Line
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.lineTo(Math.cos(sweepAngle) * maxRadius, Math.sin(sweepAngle) * maxRadius);
    ctx.lineWidth = 2.2;
    ctx.strokeStyle = "#00F5D4";
    ctx.shadowColor = "#00F5D4";
    ctx.shadowBlur = 10;
    ctx.stroke();
    ctx.restore();

    // 5. Draw Peers and detect sweep line overlap
    peers.forEach(peer => {
      const px = center.x + Math.cos(peer.angle) * (peer.distanceRatio * maxRadius);
      const py = center.y + Math.sin(peer.angle) * (peer.distanceRatio * maxRadius);

      // Check if sweep line is passing this peer's angle
      let angleDiff = Math.abs(sweepAngle - peer.angle);
      if (angleDiff > Math.PI) angleDiff = Math.PI * 2 - angleDiff;

      if (angleDiff < 0.05 && !peer.pinged) {
        peer.pinged = true;
        playSonarPing(750 + peer.distanceRatio * 400);
      } else if (angleDiff >= 0.1) {
        peer.pinged = false;
      }

      // Blip pulse aura
      const color = peer.status === "available" ? "#00FF88" : "#FFB800";
      ctx.beginPath();
      ctx.arc(px, py, 14, 0, Math.PI * 2);
      ctx.fillStyle = peer.status === "available" ? "rgba(0, 255, 136, 0.2)" : "rgba(255, 184, 0, 0.2)";
      ctx.fill();

      // Blip core
      ctx.beginPath();
      ctx.arc(px, py, 8, 0, Math.PI * 2);
      ctx.fillStyle = color;
      ctx.shadowColor = color;
      ctx.shadowBlur = 8;
      ctx.fill();
      ctx.shadowBlur = 0;

      // Peer label
      ctx.fillStyle = "#F8FAFC";
      ctx.font = "bold 9px 'Outfit', sans-serif";
      ctx.fillText(peer.avatar + " " + peer.name, px - 16, py + 22);
    });

    // 6. Center Local User Beacon
    ctx.beginPath();
    ctx.arc(center.x, center.y, 8, 0, Math.PI * 2);
    ctx.fillStyle = "#00F5D4";
    ctx.shadowColor = "#00F5D4";
    ctx.shadowBlur = 14;
    ctx.fill();
    ctx.shadowBlur = 0;

    sweepAngle = (sweepAngle + sweepSpeed) % (Math.PI * 2);
    requestAnimationFrame(draw);
  }

  requestAnimationFrame(draw);
}

/* ==========================================================================
   2. PROFILE CREATION STUDIO & LIVE PREVIEW
   ========================================================================== */
function initProfileStudio() {
  const nameInput = document.getElementById("displayNameInput");
  const bioInput = document.getElementById("bioInput");
  const bioCharCount = document.getElementById("bioCharCount");
  const randomizeBtn = document.getElementById("randomizeNameBtn");
  const presetAvatars = document.querySelectorAll(".preset-avatar");
  const avatarFileInput = document.getElementById("avatarFileInput");
  const statusPills = document.querySelectorAll(".status-pill");
  const tagsContainer = document.getElementById("tagsContainer");
  const newTagInput = document.getElementById("newTagInput");
  const addTagBtn = document.getElementById("addTagBtn");
  const saveProfileBtn = document.getElementById("saveProfileBtn");

  // Preview elements
  const previewName = document.getElementById("previewNameDisplay");
  const previewBio = document.getElementById("previewBioDisplay");
  const previewBlipAvatar = document.getElementById("previewBlipAvatar");
  const previewSheetAvatar = document.getElementById("previewSheetAvatar");
  const previewStatusBadge = document.getElementById("previewStatusBadge");
  const previewSafetyBadge = document.getElementById("previewSafetyCodeBadge");
  const cryptoKeyDisplay = document.getElementById("cryptoKeyDisplay");
  const safetyCodeDisplay = document.getElementById("safetyCodeDisplay");
  const deviceUuidDisplay = document.getElementById("deviceUuidDisplay");

  let currentAvatar = "🦊";
  let currentStatus = 0; // 0=Available, 1=Busy, 2=Invisible
  let currentTags = ["Radar", "P2P", "Privacy"];

  // Generate synthetic crypto keys
  function generateSyntheticIdentity() {
    const uuid = "8f" + Math.random().toString(16).substring(2, 8) + "-" + Math.random().toString(16).substring(2, 6);
    const pubKey = "e4c1" + Math.random().toString(16).substring(2, 10) + "892b";
    const code = Math.floor(Math.random() * 900000 + 100000).toString();
    const safetyCode = code.substring(0, 3) + " " + code.substring(3, 6);

    deviceUuidDisplay.textContent = uuid;
    cryptoKeyDisplay.textContent = pubKey;
    safetyCodeDisplay.textContent = safetyCode;
    previewSafetyBadge.textContent = safetyCode;

    return { uuid, pubKey, safetyCode };
  }

  let activeIdentity = generateSyntheticIdentity();

  // Randomize Name
  const cyberNames = [
    "CyberPhantom", "EchoRider", "VortexSignal", "NovaDrifter", "ShadowLink",
    "StealthBeacon", "AegisNode", "ZeroCipher", "PulseWalker", "NexusCore"
  ];

  if (randomizeBtn) {
    randomizeBtn.addEventListener("click", () => {
      const rand = cyberNames[Math.floor(Math.random() * cyberNames.length)];
      nameInput.value = rand;
      updatePreview();
    });
  }

  // Name & Bio Input Handlers
  if (nameInput) {
    nameInput.addEventListener("input", updatePreview);
  }

  if (bioInput) {
    bioInput.addEventListener("input", () => {
      bioCharCount.textContent = bioInput.value.length;
      updatePreview();
    });
  }

  // Preset Avatar Selection
  presetAvatars.forEach(el => {
    el.addEventListener("click", () => {
      presetAvatars.forEach(a => a.classList.remove("selected"));
      el.classList.add("selected");
      currentAvatar = el.getAttribute("data-avatar");
      updatePreview();
    });
  });

  // Custom Avatar Upload
  if (avatarFileInput) {
    avatarFileInput.addEventListener("change", (e) => {
      const file = e.target.files[0];
      if (file) {
        const reader = new FileReader();
        reader.onload = (ev) => {
          currentAvatar = ev.target.result;
          presetAvatars.forEach(a => a.classList.remove("selected"));
          updatePreview();
        };
        reader.readAsDataURL(file);
      }
    });
  }

  // Presence Status Pills
  statusPills.forEach(pill => {
    pill.addEventListener("click", () => {
      statusPills.forEach(p => p.classList.remove("selected"));
      pill.classList.add("selected");
      currentStatus = parseInt(pill.getAttribute("data-status"), 10);
      updatePreview();
    });
  });

  // Interest Tags
  function renderTags() {
    tagsContainer.innerHTML = "";
    currentTags.forEach(tag => {
      const badge = document.createElement("span");
      badge.className = "tag-badge";
      badge.innerHTML = `#${tag} <span class="tag-remove" data-tag="${tag}">×</span>`;
      tagsContainer.appendChild(badge);
    });

    document.querySelectorAll(".tag-remove").forEach(btn => {
      btn.addEventListener("click", (e) => {
        const t = e.target.getAttribute("data-tag");
        currentTags = currentTags.filter(item => item !== t);
        renderTags();
      });
    });
  }

  if (addTagBtn && newTagInput) {
    addTagBtn.addEventListener("click", () => {
      const val = newTagInput.value.trim().replace("#", "");
      if (val && !currentTags.includes(val)) {
        currentTags.push(val);
        newTagInput.value = "";
        renderTags();
      }
    });
    newTagInput.addEventListener("keypress", (e) => {
      if (e.key === "Enter") addTagBtn.click();
    });
  }

  function updatePreview() {
    const name = nameInput.value.trim() || "Anonymous";
    const bio = bioInput.value.trim() || "Exploring offline mesh networks.";

    previewName.textContent = name;
    previewBio.textContent = bio;

    // Render avatar
    if (currentAvatar.startsWith("data:image")) {
      previewBlipAvatar.innerHTML = `<img src="${currentAvatar}" style="width:100%;height:100%;border-radius:50%;object-fit:cover;">`;
      previewSheetAvatar.innerHTML = `<img src="${currentAvatar}" style="width:100%;height:100%;border-radius:50%;object-fit:cover;">`;
    } else {
      previewBlipAvatar.textContent = currentAvatar;
      previewSheetAvatar.textContent = currentAvatar;
    }

    // Status styling
    const statusText = currentStatus === 0 ? "Available • <2 m" : (currentStatus === 1 ? "Busy • <2 m" : "Invisible Mode");
    previewStatusBadge.textContent = statusText;
  }

  // Save Profile Handler
  if (saveProfileBtn) {
    saveProfileBtn.addEventListener("click", () => {
      const profileData = {
        name: nameInput.value.trim() || "Echo Explorer",
        bio: bioInput.value.trim(),
        status: currentStatus,
        avatar: currentAvatar,
        tags: currentTags,
        identity: activeIdentity,
        savedAt: new Date().toISOString()
      };

      try {
        localStorage.setItem("nearby_web_profile", JSON.stringify(profileData));
      } catch (e) {}

      // Trigger Download & QR Code modal with Profile Sync tab active
      window.openDownloadModalWithProfile(profileData);
    });
  }

  // Initial render of section QR
  const sectionQr = document.getElementById("sectionQrCanvas");
  if (sectionQr && window.QRCode) {
    const apkUrl = window.location.origin + "/download/Nearby-v1.0.0.apk";
    QRCode.renderCanvas(sectionQr, apkUrl, {
      size: 220,
      foreground: "#00F5D4",
      background: "#090E1A"
    });
  }
}

/* ==========================================================================
   3. DOWNLOAD CENTER & DYNAMIC QR CODE MODAL
   ========================================================================== */
function initDownloadModal() {
  const modal = document.getElementById("qrModal");
  const openModalBtn = document.getElementById("openDownloadModalBtn");
  const heroDownloadBtn = document.getElementById("heroDownloadBtn");
  const closeModalBtn = document.getElementById("closeModalBtn");
  const modalTabs = document.querySelectorAll(".modal-tab-btn");
  const modalQrCanvas = document.getElementById("modalQrCanvas");
  const modalQrHint = document.getElementById("modalQrHint");
  const copyLinkBtn = document.getElementById("copyDownloadLinkBtn");
  const showProfileQrBtn = document.getElementById("showProfileQrBtn");

  let activeTab = "android";
  let savedProfile = null;

  function renderModalQr() {
    if (!modalQrCanvas || !window.QRCode) return;

    const currentOrigin = window.location.origin.includes("http") ? window.location.origin : "http://localhost:3000";
    let qrPayload = "";

    if (activeTab === "android") {
      qrPayload = `${currentOrigin}/download/Nearby-Radar-v1.0.0.apk`;
      modalQrHint.innerHTML = "Scan with your Android phone camera to download <strong>Nearby-Radar-v1.0.0.apk</strong> directly.";
    } else if (activeTab === "ios") {
      qrPayload = "https://testflight.apple.com/join/nearby-mesh-beta";
      modalQrHint.innerHTML = "Scan with iPhone camera to join the <strong>iOS TestFlight Beta</strong> (CoreBluetooth + Multipeer).";
    } else if (activeTab === "profile") {
      const p = savedProfile || { name: "Echo Explorer", status: 0, bio: "Offline mesh explorer" };
      qrPayload = "nearby://profile?data=" + encodeURIComponent(JSON.stringify(p));
      modalQrHint.innerHTML = "Open the <strong>Nearby Mobile App</strong> and scan this QR code to instantly import your web profile!";
    }

    QRCode.renderCanvas(modalQrCanvas, qrPayload, {
      size: 240,
      foreground: "#00F5D4",
      background: "#090E1A"
    });
  }

  function openModal() {
    modal.classList.add("active");
    renderModalQr();
  }

  function closeModal() {
    modal.classList.remove("active");
  }

  if (openModalBtn) openModalBtn.addEventListener("click", openModal);
  if (heroDownloadBtn) heroDownloadBtn.addEventListener("click", openModal);
  if (closeModalBtn) closeModalBtn.addEventListener("click", closeModal);

  if (showProfileQrBtn) {
    showProfileQrBtn.addEventListener("click", () => {
      activeTab = "profile";
      modalTabs.forEach(t => t.classList.toggle("active", t.getAttribute("data-tab") === "profile"));
      openModal();
    });
  }

  // Close on outside click
  modal.addEventListener("click", (e) => {
    if (e.target === modal) closeModal();
  });

  // Modal tab switcher
  modalTabs.forEach(tab => {
    tab.addEventListener("click", () => {
      modalTabs.forEach(t => t.classList.remove("active"));
      tab.classList.add("active");
      activeTab = tab.getAttribute("data-tab");
      renderModalQr();
    });
  });

  // Copy Link Button
  if (copyLinkBtn) {
    copyLinkBtn.addEventListener("click", () => {
      const url = window.location.origin + "/download/Nearby-Radar-v1.0.0.apk";
      navigator.clipboard.writeText(url).then(() => {
        copyLinkBtn.textContent = "Copied!";
        setTimeout(() => copyLinkBtn.textContent = "Copy Link", 2000);
      });
    });
  }

  // Global helper invoked from Profile Studio
  window.openDownloadModalWithProfile = function (profile) {
    savedProfile = profile;
    activeTab = "android";
    modalTabs.forEach(t => t.classList.toggle("active", t.getAttribute("data-tab") === "android"));
    openModal();
  };
}
