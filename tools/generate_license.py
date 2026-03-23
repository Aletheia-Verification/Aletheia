"""
generate_license.py — License Generation Tool (INTERNAL USE ONLY)

Generates signed license files for Aletheia customers.
Requires the Aletheia master private key.

Usage:
    python tools/generate_license.py \\
        --customer "First National Bank" \\
        --license-id "ALT-2026-BANK-001" \\
        --expires "2027-03-04" \\
        --features engine,shadow_diff,vault,cli \\
        --max-daily 1000 \\
        --private-key aletheia_keys/license_master_private.pem \\
        --output-dir ./license/

    # Generate new master key pair:
    python tools/generate_license.py --generate-master-key --output-dir aletheia_keys/
"""

import argparse
import base64
import json
import os
import sys
from datetime import datetime, timezone

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa


def generate_master_key(output_dir: str):
    """Generate a new RSA-2048 master key pair for license signing."""
    os.makedirs(output_dir, exist_ok=True)

    private_path = os.path.join(output_dir, "license_master_private.pem")
    public_path = os.path.join(output_dir, "license_master_public.pem")

    if os.path.exists(private_path):
        print(f"ERROR: {private_path} already exists. Delete it first to regenerate.")
        sys.exit(1)

    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    public_key = private_key.public_key()

    with open(private_path, "wb") as f:
        f.write(private_key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption(),
        ))

    pub_pem = public_key.public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    with open(public_path, "wb") as f:
        f.write(pub_pem)

    print(f"Master key pair generated:")
    print(f"  Private: {private_path}")
    print(f"  Public:  {public_path}")
    print()
    print("Embed this public key in license_manager.py EMBEDDED_PUBLIC_KEY:")
    print(pub_pem.decode("utf-8"))


def sign_license(license_json_bytes: bytes, private_key_path: str) -> str:
    """Sign license.json bytes with RSA-PSS + SHA-256. Returns base64 signature."""
    with open(private_key_path, "rb") as f:
        private_key = serialization.load_pem_private_key(f.read(), password=None)

    sig_bytes = private_key.sign(
        license_json_bytes,
        padding.PSS(
            mgf=padding.MGF1(hashes.SHA256()),
            salt_length=padding.PSS.MAX_LENGTH,
        ),
        hashes.SHA256(),
    )
    return base64.b64encode(sig_bytes).decode("utf-8")


def generate_license(args):
    """Generate a signed license.json + license.sig pair."""
    if not os.path.exists(args.private_key):
        print(f"ERROR: Private key not found: {args.private_key}")
        sys.exit(1)

    os.makedirs(args.output_dir, exist_ok=True)

    issued = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    # Parse expires as date, format as ISO timestamp
    try:
        exp_date = datetime.strptime(args.expires, "%Y-%m-%d")
        expires = exp_date.strftime("%Y-%m-%dT00:00:00Z")
    except ValueError:
        expires = args.expires  # Allow full ISO format too

    features = [f.strip() for f in args.features.split(",")]

    license_data = {
        "license_id": args.license_id,
        "customer": args.customer,
        "issued": issued,
        "expires": expires,
        "features": features,
        "max_analyses_per_day": args.max_daily,
    }

    # Write license.json with sorted keys for deterministic output
    license_json = json.dumps(license_data, indent=2, sort_keys=False)
    license_bytes = license_json.encode("utf-8")

    license_path = os.path.join(args.output_dir, "license.json")
    with open(license_path, "wb") as f:
        f.write(license_bytes)

    # Sign and write license.sig
    sig_b64 = sign_license(license_bytes, args.private_key)
    sig_path = os.path.join(args.output_dir, "license.sig")
    with open(sig_path, "w") as f:
        f.write(sig_b64)

    print(f"License generated for: {args.customer}")
    print(f"  ID:       {args.license_id}")
    print(f"  Expires:  {expires}")
    print(f"  Features: {', '.join(features)}")
    print(f"  Daily:    {args.max_daily}")
    print(f"  Files:    {license_path}")
    print(f"            {sig_path}")


def main():
    parser = argparse.ArgumentParser(
        description="Aletheia License Generator (INTERNAL USE ONLY)",
    )
    sub = parser.add_subparsers(dest="command")

    # generate-master-key
    keygen = sub.add_parser("generate-master-key", help="Generate RSA-2048 master key pair")
    keygen.add_argument("--output-dir", required=True, help="Directory to write PEM files")

    # sign
    sign = sub.add_parser("sign", help="Generate a signed license")
    sign.add_argument("--customer", required=True, help="Customer name")
    sign.add_argument("--license-id", required=True, help="License ID (e.g. ALT-2026-BANK-001)")
    sign.add_argument("--expires", required=True, help="Expiry date (YYYY-MM-DD)")
    sign.add_argument("--features", default="engine,shadow_diff,vault,cli",
                      help="Comma-separated feature list")
    sign.add_argument("--max-daily", type=int, default=1000,
                      help="Max analyses per day (0 = unlimited)")
    sign.add_argument("--private-key", required=True, help="Path to master private key PEM")
    sign.add_argument("--output-dir", required=True, help="Directory to write license files")

    args = parser.parse_args()

    if args.command == "generate-master-key":
        generate_master_key(args.output_dir)
    elif args.command == "sign":
        generate_license(args)
    else:
        parser.print_help()
        sys.exit(0)


if __name__ == "__main__":
    main()
