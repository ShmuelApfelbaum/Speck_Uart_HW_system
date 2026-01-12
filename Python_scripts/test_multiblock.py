#!/usr/bin/env python3
"""
Hardware Test 3: Multi-Block Encryption/Decryption
Tests long ASCII messages with single key load
"""

import serial
import time

KEY = "MySecretKey12345"

# Two different test messages (will create ~10 blocks each)
TEST_TEXT_1 = "SPECK64/128 is a lightweight block cipher designed by the NSA for embedded systems."

TEST_TEXT_2 = "This FPGA implementation achieves 100 MHz operation with minimal resource usage."

def encrypt_text(ser, text):
    """Encrypt text and return hex"""
    # PKCS#7 padding
    pt_bytes = text.encode('ascii')
    padding = (8 - (len(pt_bytes) % 8)) % 8
    if padding == 0:
        padding = 8
    padded = pt_bytes + bytes([padding] * padding)
    num_blocks = len(padded) // 8
    
    print(f"   Input: \"{text[:50]}...\" ({len(text)} chars)")
    print(f"   Blocks: {num_blocks} blocks ({len(padded)} bytes with padding)")
    
    # Encrypt all blocks
    ciphertext = bytearray()
    for i in range(num_blocks):
        block = padded[i*8:(i+1)*8]
        ser.write(b'E')
        ser.write(block)
        time.sleep(0.5)
        ct_block = ser.read(8)
        ciphertext.extend(ct_block)
    
    ct_hex = ciphertext.hex()
    print(f"   Ciphertext: {ct_hex[:40]}... ({len(ct_hex)} hex chars)")
    return ct_hex

def decrypt_hex(ser, ct_hex):
    """Decrypt hex and return text"""
    ct_bytes = bytes.fromhex(ct_hex)
    num_blocks = len(ct_bytes) // 8
    
    print(f"   Ciphertext: {ct_hex[:40]}... ({len(ct_hex)} hex chars)")
    print(f"   Blocks: {num_blocks} blocks")
    
    # Decrypt all blocks
    plaintext = bytearray()
    for i in range(num_blocks):
        block = ct_bytes[i*8:(i+1)*8]
        ser.write(b'D')
        ser.write(block)
        time.sleep(0.5)
        pt_block = ser.read(8)
        plaintext.extend(pt_block)
    
    # Remove PKCS#7 padding
    padding_len = plaintext[-1]
    if 0 < padding_len <= 8:
        plaintext = plaintext[:-padding_len]
    
    text = plaintext.decode('ascii')
    print(f"   Plaintext: \"{text[:50]}...\" ({len(text)} chars)")
    return text

print("="*70)
print("SPECK64/128 Hardware Test - Multi-Block with Single Key Load")
print("="*70)

# Connect
ser = serial.Serial('COM10', 115200, timeout=2)
time.sleep(0.2)
ser.reset_input_buffer()
ser.reset_output_buffer()

print("\n╔════════════════════════════════════════════════════════════════╗")
print("║ KEY LOADED ONCE FOR ALL OPERATIONS                            ║")
print("╚════════════════════════════════════════════════════════════════╝")
print(f"\nLoading key: \"{KEY}\"")

# Load key ONCE
ser.write(b'K')
key_bytes = KEY.ljust(16, '\0')[:16].encode('ascii')
ser.write(key_bytes)
time.sleep(0.5)

print("✓ Key loaded and cached in hardware\n")

print("─"*70)
print("TEST 1: First Long Message")
print("─"*70)

print("\n[Encryption]")
ct1 = encrypt_text(ser, TEST_TEXT_1)

print("\n[Decryption]")
pt1 = decrypt_hex(ser, ct1)

print("\n[Verification]")
if pt1 == TEST_TEXT_1:
    print("✅ PASS - Round-trip successful!")
else:
    print("❌ FAIL - Mismatch!")
    print(f"Expected: {TEST_TEXT_1[:50]}...")
    print(f"Got:      {pt1[:50]}...")

print("\n" + "─"*70)
print("TEST 2: Second Long Message")
print("─"*70)

print("\n[Encryption]")
ct2 = encrypt_text(ser, TEST_TEXT_2)

print("\n[Decryption]")
pt2 = decrypt_hex(ser, ct2)

print("\n[Verification]")
if pt2 == TEST_TEXT_2:
    print("✅ PASS - Round-trip successful!")
else:
    print("❌ FAIL - Mismatch!")
    print(f"Expected: {TEST_TEXT_2[:50]}...")
    print(f"Got:      {pt2[:50]}...")

print("\n" + "="*70)
print("SUMMARY")
print("="*70)
print(f"Key loads:     1 (cached for all operations)")
print(f"Test 1:        {len(TEST_TEXT_1)} chars → {len(ct1)//2} encrypted bytes → {'PASS' if pt1 == TEST_TEXT_1 else 'FAIL'}")
print(f"Test 2:        {len(TEST_TEXT_2)} chars → {len(ct2)//2} encrypted bytes → {'PASS' if pt2 == TEST_TEXT_2 else 'FAIL'}")
print(f"Total blocks:  {len(ct1)//16 + len(ct2)//16} blocks encrypted/decrypted")
print("="*70)

ser.close()

