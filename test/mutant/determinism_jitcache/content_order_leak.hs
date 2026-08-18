-- mut-48-content-address-field-order-leak: preserve caller field order.
module ContentAddressFieldOrderLeak where

canonicalize :: [(String, String)] -> [(String, String)]
canonicalize = id
