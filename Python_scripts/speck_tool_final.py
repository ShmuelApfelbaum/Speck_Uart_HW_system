#!/usr/bin/env python3
"""
SPECK64/128 FPGA Crypto Tool - Final Version
No connection resets - just clean, simple communication
"""

import serial
import time

class SPECKCrypto:
    def __init__(self, port, baud=115200):
        """Initialize connection to FPGA"""
        self.ser = serial.Serial(port, baud, timeout=2)
        time.sleep(0.2)
        self.ser.reset_input_buffer()
        self.ser.reset_output_buffer()
        print(f"  ✓ Connected to {port}")
    
    def close(self):
        """Close serial connection"""
        self.ser.close()
    
    def load_key(self, key_text):
        """Load key from ASCII string"""
        # Pad or truncate to 16 characters
        key_text = key_text.ljust(16, '\0')[:16]
        key_bytes = key_text.encode('ascii')
        
        # Pack as four 32-bit words (little-endian)
        k0 = int.from_bytes(key_bytes[0:4], 'little')
        k1 = int.from_bytes(key_bytes[4:8], 'little')
        k2 = int.from_bytes(key_bytes[8:12], 'little')
        k3 = int.from_bytes(key_bytes[12:16], 'little')
        
        # Send 'K' command
        self.ser.write(b'K')
        time.sleep(0.1)
        
        # Send 16 key bytes
        for k in [k0, k1, k2, k3]:
            self.ser.write(k.to_bytes(4, 'little'))
        
        # Wait for key schedule
        time.sleep(0.1)
    
    def encrypt(self, plaintext):
        """Encrypt ASCII plaintext of any length"""
        # Convert to bytes
        pt_bytes = plaintext.encode('ascii')
        original_length = len(pt_bytes)
        
        # Add PKCS#7 padding
        padding_needed = (8 - (original_length % 8)) % 8
        if padding_needed == 0:
            padding_needed = 8
        padded_bytes = pt_bytes + bytes([padding_needed] * padding_needed)
        num_blocks = len(padded_bytes) // 8
        
        # Encrypt each block
        ciphertext = bytearray()
        for i in range(num_blocks):
            block = padded_bytes[i*8:(i+1)*8]
            
            # Send 'E' command
            self.ser.write(b'E')
            time.sleep(0.01)
            
            # Send 8 plaintext bytes
            self.ser.write(block)
            
            # Wait and receive 8 ciphertext bytes
            time.sleep(0.1)
            ct_block = self.ser.read(8)
            
            if len(ct_block) != 8:
                raise Exception(f"Expected 8 bytes, got {len(ct_block)}")
            
            ciphertext.extend(ct_block)
        
        return ciphertext.hex()
    
    def decrypt(self, ct_hex):
        """Decrypt hex ciphertext of any length"""
        # Remove spaces and convert to bytes
        ct_hex = ct_hex.replace(' ', '').replace('0x', '').strip()
        
        if len(ct_hex) % 16 != 0:
            raise Exception(f"Ciphertext must be multiple of 16 hex chars")
        
        ct_bytes = bytes.fromhex(ct_hex)
        num_blocks = len(ct_bytes) // 8
        
        # Decrypt each block
        plaintext = bytearray()
        for i in range(num_blocks):
            block = ct_bytes[i*8:(i+1)*8]
            
            # Send 'D' command
            self.ser.write(b'D')
            time.sleep(0.01)
            
            # Send 8 ciphertext bytes
            self.ser.write(block)
            
            # Wait and receive 8 plaintext bytes
            time.sleep(0.1)
            pt_block = self.ser.read(8)
            
            if len(pt_block) != 8:
                raise Exception(f"Expected 8 bytes, got {len(pt_block)}")
            
            plaintext.extend(pt_block)
        
        # Remove PKCS#7 padding
        padding_length = plaintext[-1]
        if padding_length > 0 and padding_length <= 8:
            if all(b == padding_length for b in plaintext[-padding_length:]):
                plaintext = plaintext[:-padding_length]
        
        # Convert to ASCII
        try:
            return plaintext.decode('ascii')
        except:
            # If contains non-ASCII, show hex
            return f"<non-ASCII: {plaintext.hex()}>"

def print_banner():
    """Print welcome banner"""
    print("\n" + "="*60)
    print("  🔐 SPECK64/128 Hardware Crypto Tool")
    print("="*60)
    print("\n  Encrypt and decrypt using your FPGA accelerator")
    print(f"  {'─'*58}")
    print()

def main():
    COM_PORT = "COM10"
    
    print_banner()
    
    # Connect to FPGA (ONCE - no resets!)
    print(f"  Connecting to FPGA on {COM_PORT}...")
    try:
        crypto = SPECKCrypto(COM_PORT)
    except Exception as e:
        print(f"\n  ❌ ERROR: Could not connect to {COM_PORT}")
        print(f"  {e}")
        print("\n  Make sure:")
        print("    • Basys 3 connected and powered ON")
        print("    • FPGA programmed with SPECK design")
        return
    
    print(f"  {'─'*58}")
    print()
    
    # Main loop
    try:
        while True:
            print("  What would you like to do?")
            print("    [E] Encrypt text")
            print("    [D] Decrypt ciphertext")
            print("    [Q] Quit")
            print()
            
            mode = input("  → ").strip().upper()
            
            if mode == 'Q':
                print("\n  👋 Goodbye!\n")
                break
            
            elif mode == 'E':
                # Get plaintext
                print("\n  Enter text to encrypt:")
                plaintext = input("  → ")
                
                if not plaintext:
                    print("  ⚠ Empty text\n")
                    continue
                
                # Get key
                print("\n  Enter 16-character key:")
                key = input("  → ")
                
                if len(key) < 16:
                    key = key.ljust(16, '\0')
                    print(f"  ⚠ Key padded to 16 characters")
                elif len(key) > 16:
                    key = key[:16]
                    print(f"  ⚠ Key truncated to 16 characters")
                
                # Load key
                print(f"\n  Loading key...")
                try:
                    crypto.load_key(key)
                    print(f"  ✓ Key loaded")
                except Exception as e:
                    print(f"  ❌ ERROR: {e}\n")
                    continue
                
                # Encrypt
                print(f"\n  🔒 Encrypting \"{plaintext}\"...")
                try:
                    ct_hex = crypto.encrypt(plaintext)
                    print(f"  ✓ Done!")
                    print(f"\n  {'─'*58}")
                    print(f"  Ciphertext (hex):")
                    print(f"  {ct_hex}")
                    print(f"  {'─'*58}\n")
                except Exception as e:
                    print(f"  ❌ ERROR: {e}\n")
            
            elif mode == 'D':
                # Get ciphertext
                print("\n  Enter ciphertext (hex):")
                ct_hex = input("  → ")
                
                if not ct_hex:
                    print("  ⚠ Empty ciphertext\n")
                    continue
                
                # Get key
                print("\n  Enter 16-character key:")
                key = input("  → ")
                
                if len(key) < 16:
                    key = key.ljust(16, '\0')
                    print(f"  ⚠ Key padded to 16 characters")
                elif len(key) > 16:
                    key = key[:16]
                    print(f"  ⚠ Key truncated to 16 characters")
                
                # Load key
                print(f"\n  Loading key...")
                try:
                    crypto.load_key(key)
                    print(f"  ✓ Key loaded")
                except Exception as e:
                    print(f"  ❌ ERROR: {e}\n")
                    continue
                
                # Decrypt
                print(f"\n  🔓 Decrypting...")
                try:
                    plaintext = crypto.decrypt(ct_hex)
                    print(f"  ✓ Done!")
                    print(f"\n  {'─'*58}")
                    print(f"  Plaintext:")
                    print(f"  \"{plaintext}\"")
                    print(f"  {'─'*58}\n")
                except Exception as e:
                    print(f"  ❌ ERROR: {e}\n")
            
            else:
                print(f"  ⚠ Unknown command\n")
    
    except KeyboardInterrupt:
        print("\n\n  ⚠ Interrupted\n")
    
    except Exception as e:
        print(f"\n  ❌ ERROR: {e}\n")
    
    finally:
        crypto.close()
        print("  ✓ Connection closed\n")

if __name__ == "__main__":
    main()

