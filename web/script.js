const body = document.body;
const topbar = document.querySelector('#topbar');
const progressLine = document.querySelector('#progress-line');
const heroBackdrop = document.querySelector('[data-parallax]');
const revealItems = document.querySelectorAll('.reveal');
const menuToggle = document.querySelector('#menu-toggle');
const mobileMenu = document.querySelector('#mobile-menu');
const audioToggle = document.querySelector('#audio-toggle');
const audioLabel = audioToggle?.querySelector('.audio-label');
const ambientAudio = document.querySelector('#ambient-audio');
const trailer = document.querySelector('#trailer');
const trailerPlay = document.querySelector('#trailer-play');
const lightbox = document.querySelector('#lightbox');
const lightboxImage = document.querySelector('#lightbox-image');
const lightboxTitle = document.querySelector('#lightbox-title');
const toast = document.querySelector('#toast');

let toastTimer;
let lastFocusedElement;

const showToast = (message) => {
  if (!toast) return;
  toast.textContent = message;
  toast.classList.add('visible');
  window.clearTimeout(toastTimer);
  toastTimer = window.setTimeout(() => toast.classList.remove('visible'), 4200);
};

const updateScrollChrome = () => {
  const scrollTop = window.scrollY;
  const scrollable = document.documentElement.scrollHeight - window.innerHeight;
  const progress = scrollable > 0 ? (scrollTop / scrollable) * 100 : 0;
  if (progressLine) progressLine.style.width = `${progress}%`;
  topbar?.classList.toggle('scrolled', scrollTop > 24);

  if (heroBackdrop && !window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    heroBackdrop.style.setProperty('--parallax', `${Math.min(scrollTop * 0.11, 90)}px`);
  }
};

window.addEventListener('scroll', updateScrollChrome, { passive: true });
window.addEventListener('resize', updateScrollChrome, { passive: true });
updateScrollChrome();

if ('IntersectionObserver' in window) {
  const revealObserver = new IntersectionObserver((entries, observer) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add('is-visible');
      observer.unobserve(entry.target);
    });
  }, { threshold: 0.12, rootMargin: '0px 0px -35px' });
  revealItems.forEach((item) => revealObserver.observe(item));
} else {
  revealItems.forEach((item) => item.classList.add('is-visible'));
}

const closeMenu = () => {
  if (!mobileMenu || !menuToggle) return;
  mobileMenu.hidden = true;
  menuToggle.setAttribute('aria-expanded', 'false');
};

menuToggle?.addEventListener('click', () => {
  const isOpen = menuToggle.getAttribute('aria-expanded') === 'true';
  menuToggle.setAttribute('aria-expanded', String(!isOpen));
  mobileMenu.hidden = isOpen;
});

mobileMenu?.querySelectorAll('a').forEach((link) => link.addEventListener('click', closeMenu));

const syncAudioLabel = (isPlaying) => {
  if (!audioToggle) return;
  audioToggle.setAttribute('aria-pressed', String(isPlaying));
  audioToggle.setAttribute('title', isPlaying ? 'Desativar trilha ambiente' : 'Ativar trilha ambiente');
  if (audioLabel) audioLabel.textContent = isPlaying ? 'Som on' : 'Som off';
};

audioToggle?.addEventListener('click', async () => {
  if (!ambientAudio) return;
  if (ambientAudio.paused) {
    try {
      await ambientAudio.play();
      syncAudioLabel(true);
    } catch {
      showToast('O áudio precisa ser liberado pelo navegador para começar.');
    }
  } else {
    ambientAudio.pause();
    syncAudioLabel(false);
  }
});

const toggleTrailer = () => {
  if (!trailer) return;
  if (trailer.paused) {
    trailer.play().then(() => trailer.closest('.trailer')?.classList.add('is-playing')).catch(() => showToast('Não foi possível reproduzir o recorte agora.'));
  } else {
    trailer.pause();
    trailer.closest('.trailer')?.classList.remove('is-playing');
  }
};

trailerPlay?.addEventListener('click', toggleTrailer);
trailer?.addEventListener('click', (event) => {
  if (event.target === trailer) toggleTrailer();
});
trailer?.addEventListener('pause', () => trailer.closest('.trailer')?.classList.remove('is-playing'));
trailer?.addEventListener('play', () => trailer.closest('.trailer')?.classList.add('is-playing'));

const openLightbox = (button) => {
  if (!lightbox || !lightboxImage || !lightboxTitle) return;
  lastFocusedElement = document.activeElement;
  lightboxImage.src = button.dataset.gallerySrc;
  lightboxImage.alt = button.dataset.galleryAlt || '';
  lightboxTitle.textContent = button.dataset.galleryAlt || '';
  lightbox.hidden = false;
  body.classList.add('is-locked');
  lightbox.querySelector('.lightbox-close')?.focus();
};

const closeLightbox = () => {
  if (!lightbox) return;
  lightbox.hidden = true;
  body.classList.remove('is-locked');
  if (lightboxImage) lightboxImage.src = '';
  lastFocusedElement?.focus?.();
};

document.querySelectorAll('[data-gallery-src]').forEach((button) => button.addEventListener('click', () => openLightbox(button)));
document.querySelectorAll('[data-close-lightbox]').forEach((element) => element.addEventListener('click', closeLightbox));

document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') {
    closeMenu();
    if (lightbox && !lightbox.hidden) closeLightbox();
  }
});

document.querySelectorAll('.placeholder-action').forEach((button) => {
  button.addEventListener('click', () => showToast(button.dataset.message || 'Este canal será adicionado em breve.'));
});

document.querySelectorAll('a[href^="#"]').forEach((link) => {
  link.addEventListener('click', (event) => {
    const target = document.querySelector(link.getAttribute('href'));
    if (!target) return;
    event.preventDefault();
    target.scrollIntoView({ behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth', block: 'start' });
  });
});
