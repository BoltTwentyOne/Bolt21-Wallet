---
css: ["blog.css"]
title: "BOLT12 Offers: Reusable Lightning Addresses That Never Expire"
description: "Learn about BOLT12 offers, the revolutionary Lightning Network payment standard that enables reusable payment addresses. Perfect for merchants, miners, and content creators."
date: 2024-12-05
author: 'Bolt21 Team'
tags: ['bolt12', 'lightning-network', 'technology', 'payments']
image: '/images/blog/bolt12-offers-explained.png'
---

# BOLT12 Offers: Reusable Lightning Addresses That Never Expire

If you've used Lightning Network before, you know the frustration: generate an invoice, share it, but it expires in an hour. Need another payment? Generate a new invoice. It's tedious.

BOLT12 offers solve this problem completely.

## What is BOLT12?

BOLT12 is a new Lightning Network specification that introduces **Offers** - reusable payment endpoints that never expire.

Think of it like:
- **BOLT11 (old)**: A check made out for a specific amount that expires
- **BOLT12 (new)**: Your bank account number - share it once, receive unlimited payments

## The Problem with BOLT11 Invoices

Current Lightning invoices (BOLT11) have several limitations:

### Single-Use Only
Each invoice can only be paid once. Want to receive multiple payments? Generate multiple invoices.

### Expiration
Most invoices expire in 1 hour. If your customer waits too long, the invoice is invalid.

### Fixed Amounts
Invoices specify an exact amount. If you want to receive variable amounts, you need to generate custom invoices for each payment.

### Privacy Concerns
Invoices contain your node's public key, linking all your payments together.

## How BOLT12 Offers Work

A BOLT12 offer is a compact QR code or text string that you can share publicly.

### The Flow

1. **Merchant creates an offer** - This is the reusable payment endpoint
2. **Customer scans the offer** - Using their Lightning wallet
3. **Customer's wallet requests an invoice** - Behind the scenes, automatically
4. **Merchant's wallet sends a custom invoice** - Generated on the fly
5. **Payment completes** - Customer pays the invoice
6. **Everyone's happy** - No expiration, no manual invoice generation

### The Magic

The offer itself contains minimal information - it's just an endpoint. The actual invoice is generated when needed, providing:
- Fresh, non-expired invoices every time
- Custom amounts (customer can choose or merchant can specify)
- Improved privacy (each invoice is unique)
- Infinite reusability

## Benefits of BOLT12 Offers

### For Merchants

**Print Once, Use Forever**
- Put your offer QR code on business cards
- Display at your physical location
- Embed on your website
- No more updating expired QR codes

**Variable Amounts**
Customers can send any amount, or you can specify a minimum/maximum.

**Simplified Accounting**
All payments come to the same offer - easier to track and reconcile.

### For Content Creators

**Donations Made Easy**
Put your offer in:
- YouTube descriptions
- Podcast show notes
- Blog sidebars
- Social media bios

Fans can support you with any amount, anytime.

### For Bitcoin Miners

**Set and Forget**
Configure your mining pool payout once with your BOLT12 offer. Receive daily payouts indefinitely without updating anything.

Ocean Mining Pool supports BOLT12 offers, making Bolt21 the perfect wallet for miners.

### For Everyone

**Better Privacy**
Each payment uses a fresh invoice with unique payment details, making it harder to link your transactions.

**Simpler Experience**
Share one QR code instead of generating new invoices constantly.

**No Expiration Worries**
Your offer works today, tomorrow, and forever.

## BOLT12 vs Other Solutions

### Lightning Address (user@domain.com)

**Similarities:**
- Both provide reusable payment endpoints
- Both enable variable amount payments

**Differences:**
- Lightning Address requires a web server and domain
- BOLT12 offers work with just a wallet
- Lightning Address relies on centralized DNS
- BOLT12 is native to Lightning protocol

### LNURL

**Similarities:**
- Both enable advanced Lightning features
- Both support reusable payments

**Differences:**
- LNURL requires HTTP servers
- BOLT12 is pure Lightning protocol
- BOLT12 offers better privacy
- BOLT12 is more decentralized

### Traditional Bitcoin Addresses

**Similarities:**
- Both can be reused (though you shouldn't reuse Bitcoin addresses)

**Differences:**
- BOLT12 is for Lightning (instant, low-fee)
- Bitcoin addresses are on-chain (slower, higher fees)
- BOLT12 offers better privacy than address reuse

## Real-World Use Cases

### Coffee Shop
Display a BOLT12 offer QR code at the register:
1. Customer scans with their wallet
2. Enters the amount (or amount is preset)
3. Pays instantly
4. Coffee delivered

No payment processor, no fees, no chargebacks.

### Freelancer
Include your BOLT12 offer in your email signature or invoice:
- Clients can pay immediately
- Works for any amount
- No waiting for bank transfers
- No international payment fees

### Podcast Donations
Put your offer in show notes:
- Listeners can donate during or after listening
- Any amount, from 1 sat to millions
- No Patreon fees
- Direct to your wallet

### Mining Payouts (Ocean + Bolt21)
Set your Bolt21 BOLT12 offer as your Ocean payout address:
- Receive daily payouts automatically
- No minimum payout (as low as 2,000 sats)
- Zero Lightning fees
- Complete self-custody

## How to Create a BOLT12 Offer with Bolt21

It's incredibly simple:

1. **Open Bolt21**
2. **Tap "Receive"**
3. **Select "BOLT12 Offer"**
4. **Share the QR code or text**

That's it. Your offer is ready to receive unlimited payments.

### Customization Options

You can configure:
- Description (what the payment is for)
- Amount (fixed or variable)
- Expiry (though most offers never expire)

## The Future of Lightning Payments

BOLT12 is still relatively new, with wallet support growing throughout 2024. But it's quickly becoming the standard for:

- Merchant payments
- Donation/tipping platforms
- Subscription services
- Mining pool payouts
- Any scenario requiring reusable payment endpoints

### Current Support

**Wallets:**
- Bolt21 (full support)
- Core Lightning (reference implementation)
- Phoenix (coming soon)
- Others adding support throughout 2024

**Services:**
- Ocean Mining Pool
- BTCPay Server (in development)
- Various merchant solutions

## Common Questions

**Can I use one offer for multiple purposes?**
Yes! You can use the same offer for your coffee shop, online store, and donations. However, separate offers make accounting easier.

**What if my wallet is offline?**
Your wallet needs to be online (or using a Lightning Service Provider) to generate invoices when someone tries to pay your offer. Bolt21 handles this automatically.

**Are offers backward compatible?**
BOLT11 wallets can't pay BOLT12 offers (yet). Most modern wallets are adding support. In the meantime, you can offer both BOLT11 invoices and BOLT12 offers.

**Can I cancel an offer?**
You can stop responding to payment requests for an offer, effectively "canceling" it. But the offer string itself can't be revoked once shared.

## Getting Started with BOLT12

Ready to experience the future of Lightning payments?

1. **Download Bolt21** - Native BOLT12 support
2. **Create your offer** - Takes 30 seconds
3. **Start sharing** - Put it everywhere
4. **Receive payments** - Unlimited, forever

BOLT12 offers represent a massive leap forward in Lightning usability. If you've been frustrated with expiring invoices and manual payment requests, BOLT12 is the solution you've been waiting for.

**One offer. Unlimited payments. Forever.**

---

*Related Articles:*
- [Lightning Network Basics: Fast, Cheap Bitcoin Payments](/blog/lightning-network-basics)
- [Bitcoin Payments for Merchants: Complete Guide](/blog/bitcoin-payments-guide)
- [Understanding BOLT12 in the Docs](/docs/bolt12)
