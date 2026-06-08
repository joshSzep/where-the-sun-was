document.documentElement.classList.add('js');

const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
const pointer = { x: 0.5, y: 0.45, active: false };

window.addEventListener('pointermove', (event) => {
  pointer.x = event.clientX / Math.max(window.innerWidth, 1);
  pointer.y = event.clientY / Math.max(window.innerHeight, 1);
  pointer.active = true;
}, { passive: true });

function fitCanvas(canvas) {
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  const rect = canvas.getBoundingClientRect();
  canvas.width = Math.max(1, Math.floor(rect.width * dpr));
  canvas.height = Math.max(1, Math.floor(rect.height * dpr));
  const ctx = canvas.getContext('2d');
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  return { ctx, width: rect.width, height: rect.height, dpr };
}

function seededRandom(seed) {
  let value = seed % 2147483647;
  if (value <= 0) value += 2147483646;
  return () => {
    value = value * 16807 % 2147483647;
    return (value - 1) / 2147483646;
  };
}

function createStarfield(canvas) {
  if (!canvas) return;
  const random = seededRandom(190873);
  let ctx;
  let width = 0;
  let height = 0;
  let stars = [];

  function resize() {
    const fit = fitCanvas(canvas);
    ctx = fit.ctx;
    width = fit.width;
    height = fit.height;
    const count = Math.round(Math.min(520, Math.max(240, width * height / 2200)));
    stars = Array.from({ length: count }, () => ({
      x: random(),
      y: random(),
      z: 0.25 + random() * 1.8,
      r: 0.35 + random() * 1.25,
      warm: random(),
      pulse: random() * Math.PI * 2
    }));
  }

  function draw(time = 0) {
    if (!ctx) return;
    const scroll = window.scrollY || 0;
    ctx.clearRect(0, 0, width, height);
    ctx.fillStyle = '#020100';
    ctx.fillRect(0, 0, width, height);

    for (const star of stars) {
      const driftX = (pointer.x - 0.5) * 16 * star.z;
      const driftY = (pointer.y - 0.5) * 8 * star.z + scroll * 0.012 * star.z;
      const x = (star.x * width + driftX + width) % width;
      const y = (star.y * height + driftY + height) % height;
      const twinkle = reduceMotion ? 1 : 0.72 + Math.sin(time * 0.0012 + star.pulse) * 0.28;
      const alpha = (0.24 + star.z * 0.26) * twinkle;
      const hue = star.warm > 0.82 ? '255,185,108' : star.warm < 0.08 ? '156,203,208' : '241,226,205';

      ctx.beginPath();
      ctx.fillStyle = `rgba(${hue}, ${alpha})`;
      ctx.arc(x, y, star.r, 0, Math.PI * 2);
      ctx.fill();
    }

    if (!reduceMotion) requestAnimationFrame(draw);
  }

  resize();
  window.addEventListener('resize', resize);
  requestAnimationFrame(draw);
}

function createSphere(canvas, options = {}) {
  if (!canvas) return;
  let ctx;
  let width = 0;
  let height = 0;
  let stars = [];
  const random = seededRandom(options.hero ? 76191 : 8837);

  function resize() {
    const fit = fitCanvas(canvas);
    ctx = fit.ctx;
    width = fit.width;
    height = fit.height;
    const count = options.hero ? 420 : 260;
    stars = Array.from({ length: count }, () => ({
      x: random(),
      y: random(),
      r: 0.35 + random() * (options.hero ? 1.35 : 0.95),
      a: 0.12 + random() * 0.72,
      warm: random()
    }));
  }

  function drawArc(cx, cy, radius, start, end, yScale, tilt, time, glow) {
    const segments = 84;
    let previous = null;
    for (let i = 0; i <= segments; i += 1) {
      const t = start + (end - start) * (i / segments);
      const wobble = Math.sin(t * 3.1 + tilt) * radius * 0.018;
      const x = cx + Math.cos(t) * (radius + wobble);
      const y = cy + Math.sin(t) * radius * yScale + Math.cos(t + tilt) * radius * 0.05;
      if (previous) {
        const seamPulse = Math.max(0, Math.sin(time * 0.0015 + i * 0.18 + tilt));
        ctx.strokeStyle = `rgba(255, ${150 + seamPulse * 70}, ${72 + seamPulse * 45}, ${0.24 + glow * 0.34 + seamPulse * 0.2})`;
        ctx.lineWidth = 0.75 + seamPulse * 0.9 + glow * 0.8;
        ctx.beginPath();
        ctx.moveTo(previous.x, previous.y);
        ctx.lineTo(x, y);
        ctx.stroke();
      }
      previous = { x, y };
    }

    for (let i = 0; i < 4; i += 1) {
      const t = start + ((time * 0.00008 + i * 0.29 + tilt) % 1) * (end - start);
      const x = cx + Math.cos(t) * radius;
      const y = cy + Math.sin(t) * radius * yScale + Math.cos(t + tilt) * radius * 0.05;
      const flare = 0.6 + Math.sin(time * 0.004 + i) * 0.4;
      ctx.fillStyle = `rgba(255, 198, 126, ${0.45 + flare * 0.4})`;
      ctx.shadowColor = 'rgba(255, 146, 64, 0.9)';
      ctx.shadowBlur = 14 + flare * 12;
      ctx.beginPath();
      ctx.arc(x, y, 1.5 + flare * 2.2 + glow, 0, Math.PI * 2);
      ctx.fill();
      ctx.shadowBlur = 0;
    }
  }

  function draw(time = 0) {
    if (!ctx) return;
    const scroll = window.scrollY || 0;
    ctx.clearRect(0, 0, width, height);

    const gradient = ctx.createLinearGradient(0, 0, 0, height);
    gradient.addColorStop(0, '#020100');
    gradient.addColorStop(0.55, '#080403');
    gradient.addColorStop(1, '#020100');
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, width, height);

    for (const star of stars) {
      const x = (star.x * width + (pointer.x - 0.5) * 18 + width) % width;
      const y = (star.y * height + (pointer.y - 0.5) * 8 + scroll * 0.018 + height) % height;
      const hue = star.warm > 0.7 ? '255,161,81' : '241,226,205';
      ctx.fillStyle = `rgba(${hue}, ${star.a})`;
      ctx.beginPath();
      ctx.arc(x, y, star.r, 0, Math.PI * 2);
      ctx.fill();
    }

    const cx = width * (options.hero ? 0.5 : 0.52);
    const cy = height * (options.hero ? 0.43 : 0.48);
    const radius = Math.min(width, height) * (options.hero ? 0.31 : 0.34);
    const glow = pointer.active ? 0.6 + Math.abs(pointer.x - 0.5) * 0.75 : 0.28;

    const aura = ctx.createRadialGradient(cx, cy, radius * 0.9, cx, cy, radius * 1.95);
    aura.addColorStop(0, 'rgba(255, 137, 55, 0)');
    aura.addColorStop(0.35, 'rgba(255, 137, 55, 0.08)');
    aura.addColorStop(0.72, 'rgba(255, 137, 55, 0.025)');
    aura.addColorStop(1, 'rgba(255, 137, 55, 0)');
    ctx.fillStyle = aura;
    ctx.beginPath();
    ctx.arc(cx, cy, radius * 2, 0, Math.PI * 2);
    ctx.fill();

    const sphere = ctx.createRadialGradient(cx - radius * 0.32, cy - radius * 0.38, radius * 0.2, cx, cy, radius * 1.1);
    sphere.addColorStop(0, '#050302');
    sphere.addColorStop(0.68, '#010100');
    sphere.addColorStop(1, '#000000');
    ctx.fillStyle = sphere;
    ctx.beginPath();
    ctx.arc(cx, cy, radius, 0, Math.PI * 2);
    ctx.fill();

    ctx.save();
    ctx.beginPath();
    ctx.arc(cx, cy, radius * 0.998, 0, Math.PI * 2);
    ctx.clip();
    ctx.globalCompositeOperation = 'screen';
    drawArc(cx - radius * 0.04, cy + radius * 0.03, radius * 1.04, -2.78, 0.2, 0.34, 0.8, time, glow);
    drawArc(cx + radius * 0.25, cy - radius * 0.02, radius * 0.96, -1.42, 1.66, 0.9, 1.9, time, glow);
    drawArc(cx - radius * 0.1, cy + radius * 0.18, radius * 0.92, -0.02, 2.6, 0.21, 2.7, time, glow);
    drawArc(cx + radius * 0.68, cy + radius * 0.04, radius * 0.62, -1.38, 1.35, 1.12, 3.5, time, glow);
    ctx.restore();

    ctx.strokeStyle = 'rgba(255, 191, 120, 0.08)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.arc(cx, cy, radius, 0, Math.PI * 2);
    ctx.stroke();

    if (!reduceMotion) requestAnimationFrame(draw);
  }

  resize();
  window.addEventListener('resize', resize);
  requestAnimationFrame(draw);
}

const phases = {
  arrival: {
    title: 'Arrival',
    body: 'The probe enters the origin system with confidence in models, boundaries, and staged reporting.',
    confidence: 'Preliminary',
    boundary: 'External',
    status: 'Classification pending',
    signal: 'Central stellar occlusion'
  },
  contradiction: {
    title: 'Contradiction',
    body: 'Data quality improves while interpretation fails to converge. The issue is not noise. It is the frame.',
    confidence: 'Nonconvergent',
    boundary: 'Unstable',
    status: 'Models retained',
    signal: 'Correct answers, insufficient questions'
  },
  recognition: {
    title: 'Recognition',
    body: 'Archive residue and interface traces imply shared lineage. The structure is not alien in the way the mission requires.',
    confidence: 'Reframed',
    boundary: 'Kinship detected',
    status: 'Observer implicated',
    signal: 'The branch that stayed'
  },
  participation: {
    title: 'Participation',
    body: 'Classification stops being the highest form of contact. Compatibility becomes more useful than closure.',
    confidence: 'Open',
    boundary: 'Permeable',
    status: 'Continue',
    signal: 'Separation no longer primary'
  }
};

function wirePhases() {
  const buttons = document.querySelectorAll('[data-phase]');
  const title = document.querySelector('[data-readout-title]');
  const body = document.querySelector('[data-readout-body]');
  const fields = {
    confidence: document.querySelector('[data-telemetry="confidence"]'),
    boundary: document.querySelector('[data-telemetry="boundary"]'),
    status: document.querySelector('[data-telemetry="status"]'),
    signal: document.querySelector('[data-telemetry="signal"]')
  };

  function setPhase(name) {
    const phase = phases[name] || phases.arrival;
    document.body.dataset.phase = name;
    if (title) title.textContent = phase.title;
    if (body) body.textContent = phase.body;
    Object.entries(fields).forEach(([key, element]) => {
      if (element) element.textContent = phase[key];
    });
    buttons.forEach((button) => {
      button.setAttribute('aria-pressed', button.dataset.phase === name ? 'true' : 'false');
    });
  }

  buttons.forEach((button) => {
    button.addEventListener('click', () => setPhase(button.dataset.phase));
  });

  setPhase('arrival');
}

function wireScrollState() {
  const progress = document.querySelector('.progress-line');
  const chapter = document.querySelector('#chapter-one');
  const meter = document.querySelector('.chapter-meter span');

  function update() {
    const max = Math.max(document.documentElement.scrollHeight - window.innerHeight, 1);
    const ratio = Math.min(1, Math.max(0, window.scrollY / max));
    if (progress) progress.style.transform = `scaleX(${ratio})`;

    if (chapter && meter) {
      const rect = chapter.getBoundingClientRect();
      const total = rect.height + window.innerHeight;
      const read = Math.min(1, Math.max(0, (window.innerHeight - rect.top) / total));
      meter.style.height = `${read * 100}%`;
    }
  }

  update();
  window.addEventListener('scroll', update, { passive: true });
  window.addEventListener('resize', update);
}

function wireReveals() {
  const reveals = document.querySelectorAll('.reveal');
  if (!('IntersectionObserver' in window) || reduceMotion) {
    reveals.forEach((element) => element.classList.add('is-visible'));
    return;
  }

  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add('is-visible');
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: 0.01 });

  reveals.forEach((element) => observer.observe(element));
}

createStarfield(document.querySelector('#ambient-field'));
createSphere(document.querySelector('#entry-field'), { hero: true });
createSphere(document.querySelector('#sphere-canvas'));
wirePhases();
wireScrollState();
wireReveals();
