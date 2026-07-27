<?php
class PaymentController {
    public function store($request) {
        try {
            $charge = $this->gateway->charge($request->amount);
        } catch (GatewayException $e) {
            Log::error('charge failed', ['id' => $request->id]);
            throw $e;
        }
    }
}
