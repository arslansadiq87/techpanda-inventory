#!/usr/bin/env python3
"""
deploy_remote.py — 1-Click Remote Deployment for TechPanda Inventory from Windows to Linux.
Prompts for Linux SSH user and password, uploads backend + compose files, and executes deploy.sh.
"""

import os
import sys
import io
import tarfile
import getpass
import secrets

try:
    import paramiko
except ImportError:
    print("[!] Error: 'paramiko' is required. Install it using: pip install paramiko")
    sys.exit(1)


IGNORE_PATTERNS = {
    ".venv", "__pycache__", ".pytest_cache", ".git", ".idea", ".vscode",
    "tests", "build", ".pio"
}
IGNORE_EXTS = {".pyc", ".pyo", ".pyd", ".db", ".sqlite3"}


def should_ignore(path: str) -> bool:
    parts = path.replace("\\", "/").split("/")
    for p in parts:
        if p in IGNORE_PATTERNS:
            return True
    _, ext = os.path.splitext(path)
    return ext in IGNORE_EXTS


def sync_web_assets(project_root: str):
    flutter_web_dir = os.path.join(project_root, "flutter_app", "build", "web")
    static_web_dir = os.path.join(project_root, "backend", "static_web")

    # If build/web/index.html is missing, build Flutter web first
    if not os.path.exists(os.path.join(flutter_web_dir, "index.html")):
        flutter_app_dir = os.path.join(project_root, "flutter_app")
        if os.path.exists(os.path.join(flutter_app_dir, "pubspec.yaml")):
            print("[+] Building Flutter web app assets (flutter build web)...")
            import subprocess
            res = subprocess.run(["flutter", "build", "web"], cwd=flutter_app_dir, shell=True)
            if res.returncode != 0:
                print("[!] Warning: flutter build web exited with error; proceeding with existing files.")

    if os.path.exists(flutter_web_dir):
        print("[+] Syncing Flutter web assets into backend/static_web...")
        import shutil
        import time
        if os.path.exists(static_web_dir):
            shutil.rmtree(static_web_dir)
        shutil.copytree(flutter_web_dir, static_web_dir)
        bootstrap_file = os.path.join(static_web_dir, "flutter_bootstrap.js")
        if os.path.exists(bootstrap_file):
            with open(bootstrap_file, "r", encoding="utf-8") as f:
                content = f.read()
            ts = int(time.time())
            content = content.replace('"mainJsPath":"main.dart.js"', f'"mainJsPath":"main.dart.js?v={ts}"')
            with open(bootstrap_file, "w", encoding="utf-8") as f:
                f.write(content)
        print("[OK] Web assets synced and cache-busted.")


def build_tar_package(project_root: str) -> io.BytesIO:
    bio = io.BytesIO()
    with tarfile.open(fileobj=bio, mode="w:gz") as tar:
        # Add deploy.sh
        deploy_sh = os.path.join(project_root, "deploy.sh")
        if os.path.exists(deploy_sh):
            with open(deploy_sh, "rb") as f:
                data = f.read().replace(b"\r\n", b"\n")
            ti = tarfile.TarInfo(name="deploy.sh")
            ti.size = len(data)
            ti.mode = 0o755
            tar.addfile(ti, io.BytesIO(data))

        # Add docker-compose.yml
        compose_file = os.path.join(project_root, "docker-compose.yml")
        if os.path.exists(compose_file):
            tar.add(compose_file, arcname="docker-compose.yml")

        # Add backend directory
        backend_dir = os.path.join(project_root, "backend")
        for root, dirs, files in os.walk(backend_dir):
            rel_dir = os.path.relpath(root, project_root)
            if should_ignore(rel_dir):
                continue
            for file in files:
                full_path = os.path.join(root, file)
                rel_path = os.path.relpath(full_path, project_root)
                if should_ignore(rel_path):
                    continue
                tar.add(full_path, arcname=rel_path.replace("\\", "/"))

    bio.seek(0)
    return bio


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Deploy TechPanda Inventory from Windows to Linux over SSH.")
    parser.add_argument("--host", help="Linux Server IP / Hostname")
    parser.add_argument("--port", type=int, default=22, help="SSH Port (default: 22)")
    parser.add_argument("--user", help="SSH Username (default: root)")
    parser.add_argument("--password", help="SSH Password")
    parser.add_argument("--dir", default="~/techpanda_inventory", help="Remote destination directory")
    parser.add_argument("--token", help="Cloudflare Tunnel Token (optional)")
    parser.add_argument("--admin-password", help="Initial application admin password; can also be supplied as ADMIN_PASSWORD")
    args = parser.parse_args()

    print("=" * 65)
    print("    TechPanda Inventory — Windows to Linux Remote Deployer")
    print("=" * 65)

    host = args.host or input("Linux Server IP / Hostname: ").strip()
    if not host:
        print("[!] Server IP/Hostname cannot be empty.")
        sys.exit(1)

    port = args.port
    if not args.host:
        port_str = input(f"SSH Port [{port}]: ").strip()
        if port_str.isdigit():
            port = int(port_str)

    username = args.user or (input("SSH Username [root]: ").strip() or "root")
    password = args.password or getpass.getpass(f"SSH Password for '{username}': ")
    if not password:
        print("[!] Password cannot be empty.")
        sys.exit(1)

    admin_password = args.admin_password or os.environ.get("ADMIN_PASSWORD", "").strip()
    if not admin_password:
        admin_password = getpass.getpass("Initial application admin password: ").strip()
    if not admin_password:
        print("[!] Application admin password cannot be empty.")
        sys.exit(1)

    remote_dir = args.dir
    if not args.host:
        remote_dir = input(f"Remote destination dir [{remote_dir}]: ").strip() or remote_dir

    # Check for Cloudflare token
    cf_token = args.token or ""
    if not cf_token:
        env_local = os.path.join(os.path.dirname(__file__), ".env")
        if os.path.exists(env_local):
            with open(env_local, "r", encoding="utf-8") as f:
                for line in f:
                    if line.startswith("CLOUDFLARE_TUNNEL_TOKEN="):
                        cf_token = line.split("=", 1)[1].strip().strip('"').strip("'")
                        break

    if not cf_token and not args.host:
        cf_token = getpass.getpass("Cloudflare Tunnel Token (optional, press Enter to skip): ").strip()

    if cf_token:
        cf_token = cf_token.strip()
        dup_idx = cf_token.find("eyJh", 4)
        if dup_idx != -1:
            cf_token = cf_token[:dup_idx]

    print(f"\n[+] Connecting to {username}@{host}:{port}...")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    try:
        ssh.connect(hostname=host, port=port, username=username, password=password, timeout=15)
        print("[OK] SSH Connected successfully!")
    except Exception as e:
        print(f"[!] Failed to connect: {e}")
        sys.exit(1)

    sftp = ssh.open_sftp()

    # Expand remote directory path
    _, stdout, _ = ssh.exec_command(f"echo {remote_dir}")
    remote_path = stdout.read().decode().strip()

    print(f"[+] Creating remote directory: {remote_path}")
    ssh.exec_command(f"mkdir -p '{remote_path}'")

    print("[+] Packaging backend and deployment files...")
    script_dir = os.path.dirname(os.path.abspath(__file__))
    sync_web_assets(script_dir)
    tar_stream = build_tar_package(script_dir)
    tar_size_kb = len(tar_stream.getvalue()) / 1024
    print(f"[OK] Package built ({tar_size_kb:.1f} KB).")

    remote_tar = f"{remote_path}/release.tar.gz"
    print(f"[+] Uploading files via SFTP to {remote_tar}...")
    sftp.putfo(tar_stream, remote_tar)
    print("[OK] Upload complete!")

    # Write .env remotely so deploy.sh doesn't pause for user input
    remote_env = f"{remote_path}/.env"
    if not cf_token:
        try:
            with sftp.file(remote_env, "r") as f:
                for line in f.read().decode().splitlines():
                    if line.startswith("CLOUDFLARE_TUNNEL_TOKEN="):
                        cf_token = line.split("=", 1)[1].strip()
        except Exception:
            pass

    jwt_secret = secrets.token_hex(32)
    # Optional voice key must be supplied out-of-band; never publish a default
    # credential in the deployment helper or repository.
    voice_key = os.environ.get("VOICE_ASSISTANT_API_KEY", "").strip()
    env_content = (
        f"CLOUDFLARE_TUNNEL_TOKEN={cf_token}\n"
        f"JWT_SECRET={jwt_secret}\n"
        "ADMIN_NAME=admin\n"
        f"ADMIN_PASSWORD={admin_password}\n"
        + (f"VOICE_ASSISTANT_API_KEY={voice_key}\n" if voice_key else "")
    )
    print(f"[+] Writing remote {remote_env}...")
    with sftp.file(remote_env, "w") as f:
        f.write(env_content)

    sftp.close()

    print("\n" + "=" * 65)
    print(f"[+] Executing deployment script on {host}...")
    print("=" * 65 + "\n")

    # Command to extract and run deploy.sh
    cmd = f"cd '{remote_path}' && tar -xzf release.tar.gz && chmod +x deploy.sh && ./deploy.sh"

    # Open an interactive PTY channel to stream output and handle sudo if needed
    channel = ssh.invoke_shell()
    channel.settimeout(300)

    # If non-root user and sudo is prompted, provide password
    channel.send(f"{cmd}\n")

    output_buffer = ""
    while True:
        if channel.recv_ready():
            chunk = channel.recv(4096).decode("utf-8", errors="replace")
            safe_chunk = chunk.encode("ascii", errors="replace").decode("ascii")
            sys.stdout.write(safe_chunk)
            sys.stdout.flush()
            output_buffer += chunk

            # Detect sudo password prompt if user is non-root
            if "[sudo] password for" in chunk.lower() or "password:" in chunk.lower():
                channel.send(f"{password}\n")

        if channel.exit_status_ready() and not channel.recv_ready():
            break

        # Check for deployment complete markers
        if "Deployment complete!" in output_buffer and "docker compose" not in chunk:
            break

    ssh.close()
    print("\n" + "=" * 65)
    print("    Remote Deployment Finished!")
    print("=" * 65)


if __name__ == "__main__":
    main()
