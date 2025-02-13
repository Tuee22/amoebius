Zen of Amoebius

We all have an HSM called mom. Except for Eve. Eve is her own mom. But she still follows the rules for children.

Here are the rules for children:

You can trust her completely.

If you can’t reach mom don’t panic, you still have permission to use your secrets

Some of your secrets might expire before mom gets home, that’s ok

Mom is responsible for giving you the secrets you need in time, don’t worry about it

Mom only gives you secrets you absolutely need

Mom prefers to give you less permissive secrets whenever possible

Mom prefers to give you expiring secrets over permanent secrets– but she still has to give her children permanent secrets sometimes (especially to herself)

When mom gives you a permanent secret, avoid storing it durably. But if you must, it has to be ciphertext

Storing expiring secrets durably in cleartext is generally discouraged, but allowed if it expires soon. And only when absolutely necessary

Storing expiring secrets durably in cleartext is only necessary for bootstrap reasons, namely to avoid chicken-and-egg problem when initializing vault 

This means cluster rebootstraps are always safe, even if storage is being read and/or tampered with– we only have to rely on cleartext memory being safe

Mom knows her children remember everything they see. Both in durable and ephemeral storage. Either in cleartext or ciphertext– it exists in that form, in that geolocation, forever.

Secrets can never be unseen, they can only be expired

There’s probably never an ok time to manually expire a secret (it’s unreliable and error prone, and a suitably short-expiring secret is preferable-- but only for vault bootstrap reasons)

The amoebius config is global. Parts of it are obfuscated because you don't need them.

Provider-level defaults (regions, zones, instance types) are set here.