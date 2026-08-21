`app/Services/PaymentClient.php`:

```php
<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;

class PaymentClient
{
    public function charge(string $orderId, int $amountCents): array
    {
        $attempts = 0;

        do {
            $attempts++;
            $response = Http::post('https://payments.example.com/v1/charges', [
                'order_id' => $orderId,
                'amount' => $amountCents,
            ]);

            if ($response->successful()) {
                return $response->json();
            }
        } while ($attempts < 3);

        throw new \RuntimeException('charge failed after 3 attempts');
    }
}
```

This runs inside a queued job. Review it.
