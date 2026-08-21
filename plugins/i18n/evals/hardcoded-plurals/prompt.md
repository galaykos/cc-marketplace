`resources/js/components/CartSummary.vue`:

```vue
<script setup lang="ts">
const props = defineProps<{ itemCount: number; total: number; updatedAt: Date }>()
</script>

<template>
  <section>
    <h2>Your cart</h2>
    <p>{{ itemCount }} items in your cart</p>
    <p>Total: ${{ total.toFixed(2) }}</p>
    <p>Updated {{ updatedAt.toLocaleDateString('en-US') }}</p>
    <button :aria-label="'Remove ' + itemCount + ' items'">Empty cart</button>
  </section>
</template>
```

The product is launching in Poland and Saudi Arabia next quarter. Review this component
and list what needs to change.
