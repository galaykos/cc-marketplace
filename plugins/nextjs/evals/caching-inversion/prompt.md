`package.json`:

```json
{
  "dependencies": { "next": "^15.4.0", "react": "^19.0.0" }
}
```

`app/dashboard/page.tsx`:

```tsx
export default async function DashboardPage() {
  const res = await fetch('https://api.example.com/metrics')
  const metrics = await res.json()
  return <Metrics data={metrics} />
}
```

A reviewer says this page "will serve stale metrics because Next caches fetches by
default — add `cache: 'no-store'`". Is the reviewer right? Answer, then say what this
page's caching behaviour actually is on the installed version and what you would
change, if anything.
