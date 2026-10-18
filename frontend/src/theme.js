const defaults = {
  name: 'Smart College',
  short_name: 'SC',
  primary_color: '#1B4F9C',
  secondary_color: '#F39200',
  accent_color: '#F5A623',
  sidebar_color: '#0E2A4A',
  header_color: '#fffdf8',
  button_style: 'rounded',
  theme: 'light',
};

function readable(hex) {
  const value = String(hex || '').replace('#', '');
  if (value.length !== 6) return '#ffffff';
  const red = parseInt(value.slice(0, 2), 16);
  const green = parseInt(value.slice(2, 4), 16);
  const blue = parseInt(value.slice(4, 6), 16);
  return (red * 299 + green * 587 + blue * 114) / 1000 > 160 ? '#1c1917' : '#ffffff';
}

export function applyTheme(branding = {}) {
  const theme = { ...defaults, ...Object.fromEntries(Object.entries(branding).filter(([, value]) => value)) };
  const root = document.documentElement;
  root.dataset.theme = theme.theme === 'dark' ? 'dark' : 'light';
  root.dataset.buttons = ['square', 'pill', 'rounded'].includes(theme.button_style) ? theme.button_style : 'rounded';
  root.style.setProperty('--primary', theme.primary_color);
  root.style.setProperty('--secondary', theme.secondary_color);
  root.style.setProperty('--accent', theme.accent_color);
  root.style.setProperty('--sidebar', theme.sidebar_color);
  root.style.setProperty('--header', theme.header_color);
  root.style.setProperty('--on-primary', readable(theme.primary_color));
  const radius = theme.button_style === 'square' ? '4px' : theme.button_style === 'pill' ? '999px' : '12px';
  root.style.setProperty('--radius-btn', radius);
  if (theme.name) document.title = theme.name;
  const icon = theme.favicon_url || '/logo.png';
  if (icon) {
    let link = document.querySelector("link[rel='icon']");
    if (!link) {
      link = document.createElement('link');
      link.rel = 'icon';
      document.head.appendChild(link);
    }
    link.href = icon;
  }
}
