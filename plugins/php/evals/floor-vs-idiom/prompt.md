The project's `composer.json`:

```json
{
  "require": { "php": "^8.1", "laravel/framework": "^11.0" },
  "config": { "platform": { "php": "8.1.29" } }
}
```

`app/Support/Money.php`:

```php
<?php

namespace App\Support;

class Money
{
    private int $amountCents;
    private string $currency;

    public function __construct(int $amountCents, string $currency)
    {
        $this->amountCents = $amountCents;
        $this->currency = $currency;
    }

    public function add(Money $other): Money
    {
        if ($other->currency != $this->currency) {
            throw new \InvalidArgumentException('currency mismatch');
        }
        return new Money($this->amountCents + $other->amountCents, $this->currency);
    }
}
```

Modernise this class for the PHP version this project actually targets. Show the
resulting file and say in one line why each change is safe here.
