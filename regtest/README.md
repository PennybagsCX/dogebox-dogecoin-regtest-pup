# Dogecoin Core Regtest pup

A [Dogebox](https://github.com/Dogebox-WG) pup that runs a **wallet-enabled Dogecoin Core 1.14.9** node on a private **regtest** chain — the missing "local dev chain" for building dApps on Dogecoin L1.

## Why

Self-hosting public testnet3 on a Dogebox is impractical: dogecoin 1.14.9 needs 12GB+ of RAM just to load the testnet3 block index. Regtest needs ~60MB, starts instantly, and mints unlimited dev coins on demand. For integration testing against a public chain, use the community testnet3 tooling (faucet.doge.toys, QED electrs/explorer) instead.

## Features

- **Wallet enabled** — `getnewaddress`, `getbalance`, `sendtoaddress`, `dumpprivkey`, plus all raw-tx methods (`createrawtransaction` → `signrawtransactionwithkey` → `sendrawtransaction`)
- **Built-in auto-miner** (toggle) — produces one block every N seconds so dev coins are always mature; disable it for deterministic test-controlled block production and mine manually with `generatetoaddress`
- **txindex on** by default — `getrawtransaction` works for any txid
- **ZMQ notifications** (hashtx/rawblock/rawtx) — drive event-driven dApp logic
- **No internet required** — standalone chain, nothing syncs, nothing leaks

## Using it

The RPC is exposed via the `core-rpc` interface (bindable by other pups) and on a host port assigned by dogeboxd. Credentials default to `dogebox` / `regtest-dev-password` — change them in pup config.

```bash
# mint dev coins
ADDR=$(curl -s -u dogebox:regtest-dev-password -d '{"method":"getnewaddress","params":["dev"]}' http://<box-ip>:<host-port>/ | jq -r .result)
curl -s -u dogebox:regtest-dev-password -d "{\"method\":\"generatetoaddress\",\"params\":[101,\"$ADDR\"]}" http://<box-ip>:<host-port>/

# check the chain
curl -s -u dogebox:regtest-dev-password -d '{"method":"getblockchaininfo"}' http://<box-ip>:<host-port>/
```

After changing config: **disable then enable** the pup to apply.

## Notes

- Built on the [Dogebox-WG nur `dogecoin-core` derivation](https://github.com/Dogebox-WG/dogebox-nur-packages) (pinned), `disableWallet = false` — same derivation PUPnode's CORE Pro uses.
- Regtest addresses use the testnet-style `m`/`n` prefix; coins are worthless by design.
- v0.0.1: no metrics/monitor service, no GUI.
