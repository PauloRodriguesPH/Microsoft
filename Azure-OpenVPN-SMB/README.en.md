# OpenVPN on Azure as a workaround for blocked SMB (TCP 445)

Anonymized write-up of a real workaround for a **small company** ("Contoso", ~20 users, ~500 GB) that moved its file server to **Azure Files** and found out that **some ISPs block outbound TCP 445**, leaving remote workers without access.

## Idea

A small **Linux VM in Azure** (same region as the storage account) runs **OpenVPN on TCP 853**. The VPN is only a **bypass**: users whose ISP does not block 445 still connect directly. Users who are blocked connect to the VPN, and **only the storage traffic** (split tunnel) leaves through the VM, from inside Azure, where 445 is not blocked.

```
User WITHOUT block ───────────────── TCP 445 ─────────────────►  Azure Files
User WITH block    ── OpenVPN TCP 853 ──► OpenVPN VM ──NAT──► TCP 445 ─┘
```

The VM is hardened so it cannot be used as a general relay: its firewall forwards **only TCP 445 to the storage IP**, and an Azure NSG outbound rule denies the rest of the internet egress.

## Why not the alternatives

- **Azure VPN Gateway (point-to-site):** high fixed monthly cost for this size (see `docs/01-custos.md`).
- **pfSense from the Azure Marketplace:** hourly license charge.
- **SMB over QUIC:** not supported directly by Azure Files (needs a Windows Server with Azure File Sync).

## Cost (rough)

B1ms VM + disk + public IP: roughly **US$ 30-35/month** (estimate), plus egress (first 100 GB/month free, then US$ 0.181/GB from Brazil South). Prices checked in October 2026, **verify in the Azure pricing calculator**.

## Documentation

The step-by-step guide is in Portuguese, under [`docs/`](docs/): Azure resources (resource group, tags, network, VM, NSG), OpenVPN server, VM firewall and NSG outbound rules, Windows clients, monitoring/alerts/budget, tests, operations and security limits.

## Notes

- All IPs and names are examples (`203.0.113.10`, `198.51.100.20` are documentation ranges).
- The scripts consolidate commands that were run manually, one by one. **They were not tested end to end as single scripts. Test in a lab VM first.**
- Never commit `.ovpn` profiles, private keys or storage account keys.

License: MIT.
