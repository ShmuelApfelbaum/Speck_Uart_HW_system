#!/usr/bin/env python3
"""
Hardware Test 1: Single Block Encryption
Uses NSA test vector for verification
"""

import serial
import time

# NSA Test Vector
KEY = bytes([0x00, 0x01, 0x02, 0x03, 0x08, 0x09, 0x0a, 0x0b,
             0x10, 0x11, 0x12, 0x13, 0x18, 0x19, 0x1a, 0x1b])
PLAINTEXT = bytes([0x2d, 0x43, 0x75, 0x74, 0x74, 0x65, 0x72, 0x3b])
EXPECTED_CT = bytes([0x8b, 0x02, 0x4e, 0x45, 0x48, 0xa5, 0x6f, 0x8c])

def bytes_to_hex(data):
    return ' '.join(f'{b:02x}' for b in data)

print("="*60)
print("SPECK64/128 Hardware Test - Single Block Encryption")
print("="*60)

# Connect
ser = serial.Serial('COM10', 115200, timeout=2)
time.sleep(0.2)
ser.reset_input_buffer()
ser.reset_output_buffer()

print("\n1. Loading Key...")
print(f"   Key: {bytes_to_hex(KEY)}")
ser.write(b'K')
ser.write(KEY)
time.sleep(0.5)
print("   ✓ Key loaded")

print("\n2. Encrypting Block...")
print(f"   Plaintext:  {bytes_to_hex(PLAINTEXT)}")
ser.write(b'E')
ser.write(PLAINTEXT)
time.sleep(0.5)
ciphertext = ser.read(8)
print(f"   Ciphertext: {bytes_to_hex(ciphertext)}")

print("\n3. Verification:")
print(f"   Expected: {bytes_to_hex(EXPECTED_CT)}")
print(f"   Got:      {bytes_to_hex(ciphertext)}")

if ciphertext == EXPECTED_CT:
    print("\n   ✅ PASS - Matches NSA test vector!")
else:
    print("\n   ❌ FAIL - Mismatch!")

print("="*60)

ser.close()

