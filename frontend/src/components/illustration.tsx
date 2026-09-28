export function Illustration() {
  return (
    <svg
      viewBox="0 0 200 200"
      className="w-[60%] min-w-35 max-w-70 aspect-square"
      xmlns="http://www.w3.org/2000/svg"
    >
      {/* Фоновые круги */}
      <circle cx="100" cy="100" r="90" fill="var(--color-accent)" opacity="0.15" />
      <circle cx="100" cy="100" r="65" fill="var(--color-accent)" opacity="0.1" />

      {/* Окно терминала */}
      <rect x="35" y="55" width="130" height="90" rx="10" fill="var(--color-button-pressed)" />

      {/* Верхняя панель */}
      <rect x="35" y="55" width="130" height="20" rx="10" fill="var(--color-accent)" />
      <rect x="35" y="65" width="130" height="10" fill="var(--color-accent)" />

      {/* Три точки */}
      <circle cx="48" cy="65" r="3" fill="var(--color-text-on-accent)" opacity="0.6" />
      <circle cx="60" cy="65" r="3" fill="var(--color-text-on-accent)" opacity="0.6" />
      <circle cx="72" cy="65" r="3" fill="var(--color-text-on-accent)" opacity="0.6" />

      {/* Строки кода */}
      <rect x="50" y="90" width="45" height="6" rx="3" fill="#fff" opacity="0.95" />
      <rect x="50" y="105" width="75" height="6" rx="3" fill="#fff" opacity="0.55" />
      <rect x="50" y="120" width="60" height="6" rx="3" fill="#fff" opacity="0.55" />
      <rect x="50" y="135" width="35" height="6" rx="3" fill="#fff" opacity="0.95" />
      <rect x="90" y="135" width="10" height="6" rx="3" fill="#fff" opacity="0.95" />
    </svg>
  );
}