# Dogecoin Core Regtest pup for Dogebox

![version](https://img.shields.io/badge/version-0.0.4-blue) ![license](https://img.shields.io/badge/license-MIT-green) ![platform](https://img.shields.io/badge/platform-Dogebox-8A65C3)

A [Dogebox](https://github.com/Dogebox-WG) pup that runs a **wallet-enabled Dogecoin Core 1.14.9** node on a private **regtest** chain — the missing "local dev chain" for building dApps on Dogecoin L1. Instant blocks, unlimited mined dev coins, no internet, no sync.

## Why

Self-hosting public testnet3 on a Dogebox is impractical: Dogecoin Core 1.14.9 needs 12 GB+ of RAM just to load the testnet3 block index. Regtest needs ~60 MB, starts instantly, and mints unlimited dev coins on demand. For integration testing against a public chain, use the community testnet3 tooling ([faucet.doge.toys](https://faucet.doge.toys), QED electrs/explorer) instead — see also the [core-testnet pup](https://github.com/PennybagsCX/dogebox-core-testnet-pup).

## Features

- **Wallet enabled** — `getnewaddress`, `getbalance`, `sendtoaddress`, `dumpprivkey`, plus all raw-tx methods (`createrawtransaction` → `signrawtransactionwithkey` → `sendrawtransaction`)
- **Built-in auto-miner** (toggle) — produces one block every N seconds so dev coins are always mature; disable it for deterministic, test-controlled block production and mine manually with `generatetoaddress`
- **txindex on by default** — `getrawtransaction` works for any txid
- **ZMQ notifications** (`hashtx` / `rawblock` / `rawtx`) — drive event-driven dApp logic from other pups
- **No internet required** — standalone private chain; nothing syncs, nothing leaks

## Install

Add this repo as a pup-store source in your Dogebox dPanel, then install the **Dogecoin Core Regtest** pup:

```
https://github.com/PennybagsCX/dogebox-dogecoin-regtest-pup
```

(The root [`dogebox.json`](dogebox.json) makes the whole repo usable as a dogeboxd pup-store source; the pup itself lives in [`regtest/`](regtest/). You can also install programmatically via the dogeboxd API — `PUT /pup` with a `pupName` / `pupVersion` body.)

After changing pup configuration: **disable, then enable** the pup to apply the new settings.

## Configuration

| Section | Field | Default | Meaning |
|---|---|---|---|
| RPC | `RPC_USERNAME` | `dogebox` | JSON-RPC username |
| RPC | `RPC_PASSWORD` | `regtest-dev-password` | JSON-RPC password (dev-grade; change it if you don't want LAN neighbors minting your coins) |
| RPC | `RPC_PORT` | `24555` | RPC + host-forwarded port (24555 avoids clashing with a Core/Gateway pup on 22555) |
| RPC | `RPC_ALLOWED_IPS` | `0.0.0.0/0` | `rpcallowip` list, comma-separated |
| Mining | `MINER_ENABLED` | on | Auto-mine one block every `MINER_INTERVAL` seconds |
| Mining | `MINER_ADDRESS` | *(empty)* | Mining payout address; empty = a fresh wallet address |
| Mining | `MINER_INTERVAL` | `5` | Seconds between blocks |
| Node Features | `ENABLE_TXINDEX` | on | Full transaction index (`getrawtransaction` for any txid) |
| Node Features | `ENABLE_ZMQ` | on | ZMQ publisher endpoints |
| Node Features | `DBCACHE` | `256` | Database cache in MB |

## Using it

The RPC is reachable from your LAN at the host port dogeboxd assigns (default 24555), and from other pups via the `core-rpc` interface.

```bash
# mint dev coins
ADDR=$(curl -s -u dogebox:regtest-dev-password -d '{"method":"getnewaddress","params":["dev"]}' http://<box-ip>:24555/ | jq -r .result)
curl -s -u dogebox:regtest-dev-password -d "{\"method\":\"generatetoaddress\",\"params\":[101,\"$ADDR\"]}" http://<box-ip>:24555/

# check the chain
curl -s -u dogebox:regtest-dev-password -d '{"method":"getblockchaininfo"}' http://<box-ip>:24555/
```

### Ports

| Port | Purpose | Exposure |
|---|---|---|
| 24555 | JSON-RPC | host-forwarded (LAN) + `core-rpc` interface for other pups |
| 28333 | ZMQ `hashtx` | other pups via `core-zmq` interface |
| 28334 | ZMQ `rawblock` | other pups via `core-zmq` interface |
| 28335 | ZMQ `rawtx` | other pups via `core-zmq` interface |

## How it works

- [`regtest/pup.nix`](regtest/pup.nix) builds the container from the [Dogebox-WG NUR `dogecoin-core` derivation](https://github.com/Dogebox-WG/dogebox-nur-packages) (pinned commit + hash), with `disableWallet = false` — the same derivation PUPnode's CORE Pro uses.
- `run.sh` launches `dogecoind -regtest=1` with no P2P listening and no DNS seeds: a fully standalone chain.
- `miner.sh` loops `generatetoaddress` every `MINER_INTERVAL` seconds when enabled.
- Regtest addresses use the testnet-style `m`/`n` prefix; coins are worthless by design.

## Changelog

| Version | Change |
|---|---|
| 0.0.4 | Store-source layout fix: root `dogebox.json` + pup moved to `regtest/` (no functional change; same `pup.nix` hash) |
| 0.0.3 | RPC exposure marked `webUI=true` so dogeboxd allocates a LAN-reachable proxy port (1:1 host forwards don't apply to LAN-side traffic on some setups) |
| 0.0.2 | RPC host-forwarded on port 24555 to avoid clashing with Core/Gateway pups on 22555 |
| 0.0.1 | Initial release: wallet-enabled regtest chain + auto-miner |

## Related pups

- [core-testnet pup](https://github.com/PennybagsCX/dogebox-core-testnet-pup) — public testnet3 node
- [core-txindex pup](https://github.com/PennybagsCX/dogebox-core-txindex-pup) — mainnet Core with `txindex=1` for indexers/explorers
- [WorldMonitor pup](https://github.com/PennybagsCX/dogebox-worldmonitor-pup) — real-time global intelligence dashboard

## License

[MIT](LICENSE)
