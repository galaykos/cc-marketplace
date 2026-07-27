export function OrderForm() {
  const submit = async (data) => {
    try {
      const res = await fetch('/api/orders', { headers: { Authorization: token } })
      return await res.json()
    } catch (e) {
      console.error('order submit failed', e)
    }
  }
}
