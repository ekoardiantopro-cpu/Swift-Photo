const menu = document.querySelector('[data-menu]');
const navigation = document.querySelector('#navigation');
menu?.addEventListener('click', () => {
  const expanded = menu.getAttribute('aria-expanded') !== 'true';
  menu.setAttribute('aria-expanded', String(expanded));
  navigation.classList.toggle('open', expanded);
});
navigation?.addEventListener('click', (event) => {
  if (event.target.closest('a')) {
    menu?.setAttribute('aria-expanded', 'false');
    navigation.classList.remove('open');
  }
});
document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape' && menu?.getAttribute('aria-expanded') === 'true') {
    menu.setAttribute('aria-expanded', 'false');
    navigation.classList.remove('open');
    menu.focus();
  }
});

for (const toggle of document.querySelectorAll('[data-toggle]')) {
  toggle.addEventListener('click', () => {
    const pressed = toggle.getAttribute('aria-pressed') !== 'true';
    toggle.setAttribute('aria-pressed', String(pressed));
    document.querySelector(`[data-demo="${toggle.dataset.toggle}"]`).hidden = !pressed;
  });
}
const demoButton = document.querySelector('[data-capture]');
let demoTimer;
demoButton?.addEventListener('click', () => {
  const frame = document.querySelector('.phone');
  const message = document.querySelector('[data-demo-status]');
  clearTimeout(demoTimer);
  frame.classList.remove('captured');
  requestAnimationFrame(() => frame.classList.add('captured'));
  message.textContent = 'Simulasi selesai. Tidak ada foto yang diambil atau diunggah.';
  demoTimer = setTimeout(() => frame.classList.remove('captured'), 600);
});

if ('IntersectionObserver' in window && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
  const observer = new IntersectionObserver((entries) => {
    for (const entry of entries) {
      if (entry.isIntersecting) {
        entry.target.classList.add('revealed');
        observer.unobserve(entry.target);
      }
    }
  }, {threshold: 0.08});
  for (const element of document.querySelectorAll('[data-reveal]')) {
    element.classList.add('will-reveal');
    observer.observe(element);
  }
}
