#!/usr/bin/env python3
"""
Hardware Test 2: Single Block Decryption
Uses ciphertext from encryption test
"""

import serial
import time

# NSA Test Vector
KEY = bytes([0x00, 0x01, 0x02, 0x03, 0x08, 0x09, 0x0a, 0x0b,
             0x10, 0x11, 0x12, 0x13, 0x18, 0x19, 0x1a, 0x1b])
CIPHERTEXT = bytes([0x8b, 0x02, 0x4e, 0x45, 0x48, 0xa5, 0x6f, 0x8c])
EXPECTED_PT = bytes([0x2d, 0x43, 0x75, 0x74, 0x74, 0x65, 0x72, 0x3b])

def bytes_to_hex(data):
    return ' '.join(f'{b:02x}' for b in data)

print("="*60)
print("SPECK64/128 Hardware Test - Single Block Decryption")
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

print("\n2. Decrypting Block...")
print(f"   Ciphertext: {bytes_to_hex(CIPHERTEXT)}")
ser.write(b'D')
ser.write(CIPHERTEXT)
time.sleep(0.5)
plaintext = ser.read(8)
print(f"   Plaintext:  {bytes_to_hex(plaintext)}")

print("\n3. Verification:")
print(f"   Expected: {bytes_to_hex(EXPECTED_PT)}")
print(f"   Got:      {bytes_to_hex(plaintext)}")

if plaintext == EXPECTED_PT:
    print("\n   ✅ PASS - Correct decryption!")
else:
    print("\n   ❌ FAIL - Mismatch!")

print("="*60)

ser.close()

