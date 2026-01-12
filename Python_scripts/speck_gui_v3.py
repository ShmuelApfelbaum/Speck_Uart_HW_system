#!/usr/bin/env python3
"""
SPECK64/128 Professional Crypto Interface
Clean, stable, everything visible
"""

import tkinter as tk
from tkinter import ttk, scrolledtext, messagebox
import sys
import os

# Import the crypto backend
sys.path.insert(0, os.path.dirname(__file__))
from speck_tool_final import SPECKCrypto


class ModernCryptoGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("SPECK64/128 Cryptographic System")
        
        # Modern color scheme
        self.colors = {
            'primary': '#2563eb',
            'primary_hover': '#1d4ed8',
            'success': '#10b981',
            'danger': '#ef4444',
            'bg_main': '#f8fafc',
            'bg_card': '#ffffff',
            'text_dark': '#1e293b',
            'text_light': '#64748b',
            'border': '#e2e8f0',
        }
        
        # Fixed size window
        self.root.geometry("700x800")
        self.root.resizable(False, False)  # Fixed for stability
        self.root.configure(bg=self.colors['bg_main'])
        
        # Try to connect to FPGA
        try:
            self.crypto = SPECKCrypto(port='COM10')
            self.connected = True
        except Exception as e:
            self.connected = False
            self.error_msg = str(e)
        
        # Create UI
        self.create_ui()
        
        # Store raw result
        self.raw_result = ""
    
    def create_ui(self):
        """Create UI with perfect spacing"""
        
        # ====================================================================
        # HEADER (80px)
        # ====================================================================
        header = tk.Frame(self.root, bg=self.colors['primary'], height=80)
        header.pack(fill=tk.X)
        header.pack_propagate(False)
        
        tk.Label(header, 
                text="SPECK64/128",
                font=('Segoe UI', 26, 'bold'),
                fg='white',
                bg=self.colors['primary']).pack(pady=(12, 0))
        
        tk.Label(header,
                text="Hardware Encryption & Decryption System",
                font=('Segoe UI', 9),
                fg='#93c5fd',
                bg=self.colors['primary']).pack(pady=(3, 0))
        
        # ====================================================================
        # STATUS BAR (35px)
        # ====================================================================
        status_bar = tk.Frame(self.root, bg='white', height=35)
        status_bar.pack(fill=tk.X)
        status_bar.pack_propagate(False)
        
        status_frame = tk.Frame(status_bar, bg='white')
        status_frame.pack(expand=True)
        
        if self.connected:
            tk.Label(status_frame,
                    text="● Connected • Multi-Block Ready",
                    font=('Segoe UI', 9),
                    fg=self.colors['success'],
                    bg='white').pack(pady=8)
        else:
            tk.Label(status_frame,
                    text="● FPGA Not Connected",
                    font=('Segoe UI', 9),
                    fg=self.colors['danger'],
                    bg='white').pack(pady=8)
        
        # ====================================================================
        # MAIN CONTAINER
        # ====================================================================
        main = tk.Frame(self.root, bg=self.colors['bg_main'])
        main.pack(fill=tk.BOTH, expand=True, padx=20, pady=15)
        
        # ====================================================================
        # MODE SELECTION (70px card)
        # ====================================================================
        mode_card = tk.Frame(main, bg='white', relief=tk.FLAT,
                            highlightthickness=1, highlightbackground=self.colors['border'])
        mode_card.pack(fill=tk.X, pady=(0, 10))
        
        tk.Label(mode_card, text="Operation Mode",
                font=('Segoe UI', 10, 'bold'),
                fg=self.colors['text_dark'],
                bg='white').pack(anchor=tk.W, padx=15, pady=(8, 3))
        
        self.mode = tk.StringVar(value="encrypt")
        
        btn_frame = tk.Frame(mode_card, bg='white')
        btn_frame.pack(pady=(0, 10))
        
        self.encrypt_btn = tk.Button(btn_frame,
                                     text="🔒 Encrypt",
                                     command=lambda: self.select_mode("encrypt"),
                                     font=('Segoe UI', 10, 'bold'),
                                     bg=self.colors['primary'],
                                     fg='white',
                                     activebackground=self.colors['primary_hover'],
                                     activeforeground='white',
                                     relief=tk.FLAT,
                                     padx=30,
                                     pady=8,
                                     cursor='hand2')
        self.encrypt_btn.pack(side=tk.LEFT, padx=5)
        
        self.decrypt_btn = tk.Button(btn_frame,
                                     text="🔓 Decrypt",
                                     command=lambda: self.select_mode("decrypt"),
                                     font=('Segoe UI', 10),
                                     bg=self.colors['bg_main'],
                                     fg=self.colors['text_dark'],
                                     activebackground=self.colors['border'],
                                     relief=tk.FLAT,
                                     padx=30,
                                     pady=8,
                                     cursor='hand2')
        self.decrypt_btn.pack(side=tk.LEFT, padx=5)
        
        # ====================================================================
        # KEY INPUT (70px card)
        # ====================================================================
        key_card = tk.Frame(main, bg='white', relief=tk.FLAT,
                           highlightthickness=1, highlightbackground=self.colors['border'])
        key_card.pack(fill=tk.X, pady=(0, 10))
        
        tk.Label(key_card, text="🔑 Encryption Key",
                font=('Segoe UI', 10, 'bold'),
                fg=self.colors['text_dark'],
                bg='white').pack(anchor=tk.W, padx=15, pady=(8, 3))
        
        tk.Label(key_card,
                text="Enter key (up to 16 characters):",
                font=('Segoe UI', 8),
                fg=self.colors['text_light'],
                bg='white').pack(anchor=tk.W, padx=15, pady=(0, 3))
        
        self.key_entry = tk.Entry(key_card,
                                  font=('Consolas', 10),
                                  bg='#fafafa',
                                  fg=self.colors['text_dark'],
                                  relief=tk.SOLID,
                                  borderwidth=1,
                                  insertbackground=self.colors['primary'])
        self.key_entry.pack(fill=tk.X, padx=15, pady=(0, 10), ipady=6)
        
        # ====================================================================
        # INPUT DATA (120px card)
        # ====================================================================
        input_card = tk.Frame(main, bg='white', relief=tk.FLAT,
                             highlightthickness=1, highlightbackground=self.colors['border'])
        input_card.pack(fill=tk.X, pady=(0, 10))
        
        tk.Label(input_card, text="📝 Input Data",
                font=('Segoe UI', 10, 'bold'),
                fg=self.colors['text_dark'],
                bg='white').pack(anchor=tk.W, padx=15, pady=(8, 3))
        
        self.input_label = tk.Label(input_card,
                                    text="Enter text to encrypt (any length):",
                                    font=('Segoe UI', 8),
                                    fg=self.colors['text_light'],
                                    bg='white')
        self.input_label.pack(anchor=tk.W, padx=15, pady=(0, 3))
        
        self.input_text = scrolledtext.ScrolledText(input_card,
                                                    height=4,  # Smaller
                                                    font=('Consolas', 9),
                                                    bg='#fafafa',
                                                    fg=self.colors['text_dark'],
                                                    relief=tk.SOLID,
                                                    borderwidth=1,
                                                    insertbackground=self.colors['primary'],
                                                    padx=10,
                                                    pady=8,
                                                    wrap=tk.WORD)
        self.input_text.pack(fill=tk.X, padx=15, pady=(0, 10))
        
        # ====================================================================
        # EXECUTE BUTTON (50px)
        # ====================================================================
        self.exec_button = tk.Button(main,
                                     text="🚀 Execute Operation",
                                     command=self.execute,
                                     font=('Segoe UI', 11, 'bold'),
                                     bg=self.colors['primary'],
                                     fg='white',
                                     activebackground=self.colors['primary_hover'],
                                     activeforeground='white',
                                     relief=tk.FLAT,
                                     pady=12,
                                     cursor='hand2')
        self.exec_button.pack(fill=tk.X, pady=(0, 10))
        
        # ====================================================================
        # RESULT OUTPUT (180px card with copy button inside)
        # ====================================================================
        output_card = tk.Frame(main, bg='white', relief=tk.FLAT,
                              highlightthickness=1, highlightbackground=self.colors['border'])
        output_card.pack(fill=tk.X, pady=(0, 10))
        
        tk.Label(output_card, text="✨ Result",
                font=('Segoe UI', 10, 'bold'),
                fg=self.colors['text_dark'],
                bg='white').pack(anchor=tk.W, padx=15, pady=(8, 5))
        
        self.output_text = scrolledtext.ScrolledText(output_card,
                                                     height=6,  # Reasonable size
                                                     font=('Consolas', 9),
                                                     bg='#f1f5f9',
                                                     fg=self.colors['text_dark'],
                                                     relief=tk.FLAT,
                                                     padx=12,
                                                     pady=10,
                                                     wrap=tk.WORD)
        self.output_text.pack(fill=tk.X, padx=15, pady=(0, 8))
        
        # Placeholder
        self.output_text.insert("1.0", "Results will appear here...\n\n✨ Ready for encryption")
        self.output_text.tag_add("center", "1.0", tk.END)
        self.output_text.tag_config("center", justify='center', foreground=self.colors['text_light'])
        self.output_text.config(state=tk.DISABLED)
        
        # Copy Button (inside output card)
        self.copy_button = tk.Button(output_card,
                                     text="📋 Copy Result",
                                     command=self.copy_result,
                                     font=('Segoe UI', 9, 'bold'),
                                     bg=self.colors['bg_main'],
                                     fg=self.colors['text_dark'],
                                     activebackground=self.colors['border'],
                                     relief=tk.FLAT,
                                     padx=15,
                                     pady=6,
                                     cursor='hand2',
                                     state=tk.DISABLED)
        self.copy_button.pack(pady=(0, 10))
        
        # ====================================================================
        # TIP (40px)
        # ====================================================================
        tip_frame = tk.Frame(main, bg='#eff6ff', relief=tk.FLAT)
        tip_frame.pack(fill=tk.X)
        
        tk.Label(tip_frame,
                text="💡 Copy result, switch mode, and paste to verify!",
                font=('Segoe UI', 8),
                fg='#1e40af',
                bg='#eff6ff').pack(padx=12, pady=8)
        
        # Disable if not connected
        if not self.connected:
            self.exec_button.config(state=tk.DISABLED, bg=self.colors['text_light'])
            self.input_text.config(state=tk.DISABLED, bg='#e5e7eb')
            self.key_entry.config(state=tk.DISABLED, bg='#e5e7eb')
            self.encrypt_btn.config(state=tk.DISABLED)
            self.decrypt_btn.config(state=tk.DISABLED)
    
    def select_mode(self, mode):
        """Handle mode selection"""
        self.mode.set(mode)
        
        if mode == "encrypt":
            self.encrypt_btn.config(bg=self.colors['primary'],
                                   fg='white',
                                   font=('Segoe UI', 10, 'bold'))
            self.decrypt_btn.config(bg=self.colors['bg_main'],
                                   fg=self.colors['text_dark'],
                                   font=('Segoe UI', 10))
            self.input_label.config(text="Enter text to encrypt (any length):")
        else:
            self.decrypt_btn.config(bg=self.colors['primary'],
                                   fg='white',
                                   font=('Segoe UI', 10, 'bold'))
            self.encrypt_btn.config(bg=self.colors['bg_main'],
                                   fg=self.colors['text_dark'],
                                   font=('Segoe UI', 10))
            self.input_label.config(text="Enter ciphertext (hex format):")
    
    def _format_hex(self, hex_string):
        """Format hex for display"""
        chunks = [hex_string[i:i+16] for i in range(0, len(hex_string), 16)]
        formatted = []
        for chunk in chunks:
            spaced = ' '.join([chunk[i:i+2] for i in range(0, len(chunk), 2)])
            formatted.append(spaced)
        return '\n'.join(formatted)
    
    def copy_result(self):
        """Copy result to clipboard"""
        if not self.raw_result:
            messagebox.showwarning("Nothing to Copy", "No result available!")
            return
        
        self.root.clipboard_clear()
        self.root.clipboard_append(self.raw_result)
        
        # Feedback
        self.copy_button.config(text="✓ Copied!", 
                               bg=self.colors['success'],
                               fg='white')
        self.root.after(1500, lambda: self.copy_button.config(
            text="📋 Copy Result",
            bg=self.colors['bg_main'],
            fg=self.colors['text_dark']))
    
    def execute(self):
        """Execute operation"""
        input_data = self.input_text.get("1.0", tk.END).strip()
        key = self.key_entry.get().strip()
        
        if not input_data:
            messagebox.showerror("Input Required", "Please enter text!")
            return
        
        if not key:
            messagebox.showerror("Key Required", "Please enter a key!")
            return
        
        # Processing state
        self.exec_button.config(state=tk.DISABLED, 
                               text="⏳ Processing...", 
                               bg=self.colors['text_light'])
        self.copy_button.config(state=tk.DISABLED, bg=self.colors['bg_main'])
        self.raw_result = ""
        
        self.output_text.config(state=tk.NORMAL, bg='#f1f5f9')
        self.output_text.delete("1.0", tk.END)
        self.output_text.insert("1.0", "Processing...\nPlease wait...")
        self.output_text.tag_add("center", "1.0", tk.END)
        self.output_text.tag_config("center", justify='center')
        self.output_text.config(state=tk.DISABLED)
        self.root.update()
        
        try:
            # Load key once
            self.crypto.load_key(key)
            
            # Execute
            if self.mode.get() == "encrypt":
                result = self.crypto.encrypt(input_data)
                self.raw_result = result
                
                self.output_text.config(state=tk.NORMAL, bg='#f1f5f9')
                self.output_text.delete("1.0", tk.END)
                
                formatted = self._format_hex(result)
                self.output_text.insert("1.0", formatted)
                
                num_blocks = len(result) // 16
                info = f"\n\n✓ {num_blocks} block{'s' if num_blocks > 1 else ''} encrypted"
                self.output_text.insert(tk.END, info)
                self.output_text.tag_add("info", f"end-{len(info)}c", tk.END)
                self.output_text.tag_config("info", 
                                           foreground=self.colors['success'],
                                           font=('Segoe UI', 8, 'italic'),
                                           justify='center')
                
                self.copy_button.config(state=tk.NORMAL, 
                                       bg=self.colors['primary'],
                                       fg='white')
            else:
                result = self.crypto.decrypt(input_data)
                self.raw_result = result
                
                self.output_text.config(state=tk.NORMAL, bg='#f1f5f9')
                self.output_text.delete("1.0", tk.END)
                
                self.output_text.insert("1.0", f'"{result}"')
                
                info = "\n\n✓ Decrypted successfully"
                self.output_text.insert(tk.END, info)
                self.output_text.tag_add("info", f"end-{len(info)}c", tk.END)
                self.output_text.tag_config("info",
                                           foreground=self.colors['success'],
                                           font=('Segoe UI', 8, 'italic'),
                                           justify='center')
                
                self.copy_button.config(state=tk.NORMAL,
                                       bg=self.colors['primary'],
                                       fg='white')
            
            self.output_text.tag_add("result", "1.0", "end-1c")
            self.output_text.tag_config("result", 
                                       justify='center',
                                       foreground=self.colors['text_dark'])
            
        except Exception as e:
            self.raw_result = ""
            self.copy_button.config(state=tk.DISABLED, bg=self.colors['bg_main'])
            
            self.output_text.config(state=tk.NORMAL, bg='#fef2f2')
            self.output_text.delete("1.0", tk.END)
            self.output_text.insert("1.0", f"❌ Error\n\n{str(e)}")
            self.output_text.tag_add("center", "1.0", tk.END)
            self.output_text.tag_config("center", 
                                       justify='center',
                                       foreground=self.colors['danger'])
            messagebox.showerror("Error", str(e))
        
        finally:
            self.exec_button.config(state=tk.NORMAL,
                                   text="🚀 Execute Operation",
                                   bg=self.colors['primary'])
            self.output_text.config(state=tk.DISABLED)
    
    def cleanup(self):
        """Cleanup"""
        if self.connected:
            self.crypto.close()


def main():
    root = tk.Tk()
    app = ModernCryptoGUI(root)
    root.protocol("WM_DELETE_WINDOW", lambda: (app.cleanup(), root.destroy()))
    root.mainloop()


if __name__ == "__main__":
    main()
