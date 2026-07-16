// Presence of src/components/ satisfies the "component paths" detection signal.
export function Button({ label }: { label: string }) {
  return <button type="button">{label}</button>;
}
