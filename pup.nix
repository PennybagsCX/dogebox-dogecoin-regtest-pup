{ pkgs ? import <nixpkgs> {} }:

let
  storageDirectory = "/storage";

  # Wallet-enabled dogecoin-core from the Dogebox-WG NUR (same derivation
  # PUPnode's CORE Pro uses — pinned commit + sha256).
  dogecoind_bin = pkgs.callPackage (pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/Dogebox-WG/dogebox-nur-packages/6531e850a6e964a9cd4c36671cb9b3b7414d8044/pkgs/dogecoin-core/default.nix";
    sha256 = "sha256-bSl/IKyAV2Gnh7TNDISBVxouQTdI5jmDqTfs6qfdz2w=";
  }) {
    disableWallet = false;  # the whole point of this pup: wallet on for dApp dev
    disableGUI = true;
    disableTests = true;
    enableZMQ = true;
  };

  dogecoind = pkgs.writeScriptBin "run.sh" ''
    #!${pkgs.stdenv.shell}

    RPC_USERNAME="''${RPC_USERNAME:-dogebox}"
    RPC_PASSWORD="''${RPC_PASSWORD:-regtest-dev-password}"
    RPC_PORT="''${RPC_PORT:-22555}"
    RPC_ALLOWED_IPS="''${RPC_ALLOWED_IPS:-0.0.0.0/0}"
    ENABLE_TXINDEX="''${ENABLE_TXINDEX:-1}"
    ENABLE_ZMQ="''${ENABLE_ZMQ:-1}"
    DBCACHE="''${DBCACHE:-256}"

    # Persist creds for the miner service (and debugging)
    echo "$RPC_USERNAME" > ${storageDirectory}/rpcuser.txt
    echo "$RPC_PASSWORD" > ${storageDirectory}/rpcpassword.txt

    # Private regtest chain: no P2P listening, no DNS seeds, nothing to sync.
    ARGS="-regtest=1 -port=22556 -datadir=${storageDirectory} -server=1 -listen=0 -rpc=1 -rpcuser=$RPC_USERNAME -rpcpassword=$RPC_PASSWORD -rpcport=$RPC_PORT -rpcbind=$DBX_PUP_IP"

    RPC_ALLOWED_IPS_SPACED=$(echo "$RPC_ALLOWED_IPS" | tr "," " ")
    for IP in $RPC_ALLOWED_IPS_SPACED; do
      [ -z "$IP" ] || ARGS="$ARGS -rpcallowip=$IP"
    done

    if [ "$ENABLE_TXINDEX" = "1" ] || [ "$ENABLE_TXINDEX" = "true" ]; then
      ARGS="$ARGS -txindex=1"
    fi

    ARGS="$ARGS -dbcache=$DBCACHE"

    if [ "$ENABLE_ZMQ" = "1" ] || [ "$ENABLE_ZMQ" = "true" ]; then
      ARGS="$ARGS -zmqpubhashtx=tcp://0.0.0.0:28333 -zmqpubrawblock=tcp://0.0.0.0:28334 -zmqpubrawtx=tcp://0.0.0.0:28335"
    fi

    echo "[regtest-pup] starting wallet-enabled dogecoind: $ARGS"
    exec ${dogecoind_bin}/bin/dogecoind $ARGS
  '';

  miner = pkgs.writeScriptBin "miner.sh" ''
    #!${pkgs.stdenv.shell}

    MINER_ENABLED="''${MINER_ENABLED:-1}"
    MINER_ADDRESS="''${MINER_ADDRESS:-}"
    MINER_INTERVAL="''${MINER_INTERVAL:-5}"
    RPC_PORT="''${RPC_PORT:-22555}"

    if [ "$MINER_ENABLED" != "1" ] && [ "$MINER_ENABLED" != "true" ]; then
      echo "[miner] disabled — idling"
      while true; do sleep 3600; done
    fi

    # Wait for run.sh to persist RPC creds
    while [ ! -f ${storageDirectory}/rpcuser.txt ]; do sleep 2; done
    RU=$(cat ${storageDirectory}/rpcuser.txt)
    RP=$(cat ${storageDirectory}/rpcpassword.txt)

    CLI="${dogecoind_bin}/bin/dogecoin-cli -regtest -datadir=${storageDirectory} -rpcconnect=$DBX_PUP_IP -rpcuser=$RU -rpcpassword=$RP -rpcport=$RPC_PORT"

    # Wait for the RPC server
    until $CLI getblockchaininfo >/dev/null 2>&1; do sleep 2; done

    ADDR="$MINER_ADDRESS"
    if [ -z "$ADDR" ]; then
      ADDR=$($CLI getnewaddress miner 2>/dev/null)
    fi
    echo "[miner] mining 1 block every ''${MINER_INTERVAL}s to $ADDR"

    while true; do
      $CLI generatetoaddress 1 "$ADDR" >/dev/null 2>&1 || echo "[miner] retry: node busy or RPC error"
      sleep "$MINER_INTERVAL"
    done
  '';
in
{
  inherit dogecoind miner;
}
