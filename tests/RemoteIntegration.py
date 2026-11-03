#!/usr/bin/env python3
"""Compatibility entry point for the current HTTPS/native simulator regression.

Build 148's plaintext + pending-phone-approval protocol has been superseded.
The authoritative suite uses Node/OpenSSL with an explicitly trusted leaf cert.
"""
import pathlib,subprocess
root=pathlib.Path(__file__).resolve().parents[1]
subprocess.run(['node',str(root/'tests/RemoteSecureIntegration.mjs')],cwd=root,check=True)
