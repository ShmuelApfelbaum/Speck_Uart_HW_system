#!/usr/bin/env python3
"""
Performance Timing Test for SPECK Hardware
Moderate delays (10x ultra-optimized) for stable operation
"""

import serial
import time

# Configuration
COM_PORT = 'COM10'
KEY = "MySecretKey12345"
PLAINTEXT = "Performance test: 32 characters"

# MODERATE DELAYS (10x ultra-optimized for stability)
DELAY_KEY = 0.1        # After key load → 100ms  
DELAY_CMD = 0.01       # After encrypt/decrypt command → 10ms
DELAY_RESPONSE = 0.1   # Waiting for response → 100ms

def measure_operation(ser, operation, data, key_bytes):
    """Measure time for a single operation with optimized delays"""
    
    # START TIMING - includes key load (NO RESET NEEDED with V3 controller!)
    start_time = time.time()
    
    # Load key
    ser.reset_input_buffer()
    ser.reset_output_buffer()
    
    ser.write(b'K')
    ser.write(key_bytes)
    time.sleep(DELAY_KEY)
    
    key_load_time = time.time()
    key_duration = key_load_time - start_time
    
    if operation == 'encrypt':
        data_bytes = data.encode('ascii')
        padding = 8 - (len(data_bytes) % 8)
        if padding == 0:
            padding = 8
        padded = data_bytes + bytes([padding] * padding)
        num_blocks = len(padded) // 8
        
        print(f"\n{'='*60}")
        print(f"ENCRYPTION TEST")
        print(f"{'='*60}")
        print(f"Plaintext: \"{data}\"")
        print(f"Length: {len(data)} chars → {num_blocks} blocks ({len(padded)} bytes)")
        print(f"\nProcessing...")
        
        ciphertext = bytearray()
        for i in range(num_blocks):
            block = padded[i*8:(i+1)*8]
            ser.write(b'E')
            time.sleep(DELAY_CMD)       # OPTIMIZED: 0.01s (was 0.1s)
            ser.write(block)
            time.sleep(DELAY_RESPONSE)  # OPTIMIZED: 0.05s (was 1.0s)
            ct_block = ser.read(8)
            ciphertext.extend(ct_block)
        
        end_time = time.time()
        total_elapsed = end_time - start_time
        crypto_elapsed = end_time - key_load_time
        
        print(f"✓ Complete")
        print(f"\nCiphertext (hex): {ciphertext.hex()}")
        print(f"\n{'─'*60}")
        print(f"⏱️  TIMING BREAKDOWN:")
        print(f"    Key load time:    {key_duration:.3f} s ({key_duration*1000:.1f} ms)")
        print(f"    Encryption time:  {crypto_elapsed:.3f} s ({crypto_elapsed*1000:.1f} ms)")
        print(f"    TOTAL time:       {total_elapsed:.3f} s ({total_elapsed*1000:.1f} ms)")
        print(f"\n    Blocks processed: {num_blocks}")
        print(f"    Time per block (crypto only): {crypto_elapsed/num_blocks:.3f} s")
        print(f"{'─'*60}")
        
        return ciphertext.hex(), total_elapsed, key_duration, crypto_elapsed
        
    else:  # decrypt
        ct_bytes = bytes.fromhex(data)
        num_blocks = len(ct_bytes) // 8
        
        print(f"\n{'='*60}")
        print(f"DECRYPTION TEST")
        print(f"{'='*60}")
        print(f"Ciphertext (hex): {data}")
        print(f"Blocks: {num_blocks}")
        print(f"\nProcessing...")
        
        plaintext = bytearray()
        for i in range(num_blocks):
            block = ct_bytes[i*8:(i+1)*8]
            ser.write(b'D')
            time.sleep(DELAY_CMD)       # OPTIMIZED: 0.01s (was 0.1s)
            ser.write(block)
            time.sleep(DELAY_RESPONSE)  # OPTIMIZED: 0.05s (was 1.0s)
            pt_block = ser.read(8)
            plaintext.extend(pt_block)
        
        end_time = time.time()
        total_elapsed = end_time - start_time
        crypto_elapsed = end_time - key_load_time
        
        padding_len = plaintext[-1]
        if 0 < padding_len <= 8:
            plaintext = plaintext[:-padding_len]
        
        result = plaintext.decode('ascii')
        
        print(f"✓ Complete")
        print(f"\nPlaintext: \"{result}\"")
        print(f"\n{'─'*60}")
        print(f"⏱️  TIMING BREAKDOWN:")
        print(f"    Key load time:    {key_duration:.3f} s ({key_duration*1000:.1f} ms)")
        print(f"    Decryption time:  {crypto_elapsed:.3f} s ({crypto_elapsed*1000:.1f} ms)")
        print(f"    TOTAL time:       {total_elapsed:.3f} s ({total_elapsed*1000:.1f} ms)")
        print(f"\n    Blocks processed: {num_blocks}")
        print(f"    Time per block (crypto only): {crypto_elapsed/num_blocks:.3f} s")
        print(f"{'─'*60}")
        
        return result, total_elapsed, key_duration, crypto_elapsed


def main():
    print("="*60)
    print("SPECK64/128 Performance Test (V3 - No Reset)")
    print("="*60)
    print("\nDelay settings:")
    print(f"  Key delay:      {DELAY_KEY*1000:.0f} ms")
    print(f"  Command delay:  {DELAY_CMD*1000:.0f} ms")
    print(f"  Response delay: {DELAY_RESPONSE*1000:.0f} ms")
    print("\n✓ Using V3 controller - no reset between operations!")
    
    ser = serial.Serial(COM_PORT, 115200, timeout=2)
    time.sleep(0.2)
    
    key_bytes = KEY.ljust(16, '\0')[:16].encode('ascii')
    
    # Test encryption
    ct_hex, enc_total, enc_key, enc_crypto = measure_operation(ser, 'encrypt', PLAINTEXT, key_bytes)
    
    # Test decryption
    pt_result, dec_total, dec_key, dec_crypto = measure_operation(ser, 'decrypt', ct_hex, key_bytes)
    
    # Verify
    print(f"\n{'='*60}")
    print("VERIFICATION")
    print(f"{'='*60}")
    if pt_result == PLAINTEXT:
        print("✅ PASS - Round-trip successful!")
    else:
        print("❌ FAIL - Data corruption!")
        print(f"Expected: \"{PLAINTEXT}\"")
        print(f"Got:      \"{pt_result}\"")
    
    # Summary
    print(f"\n{'='*60}")
    print("PERFORMANCE SUMMARY")
    print(f"{'='*60}")
    print(f"\nKey load (avg):       {(enc_key + dec_key)/2:.3f} s ({(enc_key + dec_key)/2*1000:.1f} ms)")
    print(f"Per block (avg):      {((enc_crypto + dec_crypto)/(4+4)):.3f} s ({((enc_crypto + dec_crypto)/(4+4))*1000:.1f} ms)")
    print(f"Encryption total:     {enc_total:.3f} s ({enc_total*1000:.1f} ms)")
    print(f"Decryption total:     {dec_total:.3f} s ({dec_total*1000:.1f} ms)")
    print(f"Round-trip total:     {(enc_total + dec_total):.3f} s ({(enc_total + dec_total)*1000:.1f} ms)")
    print(f"{'='*60}")
    
    ser.close()


if __name__ == "__main__":
    main()

